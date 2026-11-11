#!/usr/bin/env bash
#
# Contrôle quotidien de l'état du serveur, signalé à Healthchecks.io.
#
# Trois vérifications :
#   - k3s tourne ;
#   - aucun redémarrage n'est en attente (nouveau noyau ou bibliothèque système installé
#     par les mises à jour automatiques, qui ne redémarrent jamais le serveur) ;
#   - aucun système de fichiers n'est rempli au-delà du seuil. Un disque plein bloque
#     MySQL, les sauvegardes et le téléchargement des images.
#
# Le script signale à chaque exécution la réussite, ou l'échec avec la liste des
# problèmes. Healthchecks.io prévient aussi quand le signal n'arrive plus : serveur
# éteint, injoignable ou script arrêté.
#
# Installation, sur le serveur, depuis le dossier server/ :
#
#   sudo install -m 755 healthcheck.sh /usr/local/sbin/butterfly-healthcheck
#   sudo install -m 600 /dev/null /etc/butterfly-healthcheck-url
#   sudoedit /etc/butterfly-healthcheck-url      # coller l'adresse de signalement
#   echo '17 9 * * * root /usr/local/sbin/butterfly-healthcheck' \
#     | sudo tee /etc/cron.d/butterfly-healthcheck
#   sudo /usr/local/sbin/butterfly-healthcheck   # premier signal, pour vérifier
#
# L'adresse de signalement est lisible par root seulement : quiconque la connaît peut
# envoyer de faux signaux.

set -euo pipefail

URL_FILE=/etc/butterfly-healthcheck-url
# Au-delà, l'alerte laisse le temps d'agir avant que le disque ne soit plein.
DISK_THRESHOLD=85

URL="$(tr -d '[:space:]' < "$URL_FILE")"
problems=()

systemctl is-active --quiet k3s || problems+=("k3s ne tourne pas")

if [[ -f /var/run/reboot-required ]]; then
    problems+=("redémarrage en attente ($(tr '\n' ' ' < /var/run/reboot-required.pkgs 2>/dev/null || true))")
fi

# Systèmes de fichiers réels seulement : les systèmes temporaires (tmpfs, overlay des
# conteneurs) ne disent rien de l'état du disque.
while read -r usage mount; do
    usage="${usage%\%}"
    if (( usage >= DISK_THRESHOLD )); then
        problems+=("$mount rempli à $usage %")
    fi
done < <(df --output=pcent,target -x tmpfs -x devtmpfs -x overlay -x squashfs | tail -n +2)

# Le détail des problèmes accompagne le signal : Healthchecks.io l'affiche dans l'alerte.
if (( ${#problems[@]} == 0 )); then
    curl -fsS -m 10 --retry 3 -o /dev/null --data-raw "OK" "$URL"
else
    printf '%s\n' "${problems[@]}" >&2
    curl -fsS -m 10 --retry 3 -o /dev/null --data-raw "$(printf '%s\n' "${problems[@]}")" "$URL/fail"
    exit 1
fi
