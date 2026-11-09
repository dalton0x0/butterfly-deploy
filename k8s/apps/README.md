# Applications Argo CD

L'application racine (`root`, créée par `server/install-argocd.sh`) surveille ce dossier. Chaque
fichier YAML déposé ici déclare une application Argo CD, qu'elle crée et tient à jour.

- Ajouter un composant au cluster : ajouter son fichier `Application` ici.
- Retirer un composant : supprimer son fichier. Grâce à `prune`, Argo CD supprime aussi les
  ressources correspondantes.

Argo CD ne lit que les fichiers `.yaml`, `.yml` et `.json` : ce README est ignoré.
