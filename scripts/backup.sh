#!/usr/bin/env bash
#
# Sauvegarde de la base et des fichiers téléversés.
#
# Usage : scripts/backup.sh [répertoire] (./backups par défaut)
#
# Produit deux archives horodatées puis supprime celles de plus de
# BACKUP_RETENTION_DAYS jours (7 par défaut). Prévu pour une tâche cron, voir PREPROD.md.
#
# Les services doivent tourner : la sauvegarde passe par les conteneurs mysql et backend.
# Aucun mot de passe n'apparaît ici. mysqldump lit celui du conteneur dans sa propre
# variable d'environnement.

set -euo pipefail

# Le script peut être lancé depuis n'importe où, cron compris : docker compose doit
# trouver docker-compose.yml et le .env du dépôt.
cd "$(dirname "$0")/.."

DESTINATION="${1:-./backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
STAMP="$(date +%F-%H%M)"

mkdir -p "$DESTINATION"

# --single-transaction : copie cohérente sans bloquer l'application pendant le vidage.
# MYSQL_PWD évite le mot de passe en argument, visible dans la liste des processus. Les
# guillemets simples empêchent l'hôte de remplacer les variables : c'est le shell du
# conteneur qui les lit.
dump_database() {
    docker compose exec -T mysql sh -c \
        'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot --single-transaction --routines --triggers --databases "$MYSQL_DATABASE"' \
        | gzip
}

# Rendus, pièces jointes et médias.
archive_uploads() {
    docker compose exec -T backend tar czf - -C /app uploads
}

# Chaque archive est écrite sous un nom temporaire puis renommée une fois complète :
# une sauvegarde interrompue ne laisse jamais un fichier tronqué qui passerait pour bon.
# pipefail fait échouer dump_database si mysqldump échoue, même si gzip réussit.
save() {
    local target="$1"
    local producer="$2"
    "$producer" > "$target.part"
    mv "$target.part" "$target"
    echo "Sauvegarde écrite : $target"
}

save "$DESTINATION/butterfly-db-$STAMP.sql.gz" dump_database
save "$DESTINATION/butterfly-uploads-$STAMP.tar.gz" archive_uploads

find "$DESTINATION" -maxdepth 1 -name 'butterfly-*' -mtime +"$RETENTION_DAYS" -delete
