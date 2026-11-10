#!/usr/bin/env bash
#
# Installation d'Argo CD sur le cluster k3s et raccordement au dépôt de déploiement.
#
# Argo CD est le seul composant installé à la main. Tout le reste (cert-manager,
# Butterfly) est décrit dans le dépôt et installé par Argo CD lui-même : l'état du
# cluster se lit dans Git, et un serveur perdu se reconstruit avec k3s, ce script et
# le dépôt.
#
# Prérequis :
#   - k3s installé, kubectl fonctionnel pour l'utilisateur courant ;
#   - le dossier k8s/ de ce dépôt poussé sur la branche suivie (main).
#
# Usage, sur le serveur, en utilisateur d'administration (pas en root) :
#
#   bash install-argocd.sh
#
# Le script s'arrête une fois, le temps d'ajouter la clé de déploiement sur GitHub.
# Il peut être relancé sans dommage.

set -euo pipefail

# Version épinglée : une installation rejouée donne le même résultat. La montée de
# version se fait en changeant cette valeur, après lecture des notes de mise à niveau.
ARGOCD_VERSION=v3.6.1

REPO_URL=git@github.com:dalton0x0/butterfly-deploy.git
REPO_SECRET=repo-butterfly-deploy
DEPLOY_KEY="$HOME/argocd-deploy-key"
INSTALL_MANIFEST=https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

log() { printf '\n==> %s\n' "$1"; }
fail() { printf '\nERREUR : %s\n' "$1" >&2; exit 1; }

[[ $EUID -ne 0 ]] || fail "le script se lance en utilisateur d'administration, pas en root."
[[ -t 0 ]] || fail "le script doit être lancé dans une session interactive."
kubectl get nodes >/dev/null || fail "kubectl ne joint pas le cluster."

# --- 1. Installation ------------------------------------------------------------

log "Installation d'Argo CD $ARGOCD_VERSION"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
# --server-side : certaines définitions (ApplicationSet) dépassent la taille maximale
# d'annotation de l'application côté client.
# --force-conflicts : reprend la main sur les champs posés par une installation
# précédente, nécessaire lors d'une mise à niveau.
kubectl apply -n argocd --server-side --force-conflicts -f "$INSTALL_MANIFEST"

log "Attente du démarrage des composants"
kubectl -n argocd wait --for=condition=Available deployment --all --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

# --- 2. Clé de déploiement -------------------------------------------------------

# Le dépôt est privé : Argo CD le lit avec une clé SSH dédiée, en lecture seule et
# limitée à ce dépôt. Une fuite de cette clé ne donne accès qu'à ce dépôt, sans
# possibilité d'y écrire.
if kubectl -n argocd get secret "$REPO_SECRET" >/dev/null 2>&1; then
    log "Accès au dépôt déjà configuré ($REPO_SECRET)"
else
    log "Clé de déploiement pour $REPO_URL"
    [[ -f "$DEPLOY_KEY" ]] || ssh-keygen -q -t ed25519 -N '' -C argocd-butterfly-deploy -f "$DEPLOY_KEY"

    cat <<EOF

------------------------------------------------------------------------------
Ajouter cette clé publique sur GitHub :
  dépôt butterfly-deploy > Settings > Deploy keys > Add deploy key
  Title : argocd
  Allow write access : NON coché

$(cat "$DEPLOY_KEY.pub")
------------------------------------------------------------------------------
EOF
    read -r -p "Clé ajoutée sur GitHub ? Saisir OUI pour continuer : " answer
    [[ "$answer" == "OUI" ]] || fail "arrêt. La clé reste dans $DEPLOY_KEY pour la prochaine exécution."

    # Le label signale à Argo CD que ce Secret décrit un dépôt. La clé privée n'existe
    # ensuite que dans le cluster, où le chiffrement des Secrets de k3s la protège.
    kubectl -n argocd create secret generic "$REPO_SECRET" \
        --from-literal=type=git \
        --from-literal=url="$REPO_URL" \
        --from-file=sshPrivateKey="$DEPLOY_KEY"
    kubectl -n argocd label secret "$REPO_SECRET" argocd.argoproj.io/secret-type=repository
    shred -u "$DEPLOY_KEY"
    rm -f "$DEPLOY_KEY.pub"
fi

# --- 3. Application racine ---------------------------------------------------------

# Modèle « app of apps » : l'application racine surveille k8s/apps et crée chaque
# application qui y est déclarée. Ajouter un composant au cluster revient à ajouter
# un fichier dans ce dossier.
log "Application racine"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: main
    path: k8s/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

cat <<'EOF'

Terminé. Accès à l'interface, depuis le poste local :

  ssh -t -L 8443:127.0.0.1:8080 <utilisateur>@<serveur> \
    kubectl --kubeconfig .kube/config port-forward -n argocd svc/argocd-server 8080:443

puis https://localhost:8443 (certificat autosigné : avertissement attendu).

Mot de passe initial du compte admin, à changer dès la première connexion :

  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d; echo

Une fois le mot de passe changé, supprimer ce Secret, qui le garde en clair :

  kubectl -n argocd delete secret argocd-initial-admin-secret
EOF
