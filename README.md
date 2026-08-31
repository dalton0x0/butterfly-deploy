# Butterfly - Déploiement

Orchestration conteneurisée complète de la plateforme Butterfly : base de données, messagerie de
développement, API Spring Boot et interface Vue servie par nginx. Ce dépôt ne contient aucun code
applicatif : le backend et le frontend vivent dans leurs propres dépôts et y portent chacun leur
`Dockerfile`. Celui-ci les assemble.

## Sommaire

- [Arborescence attendue](#arborescence-attendue)
- [Prérequis](#prérequis)
- [Démarrage rapide](#démarrage-rapide)
- [Services](#services)
- [Ordre de démarrage et contrôles de santé](#ordre-de-démarrage-et-contrôles-de-santé)
- [Configuration](#configuration)
- [Données persistantes](#données-persistantes)
- [SonarQube](#sonarqube)
- [Commandes utiles](#commandes-utiles)
- [Limites assumées](#limites-assumées)
- [Historique des versions](#historique-des-versions)

## Arborescence attendue

Les trois dépôts sont clonés côte à côte. Les chemins vers le backend et le frontend sont
configurables (`BACKEND_PATH` et `FRONTEND_PATH` dans le `.env`) si vos clones portent d'autres
noms ou vivent ailleurs.

```
workspace/
  butterfly/            dépôt backend, contient son propre Dockerfile
  butterfly-front/      dépôt frontend, contient son Dockerfile et nginx.conf
  butterfly-deploy/     ce dépôt
    docker-compose.yml
    .env
```

## Prérequis

- Docker et Docker Compose (plugin `docker compose`, pas l'ancien `docker-compose`)
- Environ 2 Go de mémoire disponibles pour les services applicatifs, 4 Go si SonarQube est lancé

## Démarrage rapide

```bash
cp .env.example .env
openssl rand -base64 48        # à coller dans JWT_SECRET
# renseigner les mots de passe marqués obligatoires dans .env
docker compose up -d --build
```

Une fois les contrôles de santé passés (le backend met une à deux minutes à démarrer) :

- interface : `http://localhost` (ou le port défini par `FRONTEND_PORT`)
- documentation de l'API : `http://localhost/swagger-ui.html`, réacheminée par nginx vers le
  backend dont le profil `docker` active Swagger
- boîte aux lettres Mailpit : `http://localhost:8025`

En dehors de ces chemins, l'API n'est joignable qu'à travers nginx sous `/api`. Le backend
n'expose aucun port sur l'hôte.

La connexion initiale utilise le compte administrateur défini dans le `.env` créé au premier
démarrage du backend.

## Services

- **mysql** (`mysql:8.4`) : base de données. Le port 3306 est exposé sur l'hôte pour inspection
  depuis un client SQL, à retirer sur un serveur réellement exposé.
- **mailpit** : serveur SMTP de développement. Il capture tous les messages émis par le backend
  (vérification d'adresse, réinitialisation de mot de passe) et les présente dans une interface
  web sans qu'aucun ne quitte la machine.
- **backend** : API Spring Boot construite depuis le dépôt backend avec le profil Spring `docker`.
  Elle n'expose aucun port sur l'hôte : seul nginx la joint par le réseau interne.
- **frontend** : fichiers statiques Vue servis par nginx (variante non privilégiée, sans root,
  écoutant sur le port 8080 interne), qui réachemine aussi `/api/` vers le backend. C'est le seul
  point d'entrée de la plateforme.
- **sonarqube** : analyse de qualité dans un profil séparé (voir plus bas).

## Ordre de démarrage et contrôles de santé

Le backend n'est lancé qu'une fois MySQL déclaré sain (`condition: service_healthy`) et le
frontend qu'une fois le backend sain. C'est la différence entre « le conteneur tourne » et « le
service répond » : MySQL accepte des connexions bien avant d'être prêt et Spring Boot met
plusieurs dizaines de secondes à démarrer.

- MySQL : `mysqladmin ping` sans mot de passe. La commande renvoie 0 dès que le serveur est
  vivant et passer le mot de passe l'inscrirait dans la configuration du conteneur, lisible par
  `docker inspect`.
- Backend : appel de `/actuator/health` avec une période de grâce de 90 secondes couvrant le
  démarrage de Spring Boot.
- Frontend : `wget --spider` sur la racine servie par nginx. La commande vient de BusyBox déjà
  présent dans l'image alpine et ne demande que l'en-tête sans télécharger la page.

## Configuration

Toutes les valeurs proviennent du fichier `.env`, jamais du `docker-compose.yml` versionné. Le
fichier `.env.example` documente chaque variable. Les obligatoires sont les mots de passe de la
base, la clé `JWT_SECRET` et le compte administrateur.

Trois points méritent une attention particulière :

- `FRONTEND_PORT`, `CORS_ALLOWED_ORIGINS` et `MAIL_FRONT_BASE_URL` décrivent la même adresse,
  celle que l'utilisateur tape dans son navigateur, jamais un nom de service Docker. Elles se
  modifient ensemble. Rien ne signale l'oubli au démarrage : les e-mails partent simplement avec
  des liens qui ne mènent nulle part.
- `APP_NAME` et `APP_TAGLINE` sont figées dans les fichiers du frontend à la construction de
  l'image : les changer impose un `docker compose up -d --build frontend`.
- Une variable du `.env` n'atteint un conteneur que si elle est listée dans le bloc
  `environment` du service concerné. Compose lit le `.env` pour remplacer les `${...}` de ce
  fichier, il ne transmet rien de lui-même. Ajouter un réglage au `.env.example` sans l'ajouter
  au `docker-compose.yml` donne une variable qui semble configurable et qui ne fait rien.

La messagerie vise Mailpit par défaut mais chaque variable `MAIL_*` est surchargeable depuis le
`.env` : décommenter le bloc Brevo de `.env.example` suffit à basculer sur un envoi réel, sans
toucher au `docker-compose.yml`.

## Données persistantes

Les volumes nommés font survivre les données à la reconstruction des images :

- `mysql_data` : la base de données
- `backend_uploads` : fichiers téléversés (soumissions d'exercices, fichiers joints aux énoncés,
  images, vidéos). Le montage porte sur `/app/uploads` en entier, tout nouveau sous-répertoire de
  stockage est donc couvert sans modifier le `docker-compose.yml`
- `backend_logs` : journaux applicatifs
- `sonarqube_data`, `sonarqube_extensions`, `sonarqube_logs` : projet, jetons et historique
  d'analyse

`docker compose down` les conserve, `docker compose down -v` les supprime définitivement.

## SonarQube

SonarQube vit dans le profil `tools` : il ne démarre pas avec les services applicatifs car il n'a
rien à faire dans un lancement courant et réclame à lui seul environ deux gigaoctets de mémoire.

```bash
docker compose --profile tools up -d
```

L'interface est disponible sur `http://localhost:9000`. L'analyse elle-même se lance depuis les
dépôts backend et frontend selon leurs README respectifs.

## Commandes utiles

```bash
docker compose ps                          # état et santé des services
docker compose logs -f backend             # suivre les journaux d'un service
docker compose up -d --build backend       # reconstruire un seul service
docker compose down                        # arrêter en conservant les données
docker compose down -v                     # arrêter et tout effacer
```

## Limites assumées

Cette orchestration vise la démonstration et l'intégration, pas la production exposée :

- le backend tourne avec le profil Spring `docker` : schéma créé par Hibernate et connexion à la
  base sans TLS, les conteneurs communiquant sur un réseau privé. Un déploiement réellement exposé
  passerait par le profil `prod` et un outil de migration de schéma (voir la feuille de route du
  backend),
- les ports de MySQL et de Mailpit sont ouverts sur l'hôte pour faciliter l'inspection,
- l'interface est servie en HTTP simple, sans terminaison TLS.

## Historique des versions

- v1.0.3 : correctifs d'orchestration. Les réglages optionnels du parcours documentés dans le
  `.env` atteignent enfin le conteneur. Compose lit ce fichier pour remplacer les `${...}` du
  `docker-compose.yml`, il ne transmet rien aux services de lui-même si bien que les décommenter
  restait sans effet (`LEARNING_QUIZ_ABANDON_GRACE_SECONDS`, limites des pièces jointes).
  Ajout du plafond de taille de page (`PAGE_MAX_SIZE`). Contrôle de santé sur le frontend, le
  seul service applicatif qui n'en avait pas. Version de Mailpit épinglée sur sa release mineure
  au lieu de `latest`. Couplage de `FRONTEND_PORT`, `CORS_ALLOWED_ORIGINS` et `MAIL_FRONT_BASE_URL`
  signalé aux deux endroits, faute de quoi un changement de port casse silencieusement les liens des e-mails.
- v1.0.2 : suivi des évolutions applicatives 1.4.0. Répertoire dédié aux fichiers joints aux
  énoncés d'exercices (`EXERCISE_ATTACHMENT_LOCATION`) volontairement séparé des soumissions pour
  qu'une purge de celles-ci n'emporte pas les consignes et documentation des réglages optionnels
  du parcours (délai de grâce des tentatives de quiz, limites des pièces jointes). Aucun volume
  supplémentaire : `backend_uploads` monte `/app/uploads` en entier.
- v1.0.1 : durcissement et documentation. Mot de passe root retiré du contrôle de santé MySQL (il
  était inscrit dans la configuration du conteneur lisible par `docker inspect` et inutile au
  ping), configuration mail entièrement surchargeable depuis le `.env` (Mailpit par défaut, Brevo
  en décommentant un bloc), correspondance de port adaptée au nginx non privilégié du frontend
  (8080 interne), nom et slogan de l'interface transmis au build du frontend (`APP_NAME`,
  `APP_TAGLINE`), `.gitignore` réduit à l'essentiel, rédaction de ce README.
- v1.0.0 : première version. Orchestration complète (MySQL, Mailpit, backend, frontend) avec
  contrôles de santé en cascade, volumes nommés, SonarQube dans un profil dédié et configuration
  entièrement portée par le fichier `.env`.
