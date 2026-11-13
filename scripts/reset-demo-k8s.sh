#!/usr/bin/env bash
#
# Remise à zéro de la démonstration en ligne (namespace butterfly-demo).
#
# Usage, sur le serveur : scripts/reset-demo-k8s.sh [--yes]
#
# Vide la base et les fichiers téléversés, vide le cache puis redémarre le backend. Au
# redémarrage, Flyway recrée le schéma et le backend recrée le compte administrateur de
# backend-secrets : on repart d'une installation neuve. Tous les comptes de démonstration
# disparaissent, leurs sessions ouvertes aussi.
#
# Les contenus se rechargent ensuite depuis le poste, par l'API publique :
#   node --env-file=demo/.env.demo demo/seed.mjs
#
# Le namespace est écrit en dur : le script ne peut viser ni le staging ni la production.
# Les volumes ne sont pas supprimés. On vide leur contenu, ce qui évite d'arrêter les pods
# pendant qu'Argo CD les relance aussitôt (selfHeal).
#
# --yes saute la question de confirmation.

set -euo pipefail

readonly NAMESPACE=butterfly-demo
readonly BACKEND_SELECTOR=app.kubernetes.io/name=backend

fail() { printf 'ERREUR : %s\n' "$1" >&2; exit 1; }

command -v kubectl >/dev/null || fail "kubectl est introuvable : ce script se lance sur le serveur."
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || fail "le namespace $NAMESPACE n'existe pas."

if [[ "${1:-}" != "--yes" ]]; then
    echo "Toutes les données de la démonstration ($NAMESPACE) vont être supprimées :"
    echo "comptes, contenus, rendus et fichiers téléversés."
    read -r -p "Taper « demo » pour confirmer : " answer
    [[ "$answer" == "demo" ]] || { echo "Abandon."; exit 0; }
fi

echo "==> Fichiers téléversés"
# Seuls les fichiers sont supprimés : les dossiers créés au démarrage restent en place.
kubectl -n "$NAMESPACE" exec deploy/backend -c backend -- \
    find /app/uploads -type f -delete

echo "==> Base de données"
# Les variables sont lues dans le conteneur MySQL : le mot de passe root ne transite pas
# par ce script. MYSQL_PWD évite aussi de le passer en argument de la commande.
# Les droits de l'utilisateur de l'application portent sur le nom de la base : ils
# survivent à sa suppression et valent pour la base recréée.
kubectl -n "$NAMESPACE" exec mysql-0 -c mysql -- sh -c \
    'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -e "DROP DATABASE IF EXISTS \`$MYSQL_DATABASE\`; CREATE DATABASE \`$MYSQL_DATABASE\`;"'

echo "==> Cache"
kubectl -n "$NAMESPACE" exec deploy/redis -c redis -- redis-cli FLUSHALL >/dev/null

echo "==> Redémarrage du backend"
# Suppression du pod plutôt que kubectl rollout restart : le redémarrage ajoute une
# annotation au Deployment, qu'Argo CD retirerait aussitôt en relançant un second
# déploiement.
old_pods="$(kubectl -n "$NAMESPACE" get pods -l "$BACKEND_SELECTOR" -o name)"
# shellcheck disable=SC2086 # un nom de pod par mot
kubectl -n "$NAMESPACE" delete $old_pods --wait=true
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod -l "$BACKEND_SELECTOR" --timeout=300s

echo
echo "Démonstration remise à zéro. Pour recharger les contenus, depuis le poste :"
echo "  node --env-file=demo/.env.demo demo/seed.mjs"
