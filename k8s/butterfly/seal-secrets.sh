#!/usr/bin/env bash
#
# Production des secrets chiffrés (SealedSecrets) d'un environnement de Butterfly.
#
# Les valeurs sont saisies au clavier, sans écho, et ne sont jamais écrites sur le
# disque en clair : le Secret est construit en mémoire puis transmis directement à
# kubeseal. Seuls les fichiers chiffrés sont écrits, dans <environnement>/secrets/. Ils
# se commitent sans risque.
#
# Prérequis : kubeseal (brew install kubeseal) et le certificat public
# k8s/sealed-secrets-cert.pem. Aucun accès au cluster n'est nécessaire.
#
# Usage, depuis n'importe quel dossier :
#
#   k8s/butterfly/seal-secrets.sh staging                    tous les secrets
#   k8s/butterfly/seal-secrets.sh staging backend-secrets    un seul secret
#
# Secrets disponibles :
#   mysql-credentials  mots de passe MySQL (root et compte de l'application)
#   backend-secrets    clé JWT, compte administrateur, identifiants SMTP (prod)
#   swagger-htpasswd   comptes autorisés à consulter Swagger
#   ghcr-pull          jeton de lecture des images privées de GHCR
#
# Les valeurs saisies se conservent dans un gestionnaire de mots de passe : un secret
# chiffré ne se relit pas.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERT="$SCRIPT_DIR/../sealed-secrets-cert.pem"

fail() { printf 'ERREUR : %s\n' "$1" >&2; exit 1; }

ENVIRONMENT="${1:-}"
ONLY="${2:-}"

case "$ENVIRONMENT" in
    staging | prod) ;;
    *) fail "usage : $0 staging|prod [nom-du-secret]" ;;
esac

NAMESPACE="butterfly-$ENVIRONMENT"
OUT_DIR="$SCRIPT_DIR/$ENVIRONMENT/secrets"

command -v kubeseal >/dev/null || fail "kubeseal est introuvable (brew install kubeseal)."
[[ -f "$CERT" ]] || fail "certificat absent : $CERT (voir k8s/README.md)."
mkdir -p "$OUT_DIR"

# Encodage base64 sur une seule ligne. base64 de GNU coupe les lignes longues, pas
# celui de macOS : tr harmonise les deux.
b64() { printf '%s' "$1" | base64 | tr -d '\n'; }

# Saisie masquée d'une valeur obligatoire.
ask_secret() {
    local value
    read -r -s -p "$1 : " value
    printf '\n' >&2
    [[ -n "$value" ]] || fail "valeur vide pour $1."
    printf '%s' "$value"
}

# Saisie visible, avec valeur par défaut.
ask() {
    local value
    read -r -p "$1 [$2] : " value
    printf '%s' "${value:-$2}"
}

# Chiffre un Secret lu sur l'entrée standard et l'écrit dans <nom>.sealed.yaml.
# Le secret chiffré n'est déchiffrable que sous ce nom et dans ce namespace.
seal() {
    kubeseal --cert "$CERT" --format yaml > "$OUT_DIR/$1.sealed.yaml"
    printf '==> %s\n' "${OUT_DIR#"$SCRIPT_DIR"/}/$1.sealed.yaml"
}

# Début commun des Secrets : $1 nom, $2 type.
secret_header() {
    cat <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $1
  namespace: $NAMESPACE
type: $2
data:
EOF
}

seal_mysql_credentials() {
    printf '\n--- mysql-credentials\n' >&2
    printf 'Lus au premier démarrage seulement, sur une base vierge : les modifier ensuite\n' >&2
    printf 'ne change pas les mots de passe déjà enregistrés dans MySQL.\n' >&2
    local user password root
    user="$(ask "Utilisateur de l'application" butterfly)"
    password="$(ask_secret "Mot de passe de l'application")"
    root="$(ask_secret "Mot de passe root")"
    {
        secret_header mysql-credentials Opaque
        printf '  DB_USERNAME: %s\n' "$(b64 "$user")"
        printf '  DB_PASSWORD: %s\n' "$(b64 "$password")"
        printf '  MYSQL_ROOT_PASSWORD: %s\n' "$(b64 "$root")"
    } | seal mysql-credentials
}

seal_backend_secrets() {
    printf '\n--- backend-secrets\n' >&2
    printf 'Clé JWT : 32 caractères minimum, générée par openssl rand -base64 48.\n' >&2
    local jwt email password mail_user="" mail_password=""
    jwt="$(ask_secret "Clé JWT (JWT_SECRET)")"
    [[ ${#jwt} -ge 32 ]] || fail "la clé JWT doit faire au moins 32 caractères."
    email="$(ask "E-mail du compte administrateur" "admin@butterfly.local")"
    password="$(ask_secret "Mot de passe du compte administrateur")"
    # En prod, le relais SMTP réel exige une authentification. Le staging utilise
    # Mailpit, qui n'en demande pas.
    if [[ "$ENVIRONMENT" == prod ]]; then
        mail_user="$(ask_secret "Identifiant SMTP Brevo")"
        mail_password="$(ask_secret "Clé SMTP Brevo")"
    fi
    {
        secret_header backend-secrets Opaque
        printf '  JWT_SECRET: %s\n' "$(b64 "$jwt")"
        printf '  ADMIN_EMAIL: %s\n' "$(b64 "$email")"
        printf '  ADMIN_PASSWORD: %s\n' "$(b64 "$password")"
        if [[ "$ENVIRONMENT" == prod ]]; then
            printf '  MAIL_USERNAME: %s\n' "$(b64 "$mail_user")"
            printf '  MAIL_PASSWORD: %s\n' "$(b64 "$mail_password")"
        fi
    } | seal backend-secrets
}

seal_swagger_htpasswd() {
    printf '\n--- swagger-htpasswd\n' >&2
    printf 'Fichier au format htpasswd, produit par exemple par :\n' >&2
    printf '  htpasswd -nB <utilisateur> > swagger.htpasswd\n' >&2
    local file
    file="$(ask "Chemin du fichier" "swagger.htpasswd")"
    [[ -f "$file" ]] || fail "fichier introuvable : $file."
    {
        secret_header swagger-htpasswd Opaque
        printf '  swagger.htpasswd: %s\n' "$(base64 < "$file" | tr -d '\n')"
    } | seal swagger-htpasswd
}

seal_ghcr_pull() {
    printf '\n--- ghcr-pull\n' >&2
    printf 'Jeton GitHub classique, avec le seul droit read:packages.\n' >&2
    local user token config
    user="$(ask "Compte GitHub" "dalton0x0")"
    token="$(ask_secret "Jeton (read:packages)")"
    # Format attendu par Kubernetes pour les identifiants d'un registre d'images.
    config="{\"auths\":{\"ghcr.io\":{\"auth\":\"$(b64 "$user:$token")\"}}}"
    {
        secret_header ghcr-pull kubernetes.io/dockerconfigjson
        printf '  .dockerconfigjson: %s\n' "$(b64 "$config")"
    } | seal ghcr-pull
}

case "$ONLY" in
    "")
        seal_mysql_credentials
        seal_backend_secrets
        seal_swagger_htpasswd
        seal_ghcr_pull
        ;;
    mysql-credentials) seal_mysql_credentials ;;
    backend-secrets) seal_backend_secrets ;;
    swagger-htpasswd) seal_swagger_htpasswd ;;
    ghcr-pull) seal_ghcr_pull ;;
    *) fail "secret inconnu : $ONLY." ;;
esac
