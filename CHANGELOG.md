# Historique des versions - Butterfly Deploy

Toutes les versions notables de l'interface Butterfly, de la plus récente à la plus ancienne.

Le projet suit le versionnage sémantique. Une version majeure marque une rupture de
compatibilité, une mineure ajoute des capacités, un correctif répare sans rien ajouter.

Chaque version correspond à un tag Git annoté du même nom. Le titre de chaque section
renvoie vers la comparaison GitHub avec la version précédente, c'est-à-dire l'ensemble des
commits qu'elle apporte. La toute première version renvoie vers son tag n'ayant pas de prédécesseur.

---

## [v1.2.0](https://github.com/dalton0x0/butterfly-deploy/compare/v1.1.0...v1.2.0) - 2026-09-10

Durcissement des réglages par défaut. SonarQube ne redémarre plus tout seul une fois
créé par le profil `tools` : sa politique de redémarrage le relançait à chaque démarrage du
démon Docker, deux gigaoctets consommés en arrière-plan sur une machine où l'on ne travaille
plus sur le projet. Son image est épinglée comme les autres, une montée de version majeure
changeant les règles d'analyse. Plafonds mémoire sur MySQL, le backend et SonarQube pour
qu'un service qui dérive ne fasse pas tuer ses voisins par le noyau. Le frontend n'attend plus
la bonne santé du backend : servie tout de suite, l'interface affiche au moins sa page de
connexion et le message d'erreur du premier appel là où l'attente donnait une connexion
refusée sans aucune indication. Procédure de sauvegarde des volumes documentée.

## [v1.1.0](https://github.com/dalton0x0/butterfly-deploy/compare/v1.0.3...v1.1.0) - 2026-09-07

Durcissement de la façade. Le nginx du frontend réécrit `X-Forwarded-For` avec
`$remote_addr` au lieu de le compléter avec `$proxy_add_x_forwarded_for`. La seconde variante
conservait la valeur envoyée par le client, or le backend retient la première entrée pour sa
limitation de débit : n'importe quel appelant disposait d'un compteur neuf à chaque requête et la
protection du formulaire de connexion ne servait à rien. Documentation de l'API désormais
protégée par authentification basique, ce qui introduit une étape d'installation obligatoire : le
fichier `swagger.htpasswd` doit exister avant le premier démarrage, Docker créant un répertoire à
sa place dans le cas contraire.

## [v1.0.3](https://github.com/dalton0x0/butterfly-deploy/compare/v1.0.2...v1.0.3) - 2026-08-31

Correctifs d'orchestration. Les réglages optionnels du parcours documentés dans le
`.env` atteignent enfin le conteneur. Compose lit ce fichier pour remplacer les `${...}` du
`docker-compose.yml`, il ne transmet rien aux services de lui-même si bien que les décommenter
restait sans effet (`LEARNING_QUIZ_ABANDON_GRACE_SECONDS`, limites des pièces jointes).
Ajout du plafond de taille de page (`PAGE_MAX_SIZE`). Contrôle de santé sur le frontend, le
seul service applicatif qui n'en avait pas. Version de Mailpit épinglée sur sa release mineure
au lieu de `latest`. Couplage de `FRONTEND_PORT`, `CORS_ALLOWED_ORIGINS` et `MAIL_FRONT_BASE_URL`
signalé aux deux endroits, faute de quoi un changement de port casse silencieusement les liens des e-mails.

## [v1.0.2](https://github.com/dalton0x0/butterfly-deploy/compare/v1.0.1...v1.0.2) - 2026-08-31

Suivi des évolutions applicatives 1.4.0. Répertoire dédié aux fichiers joints aux
énoncés d'exercices (`EXERCISE_ATTACHMENT_LOCATION`) volontairement séparé des soumissions pour
qu'une purge de celles-ci n'emporte pas les consignes et documentation des réglages optionnels
du parcours (délai de grâce des tentatives de quiz, limites des pièces jointes). Aucun volume
supplémentaire : `backend_uploads` monte `/app/uploads` en entier.

## [v1.0.1](https://github.com/dalton0x0/butterfly-deploy/compare/v1.0.0...v1.0.1) - 2026-08-05

Durcissement et documentation. Mot de passe root retiré du contrôle de santé MySQL (il
était inscrit dans la configuration du conteneur lisible par `docker inspect` et inutile au
ping), configuration mail entièrement surchargeable depuis le `.env` (Mailpit par défaut, Brevo
en décommentant un bloc), correspondance de port adaptée au nginx non privilégié du frontend
(8080 interne), nom et slogan de l'interface transmis au build du frontend (`APP_NAME`,
`APP_TAGLINE`), `.gitignore` réduit à l'essentiel, rédaction de ce README.

## [v1.0.0](https://github.com/dalton0x0/butterfly-deploy/releases/tag/v1.0.0) - 2026-08-03

Première version. Orchestration complète (MySQL, Mailpit, backend, frontend) avec
contrôles de santé en cascade, volumes nommés, SonarQube dans un profil dédié et configuration
entièrement portée par le fichier `.env`.
