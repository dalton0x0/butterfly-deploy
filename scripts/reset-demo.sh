#!/usr/bin/env bash
#
# Remise à zéro de la pile locale puis rechargement des contenus de démonstration.
#
# Usage : scripts/reset-demo.sh [--yes]
#
# Supprime la base et les fichiers téléversés, redémarre la pile, puis lance
# demo/seed.mjs. Au redémarrage, Flyway recrée le schéma et le backend recrée le
# compte administrateur du .env : on repart de l'état d'une installation neuve.
#
# Réservé au poste de développement. Le script refuse de tourner si le .env désigne
# un vrai relais SMTP (MAIL_HOST autre que mailpit) : c'est le signe d'une
# pré-production, dont il effacerait les données. Le chargement de la démo a de toute
# façon besoin de Mailpit pour lire les invitations.
#
# --yes saute la question de confirmation.

set -euo pipefail

# Le script peut être lancé depuis n'importe où : docker compose doit trouver
# docker-compose.yml et le .env du dépôt.
cd "$(dirname "$0")/.."

# Volumes effacés. Les volumes de SonarQube (profil tools) ne sont pas concernés.
DATA_VOLUMES=(mysql_data backend_uploads)

mail_host="$(sed -n 's/^MAIL_HOST=//p' .env | tail -n 1)"
if [[ -n "$mail_host" && "$mail_host" != "mailpit" ]]; then
    echo "Refus : MAIL_HOST vaut « $mail_host » dans le .env." >&2
    echo "Cette pile envoie de vrais e-mails, ce n'est pas un poste de développement." >&2
    exit 1
fi

# Nom du projet compose, préfixe du nom réel des volumes (dossier du dépôt par défaut).
project="$(docker compose config | sed -n 's/^name: //p' | head -n 1)"

if [[ "${1:-}" != "--yes" ]]; then
    echo "La base et les fichiers téléversés du projet « $project » vont être supprimés."
    read -r -p "Continuer ? [o/N] " answer
    [[ "$answer" == "o" || "$answer" == "O" ]] || { echo "Abandon."; exit 0; }
fi

echo "Arrêt des services..."
# rm -s arrête puis supprime les conteneurs du profil par défaut. Le réseau est conservé :
# un conteneur du profil tools encore lancé n'empêche donc pas la remise à zéro.
# Redis et le cache d'images de nginx ne vivent que dans leurs conteneurs : ils repartent
# vides eux aussi.
docker compose rm --stop --force

echo "Suppression des volumes de données..."
for volume in "${DATA_VOLUMES[@]}"; do
    docker volume rm "${project}_${volume}" >/dev/null 2>&1 || true
done

echo "Redémarrage de la pile (attente des contrôles de santé)..."
docker compose up -d --wait

echo "Chargement des contenus de démonstration..."
node --env-file=.env demo/seed.mjs
