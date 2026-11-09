#!/usr/bin/env bash
#
# Durcissement initial d'un serveur Ubuntu 24.04.
#
# Usage, une seule fois, en root, juste après la livraison du serveur :
#
#   scp server/harden.sh root@<ip>:/root/
#   ssh root@<ip>
#   bash /root/harden.sh <utilisateur>
#
# Le script pose des questions (mot de passe de sudo, confirmation). Il doit donc
# tourner dans une session SSH interactive, et non en une seule commande à distance.
#
# Il procède en deux temps pour éviter de perdre l'accès au serveur :
#   1. création de l'utilisateur d'administration, qui reçoit la clé SSH de root ;
#   2. pause, le temps de vérifier dans un AUTRE terminal que cet utilisateur se
#      connecte et obtient sudo. Ensuite seulement, root et les mots de passe sont
#      refusés en SSH. La session en cours reste ouverte après ce changement.
#
# Le script peut être relancé sans dommage : chaque étape tient compte de l'existant.

set -euo pipefail

ADMIN_USER="${1:-}"
SSH_CONFIG=/etc/ssh/sshd_config.d/01-hardening.conf

# Plages internes de k3s (pods et services), autorisées dès maintenant. Sans elles,
# le pare-feu bloque le trafic entre conteneurs une fois k3s installé, avec des
# symptômes trompeurs (échecs DNS dans les pods).
K3S_POD_CIDR=10.42.0.0/16
K3S_SERVICE_CIDR=10.43.0.0/16

log() { printf '\n==> %s\n' "$1"; }
fail() { printf '\nERREUR : %s\n' "$1" >&2; exit 1; }

[[ $EUID -eq 0 ]] || fail "le script doit être lancé en root."
[[ -t 0 ]] || fail "le script doit être lancé dans une session interactive (voir l'en-tête)."
[[ -n "$ADMIN_USER" ]] || fail "usage : bash harden.sh <utilisateur>"
[[ "$ADMIN_USER" =~ ^[a-z][a-z0-9-]{1,31}$ ]] || fail "nom d'utilisateur invalide (minuscules, chiffres, tirets)."
[[ -s /root/.ssh/authorized_keys ]] || fail "aucune clé dans /root/.ssh/authorized_keys : rien à transmettre."

# --- 1. Système à jour et outils ----------------------------------------------

log "Mise à jour du système"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get upgrade -yq
apt-get install -yq ufw fail2ban unattended-upgrades

timedatectl set-timezone Europe/Paris

# --- 2. Utilisateur d'administration ----------------------------------------------

log "Utilisateur d'administration : $ADMIN_USER"
if ! id "$ADMIN_USER" &>/dev/null; then
    adduser --disabled-password --gecos "" "$ADMIN_USER"
fi
usermod -aG sudo "$ADMIN_USER"

install -d -m 700 -o "$ADMIN_USER" -g "$ADMIN_USER" "/home/$ADMIN_USER/.ssh"
install -m 600 -o "$ADMIN_USER" -g "$ADMIN_USER" /root/.ssh/authorized_keys \
    "/home/$ADMIN_USER/.ssh/authorized_keys"

# Le mot de passe sert uniquement à sudo : la connexion SSH n'accepte que la clé.
# Sans lui, une clé volée donnerait directement les droits root.
if passwd -S "$ADMIN_USER" | awk '{print $2}' | grep -qv '^P$'; then
    echo "Mot de passe de sudo pour $ADMIN_USER (il ne sert pas à la connexion SSH) :"
    passwd "$ADMIN_USER"
fi

# --- 3. Pare-feu -------------------------------------------------------------------

log "Pare-feu : SSH, HTTP et HTTPS uniquement"
ufw default deny incoming
ufw default allow outgoing
# limit : refuse une adresse qui ouvre plus de 6 connexions en 30 secondes.
ufw limit 22/tcp comment 'SSH'
# Pas d'apostrophe dans un commentaire ufw : il la refuse (Invalid syntax).
ufw allow 80/tcp comment 'HTTP, certificats et redirection'
ufw allow 443/tcp comment 'HTTPS'
ufw allow from "$K3S_POD_CIDR" comment 'k3s pods'
ufw allow from "$K3S_SERVICE_CIDR" comment 'k3s services'
# L'API Kubernetes (6443) reste fermée : elle s'utilise à travers un tunnel SSH.
ufw --force enable

# --- 4. fail2ban -------------------------------------------------------------------

log "fail2ban : bannissement des tentatives SSH répétées"
cat > /etc/fail2ban/jail.local <<'EOF'
# Ubuntu journalise SSH dans journald, et non dans un fichier : backend systemd.
[sshd]
enabled = true
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

# --- 5. Mises à jour de sécurité automatiques ---------------------------------------

log "Mises à jour de sécurité automatiques"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
# Pas de redémarrage automatique : il interromprait les applications hébergées sans
# prévenir. Le fichier /var/run/reboot-required signale un redémarrage en attente.

# --- 6. Vérification avant de fermer l'accès ------------------------------------------

IP=$(hostname -I | awk '{print $1}')
cat <<EOF

------------------------------------------------------------------------------
AVANT DE CONTINUER, vérifier dans un AUTRE terminal, depuis le poste local :

  ssh $ADMIN_USER@$IP
  sudo -v        (doit accepter le mot de passe de sudo défini plus haut)

Garder cette session root ouverte tant que ce test n'a pas réussi.
------------------------------------------------------------------------------
EOF
read -r -p "Connexion ET sudo fonctionnels ? Saisir OUI pour refuser root et les mots de passe : " answer
[[ "$answer" == "OUI" ]] || fail "arrêt sans modifier SSH. Relancer le script une fois le test réussi."

# --- 7. SSH : clé uniquement, pas de root ---------------------------------------------

log "SSH : clé uniquement, root interdit"
# Préfixe 01 : sshd retient la PREMIÈRE valeur lue pour chaque option. Les images
# cloud d'Ubuntu fournissent 50-cloud-init.conf, qui active parfois
# PasswordAuthentication. Lu avant lui, ce fichier l'emporte.
cat > "$SSH_CONFIG" <<EOF
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowUsers $ADMIN_USER
MaxAuthTries 3
X11Forwarding no
EOF

sshd -t || { rm -f "$SSH_CONFIG"; fail "configuration SSH invalide, fichier retiré."; }

# Contrôle de la configuration réellement appliquée, et pas seulement du fichier écrit.
effective=$(sshd -T)
for expected in "permitrootlogin no" "passwordauthentication no" "kbdinteractiveauthentication no"; do
    grep -qx "$expected" <<<"$effective" || { rm -f "$SSH_CONFIG"; fail "réglage non appliqué : $expected"; }
done

# Le rechargement relit la configuration sans couper les sessions ouvertes.
systemctl reload ssh || systemctl restart ssh

cat <<EOF

Terminé. À partir de maintenant :
  - connexion : ssh $ADMIN_USER@$IP
  - root et les mots de passe sont refusés en SSH
  - pare-feu : $(ufw status | head -1)
  - fail2ban : $(systemctl is-active fail2ban)

Contrôle depuis le poste local, root doit être refusé :
  ssh root@$IP     (réponse attendue : Permission denied)
EOF
