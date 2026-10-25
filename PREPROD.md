# Butterfly - Pré-production sur un VPS

Ce guide installe la plateforme sur un serveur loué, accessible en HTTPS à une adresse comme
`https://butterfly.cheridanh.fr`. Il reprend la pile locale et `docker-compose.preprod.yml` y
change deux choses :

- **Caddy** obtient le certificat HTTPS et sert de seul accès public ;
- **le backend passe sur le profil Spring `prod`** au lieu de `docker` : connexion chiffrée à
  MySQL, Swagger désactivé, détails de santé masqués. La pré-production teste ainsi la
  configuration qui ira en production et non celle de la démonstration locale.

```text
Internet -> Caddy (80, 443) -> nginx du frontend (127.0.0.1:8081) -> backend -> MySQL, Redis
```

## Sommaire

- [1. Choisir le serveur](#1-choisir-le-serveur)
- [2. Pointer le domaine](#2-pointer-le-domaine)
- [3. Sécuriser le serveur](#3-sécuriser-le-serveur)
- [4. Installer Docker et les dépôts](#4-installer-docker-et-les-dépôts)
- [5. Configurer le .env](#5-configurer-le-env)
- [6. Premier démarrage et contenus de démonstration](#6-premier-démarrage-et-contenus-de-démonstration)
- [7. Passer à un envoi réel avec Brevo](#7-passer-à-un-envoi-réel-avec-brevo)
- [8. Sauvegardes](#8-sauvegardes)
- [9. Mettre à jour](#9-mettre-à-jour)
- [Dépannage](#dépannage)

## 1. Choisir le serveur

- **2 vCPU, 4 Go de mémoire, 40 Go de disque.** Les plafonds du compose totalisent environ
  2,2 Go (MySQL 768 Mo, backend 1 Go, Redis et Caddy 128 Mo chacun). La construction Maven de
  l'image backend demande aussi de la mémoire : 2 Go ne suffisent pas.
- **Ubuntu Server LTS** (24.04 ou plus récente) ou **Debian** (13 Trixie de préférence, 12
  Bookworm accepté). Les deux sont pris en charge par Docker et le guide couvre les deux : les
  rares différences sont signalées par une note **Debian**.
- Un hébergeur européen (Hetzner, OVHcloud, Scaleway...) garde les données des testeurs dans
  l'Union européenne. Les prix ont beaucoup bougé en 2026 avec la hausse du coût de la mémoire :
  comparer les offres au moment de commander.
- Activer l'option de sauvegarde ou d'instantané de l'hébergeur si elle existe : c'est la seule
  protection contre la perte du serveur lui-même (voir [8. Sauvegardes](#8-sauvegardes)).

## 2. Pointer le domaine

Chez le registrar de `cheridanh.fr`, ajouter un enregistrement :

| Type | Nom         | Valeur                              |
|------|-------------|-------------------------------------|
| A    | `butterfly` | adresse IPv4 du VPS                 |
| AAAA | `butterfly` | adresse IPv6 du VPS, si elle existe |

Vérifier avant d'aller plus loin : `dig +short butterfly.cheridanh.fr` doit renvoyer l'adresse du
VPS. Sans cela, Let's Encrypt refuse le certificat.

## 3. Sécuriser le serveur

Connecté en `root` la première fois :

```bash
# Debian : sudo et ufw ne sont pas toujours installés sur une image minimale.
# Sur Ubuntu, la commande est sans effet : les paquets sont déjà là.
apt update && apt install -y sudo ufw

# Utilisateur courant avec sudo, la connexion root sera fermée
adduser butterfly
usermod -aG sudo butterfly
rsync --archive --chown=butterfly:butterfly ~/.ssh /home/butterfly

# Mises à jour de sécurité automatiques
apt update && apt upgrade -y
apt install -y unattended-upgrades fail2ban
dpkg-reconfigure -plow unattended-upgrades

# Pare-feu : SSH, HTTP et HTTPS (443/udp pour HTTP/3)
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw enable
```

**Debian** : le système n'écrit plus `/var/log/auth.log`, les journaux passent par journald.
Sans précision, la surveillance SSH de fail2ban cherche ce fichier et ne démarre pas. Il faut
lui indiquer de lire journald :

```bash
apt install -y python3-systemd
cat > /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
backend = systemd
EOF
systemctl restart fail2ban
fail2ban-client status sshd   # doit afficher la surveillance sans erreur
```

Ce réglage fonctionne aussi sur Ubuntu, il n'y est simplement pas nécessaire.

Puis dans `/etc/ssh/sshd_config` : `PermitRootLogin no` et `PasswordAuthentication no`, suivis de
`systemctl restart ssh`. Certaines images cloud ajoutent un fichier dans `/etc/ssh/sshd_config.d/`
qui réactive le mot de passe et l'emporte sur `sshd_config`. Cette commande doit afficher `no`
deux fois :

```bash
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication'
```

**Tester d'abord** une connexion `ssh butterfly@<ip>` dans un autre
terminal sans fermer le premier : une erreur ici bloque l'accès au serveur.

Attention, **Docker contourne ufw** : un port publié par Docker est ouvert même si ufw ne
l'autorise pas. C'est pourquoi tous les ports de la pile sont liés à `127.0.0.1`, sauf ceux de
Caddy. Ne jamais publier un autre port sans ce préfixe.

## 4. Installer Docker et les dépôts

Installer Docker Engine et le plugin Compose depuis le dépôt officiel de Docker, et non le
paquet `docker.io` de la distribution, souvent plus ancien et sans le plugin Compose. Les
commandes viennent de la documentation Docker ([Ubuntu](https://docs.docker.com/engine/install/ubuntu/),
[Debian](https://docs.docker.com/engine/install/debian/)). Seule l'adresse du dépôt diffère entre
les deux systèmes : `$ID` est lu dans `/etc/os-release` et vaut `ubuntu` ou `debian`.

```bash
sudo apt update
sudo apt install -y ca-certificates curl git
sudo install -m 0755 -d /etc/apt/keyrings
. /etc/os-release
sudo curl -fsSL "https://download.docker.com/linux/$ID/gpg" -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/$ID
Suites: $VERSION_CODENAME
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

docker --version && docker compose version   # les deux doivent répondre
```

**Debian** : `git` n'est pas installé sur une image minimale, d'où sa présence dans la
première commande. Docker n'accepte que `iptables-nft` ou `iptables-legacy` : ne pas écrire de
règles `nft` à la main sur ce serveur, ufw suffit.

Puis :

```bash
sudo usermod -aG docker butterfly   # se reconnecter ensuite

mkdir ~/workspace && cd ~/workspace
git clone https://github.com/dalton0x0/butterfly.git
git clone https://github.com/dalton0x0/butterfly-front.git
git clone https://github.com/dalton0x0/butterfly-deploy.git
cd butterfly-deploy
```

Les dépôts privés demandent une clé de déploiement GitHub ou un jeton d'accès.

## 5. Configurer le .env

```bash
cp .env.example .env
chmod 600 .env
```

En plus des valeurs obligatoires habituelles (mots de passe MySQL, `JWT_SECRET` généré avec
`openssl rand -base64 48`, compte administrateur avec un vrai mot de passe), la pré-production
demande :

```dotenv
# nginx réservé au serveur : Caddy est le seul accès public
FRONTEND_PORT=127.0.0.1:8081

# L'adresse vue par le navigateur, dans les trois variables
DOMAIN=butterfly.cheridanh.fr
CORS_ALLOWED_ORIGINS=https://butterfly.cheridanh.fr
MAIL_FRONT_BASE_URL=https://butterfly.cheridanh.fr

ACME_EMAIL=vous@exemple.fr
```

Pour une séance de test en groupe depuis un même réseau (école, entreprise), tous les testeurs
partagent une adresse IP et donc le quota de connexions. Relever `RATE_LIMIT_IP_CAPACITY` (100
par exemple) le temps de la séance.

Créer aussi `swagger.htpasswd`, comme décrit dans le [README](README.md) : nginx refuse de
démarrer correctement sans lui. Le profil `prod` désactive cependant Swagger, la documentation
répond donc 404 après l'authentification. Pour la rouvrir le temps d'un test, ajouter
`SPRINGDOC_SWAGGER_UI_ENABLED: "true"` et `SPRINGDOC_API_DOCS_ENABLED: "true"` à l'environnement
du backend dans `docker-compose.preprod.yml`.

## 6. Premier démarrage et contenus de démonstration

Le premier démarrage garde Mailpit comme serveur d'envoi. C'est volontaire : le script de
démonstration confirme l'adresse de ses comptes en lisant les messages dans Mailpit et ces
adresses fictives (`@butterfly.local`) ne doivent jamais partir chez un vrai fournisseur.

```bash
docker compose -f docker-compose.yml -f docker-compose.preprod.yml up -d --build
docker compose ps   # attendre que backend soit "healthy"
```

La première construction prend plusieurs minutes. `https://butterfly.cheridanh.fr` doit ensuite
afficher la page de connexion avec un cadenas.

Chargement des contenus sans installer Node sur le serveur :

```bash
docker run --rm --network host --env-file .env \
  -e DEMO_API_URL=http://localhost:8081/api \
  -v "$PWD/demo:/demo:ro" node:22-alpine node /demo/seed.mjs
```

`--network host` donne au conteneur l'accès à `127.0.0.1:8081` (nginx) et `127.0.0.1:8025`
(Mailpit) du serveur. `docker run --env-file` lit les valeurs telles quelles : pas de guillemets
autour de `ADMIN_PASSWORD` dans le `.env`, ils feraient partie du mot de passe.

## 7. Passer à un envoi réel avec Brevo

1. Créer un compte sur [Brevo](https://www.brevo.com) (300 messages par jour en offre gratuite).
2. Dans **Expéditeurs, domaines et IP dédiées**, ajouter le domaine `cheridanh.fr`. Brevo donne
   des enregistrements DNS (code Brevo, DKIM, DMARC) à créer chez le registrar. S'il existe déjà
   un enregistrement SPF ou DMARC pour une autre messagerie, le **compléter** au lieu d'en ajouter
   un second : deux enregistrements SPF invalident les deux.
3. Dans **SMTP & API**, créer une clé SMTP.
4. Dans le `.env`, décommenter le bloc Brevo et renseigner :

   ```dotenv
   MAIL_HOST=smtp-relay.brevo.com
   MAIL_PORT=587
   MAIL_USERNAME=identifiant SMTP donné par Brevo
   MAIL_PASSWORD=clé SMTP
   MAIL_SMTP_AUTH=true
   MAIL_SMTP_STARTTLS=true
   MAIL_FROM=no-reply@cheridanh.fr
   ```

5. Relancer le backend : `docker compose -f docker-compose.yml -f docker-compose.preprod.yml up -d backend`.
6. Tester avec une vraie adresse : inscription, puis réception du message de confirmation.

Les comptes de démonstration gardent leur adresse fictive. Désactiver leurs notifications dans
**Profil, Notifications** évite que Brevo tente de leur écrire : un message vers une adresse
inexistante revient en erreur et dégrade la réputation de l'expéditeur.

Mailpit continue de tourner mais ne reçoit plus rien. Son interface reste consultable par un
tunnel SSH : `ssh -L 8025:127.0.0.1:8025 butterfly@<ip>`, puis `http://localhost:8025`.

## 8. Sauvegardes

`scripts/backup.sh` écrit deux archives horodatées (base et fichiers téléversés) et supprime
celles de plus de 7 jours (`BACKUP_RETENTION_DAYS`). Sauvegarde quotidienne à 3 h avec
`crontab -e` :

```cron
0 3 * * * /home/butterfly/workspace/butterfly-deploy/scripts/backup.sh >> /home/butterfly/backup.log 2>&1
```

Restauration :

```bash
# Base (remplace les données actuelles)
gunzip -c backups/butterfly-db-<date>.sql.gz \
  | docker compose exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot'

# Fichiers
docker compose exec -T backend tar xzf - -C /app < backups/butterfly-uploads-<date>.tar.gz
```

Une sauvegarde restée sur le serveur ne protège pas contre sa perte. Récupérer régulièrement le
dossier `backups` sur une autre machine (`rsync` ou `scp`) ou activer l'instantané de
l'hébergeur. Une restauration jamais essayée n'est pas une sauvegarde : la tester une fois.

## 9. Mettre à jour

```bash
cd ~/workspace
git -C butterfly pull && git -C butterfly-front pull && git -C butterfly-deploy pull
cd butterfly-deploy
scripts/backup.sh
docker compose -f docker-compose.yml -f docker-compose.preprod.yml up -d --build
```

Les migrations Flyway s'appliquent au démarrage du backend. La sauvegarde juste avant permet de
revenir en arrière si l'une d'elles pose problème.

## Dépannage

| Symptôme                                      | Cause probable                                                                                       |
|-----------------------------------------------|------------------------------------------------------------------------------------------------------|
| `port is already allocated` sur le port 80    | `FRONTEND_PORT` n'est pas à `127.0.0.1:8081`                                                         |
| Pas de certificat, erreur TLS                 | DNS pas encore propagé ou ports 80 et 443 fermés chez l'hébergeur. Voir `docker compose logs caddy` |
| Erreur CORS dans la console                   | `CORS_ALLOWED_ORIGINS` différent de l'adresse tapée (http/https, www)                                |
| Liens des e-mails vers localhost              | `MAIL_FRONT_BASE_URL` non renseignée                                                                 |
| Connexions refusées en 429 pendant une séance | Testeurs derrière une même IP : relever `RATE_LIMIT_IP_CAPACITY`                                     |
| Backend tué avec le code 137                  | Mémoire épuisée : relever `BACKEND_MEM_LIMIT` ou prendre un serveur plus grand                       |

Journaux d'un service : `docker compose logs -f backend` (ou `caddy`, `frontend`, `mysql`).
