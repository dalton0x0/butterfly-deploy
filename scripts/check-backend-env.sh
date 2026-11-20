#!/usr/bin/env bash
#
# Vérifie les deux catalogues des réglages du backend : celui de Kubernetes
# (k8s/butterfly/base/backend.env) et celui de Docker Compose (.env.example).
#
# Usage : scripts/check-backend-env.sh <dossier du dépôt backend>
#
# Kubernetes :
#   1. chaque variable lue par le backend figure dans base/backend.env, active,
#      commentée ou signalée comme secret ;
#   2. aucun backend.env (base ou environnement) ne règle une variable inconnue du
#      backend, ce qui attrape une faute de frappe restée sans effet.
#
# Docker Compose :
#   3. chaque variable lue par le backend est transmise par le service backend de
#      docker-compose.yml, sauf celles que la stack fixe autrement (COMPOSE_NOT_PASSED) ;
#   4. le service backend ne transmet pas de nom inconnu du backend ;
#   5. chaque variable du .env lue par le service backend figure dans .env.example.
#
# Les variables du backend viennent des ${NOM...} de application.yaml et
# application-docker.yml. Les profils dev et prod ne sont pas lus : Kubernetes et
# Compose utilisent le profil docker.

set -euo pipefail

cd "$(dirname "$0")/.."

BACKEND_DIR="${1:?Usage : scripts/check-backend-env.sh <dossier du dépôt backend>}"
RESOURCES="$BACKEND_DIR/src/main/resources"
CATALOGUE="k8s/butterfly/base/backend.env"
COMPOSE_FILE="docker-compose.yml"
ENV_EXAMPLE=".env.example"

# Variables lues par la JVM ou par Spring sans passer par un ${...} des fichiers.
# TZ : fuseau du conteneur. SPRINGDOC_* : liaison directe de Spring sur les propriétés
# springdoc.*.enabled du profil docker.
EXTRA_NAMES="TZ SPRINGDOC_SWAGGERUI_ENABLED SPRINGDOC_APIDOCS_ENABLED"

# Variables du backend que Compose ne transmet pas exprès. SERVER_PORT : le contrôle de
# santé et nginx visent le port 8080. APP_NAME : dans le .env, ce nom est celui de
# l'interface, pas celui de l'application Spring. REDIS_PASSWORD : Redis n'a pas de mot
# de passe dans la stack, il n'est joignable que depuis son réseau.
COMPOSE_NOT_PASSED="SERVER_PORT APP_NAME REDIS_PASSWORD"

for file in "$RESOURCES/application.yaml" "$RESOURCES/application-docker.yml"; do
    [[ -f "$file" ]] || { printf 'Fichier introuvable : %s\n' "$file" >&2; exit 2; }
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

status=0

# Affiche une liste de noms et marque l'échec quand elle n'est pas vide.
report() {
    local title="$1" names="$2"
    if [[ -n "$names" ]]; then
        printf '%s :\n%s\n\n' "$title" "$names" >&2
        status=1
    fi
}

grep -ohE '\$\{[A-Z_]+' "$RESOURCES/application.yaml" "$RESOURCES/application-docker.yml" \
    | cut -c3- | sort -u > "$work/code"
{ cat "$work/code"; printf '%s\n' $EXTRA_NAMES; } | sort -u > "$work/known"

# --- Kubernetes ----------------------------------------------------------------------

# Noms du catalogue : NOM=, #NOM= et « # secret NOM ».
{
    sed -nE 's/^#?([A-Z_]+)=.*/\1/p' "$CATALOGUE"
    sed -nE 's/^# secret ([A-Z_]+).*/\1/p' "$CATALOGUE"
} | sort -u > "$work/catalogue"

report "Variables du backend absentes de $CATALOGUE" "$(comm -23 "$work/code" "$work/catalogue")"

for env_file in k8s/butterfly/*/backend.env; do
    sed -nE 's/^#?([A-Z_]+)=.*/\1/p' "$env_file" | sort -u > "$work/used"
    report "Variables inconnues du backend dans $env_file" "$(comm -23 "$work/used" "$work/known")"
done

# --- Docker Compose ------------------------------------------------------------------

# Bloc environment: du service backend. Le fichier suit l'indentation habituelle de
# Compose (deux espaces par niveau) : le bloc s'arrête à la clé suivante du service.
awk '
    /^  backend:/ { in_service = 1; next }
    in_service && /^  [a-z]/ { exit }
    in_service && /^    environment:/ { in_env = 1; next }
    in_env && /^    [a-z_]+:/ { exit }
    in_env && /^      [A-Z_]+:/ { sub(/^ +/, ""); print }
' "$COMPOSE_FILE" > "$work/compose_lines"

[[ -s "$work/compose_lines" ]] || { printf 'Bloc environment du backend introuvable dans %s\n' "$COMPOSE_FILE" >&2; exit 2; }

cut -d: -f1 "$work/compose_lines" | sort -u > "$work/compose_keys"
{ cat "$work/compose_keys"; printf '%s\n' $COMPOSE_NOT_PASSED; } | sort -u > "$work/compose_covered"

report "Variables du backend non transmises par $COMPOSE_FILE" "$(comm -23 "$work/code" "$work/compose_covered")"
report "Variables inconnues du backend dans $COMPOSE_FILE" "$(comm -23 "$work/compose_keys" "$work/known")"

# Variables lues dans le .env : les ${NOM...} des valeurs et les noms écrits sans valeur.
{
    grep -oE '\$\{[A-Z_]+' "$work/compose_lines" | cut -c3- || true
    sed -nE 's/^([A-Z_]+):[[:space:]]*$/\1/p' "$work/compose_lines"
} | sort -u > "$work/compose_from_env"

sed -nE 's/^#?([A-Z_]+)=.*/\1/p' "$ENV_EXAMPLE" | sort -u > "$work/env_example"

report "Variables lues par le backend dans le .env mais absentes de $ENV_EXAMPLE" \
    "$(comm -23 "$work/compose_from_env" "$work/env_example")"

if [[ $status -eq 0 ]]; then
    printf 'Catalogues complets : %s variables du backend, aucun nom inconnu.\n' \
        "$(wc -l < "$work/code" | tr -d ' ')"
fi
exit $status
