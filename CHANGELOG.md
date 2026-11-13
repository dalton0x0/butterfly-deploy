# Historique des versions - Butterfly Deploy

Toutes les versions notables du dépôt de déploiement Butterfly, de la plus récente à la plus ancienne.

Le projet suit le versionnage sémantique. Une version majeure marque une rupture de
compatibilité, une mineure ajoute des capacités, un correctif répare sans rien ajouter.

Chaque version correspond à un tag Git annoté du même nom. Le titre de chaque section
renvoie vers la comparaison GitHub avec la version précédente, c'est-à-dire l'ensemble des
commits qu'elle apporte. La toute première version renvoie vers son tag n'ayant pas de prédécesseur.

---

## [v1.10.0](https://github.com/dalton0x0/butterfly-deploy/compare/v1.9.0...v1.10.0) - 2026-11-13

Accompagne le backend v3.5.0 et le frontend v3.5.0. Troisième environnement Kubernetes : la
démonstration (`demo.butterfly.cheridanh.fr`, namespace `butterfly-demo`), une instance à montrer
puis à remettre à zéro. Elle déploie la même version que la production, mise à jour par la même
pull request. Elle n'a pas de sauvegarde : deux patchs Kustomize retirent la tâche et l'accès
réseau qu'elle ouvre vers MySQL. Ses e-mails partent par Brevo pour que les personnes invitées
reçoivent leur lien d'activation et la mémoire réservée au backend baisse à 512 Mi, sa limite
restant à 1 Gi. `seal-secrets.sh` accepte l'environnement `demo` et ne lui demande pas les
secrets de sauvegarde.

`scripts/reset-demo-k8s.sh`, lancé sur le serveur, vide la base, les fichiers téléversés et le
cache puis redémarre le backend : Flyway recrée le schéma et l'administrateur de la démo est
recréé. Les volumes sont vidés et non supprimés pour ne pas lutter contre Argo CD qui relance
aussitôt les pods arrêtés. Le namespace est écrit en dur : le script ne peut pas viser le staging
ni la production. Le chargement des contenus prend un mode `DEMO_SKIP_ACCOUNTS=true` : les blocs
seuls, sans comptes ni assignations, chargés par l'API publique depuis le poste.

L'en-tête de Swagger (`OPEN_API_*`) restait vide sous Docker Compose et sous Kubernetes : ces
variables n'étaient transmises au conteneur ni par `docker-compose.yml` ni par `backend.env`. Elles
le sont désormais sans guillemets dans `backend.env` où Kustomize les garderait dans la valeur.
Le `.gitignore` couvre aussi `.env.*` dont `demo/.env.demo` qui porte le mot de passe de
l'administrateur de la démo.

---

## [v1.9.0](https://github.com/dalton0x0/butterfly-deploy/compare/v1.8.0...v1.9.0) - 2026-11-12

Accompagne le backend v3.4.0 et le frontend v3.4.0, premières versions publiées sous forme
d'images dans GHCR. Butterfly est désormais hébergé sur Kubernetes : un cluster k3s sur un seul
serveur, piloté par Argo CD à partir du dossier `k8s/` de ce dépôt. Docker Compose reste l'outil du
développement local.

Le dossier `server/` prépare le serveur : durcissement du système (`harden.sh`), configuration de
k3s avec chiffrement des Secrets, installation d'Argo CD et de son accès au dépôt
(`install-argocd.sh`). Argo CD installe tout le reste : cert-manager et ses émetteurs Let's
Encrypt, le contrôleur Sealed Secrets et un réglage de Traefik qui conserve l'adresse réelle des
clients.

`k8s/butterfly/` décrit l'application avec Kustomize : une base commune et un dossier par
environnement. La base fait tourner chaque conteneur sans root ni élévation de privilèges et
n'autorise que les flux réseau nécessaires. Le staging (`staging.butterfly.cheridanh.fr`) capture
les e-mails dans Mailpit et se met à jour seul après chaque poussée sur `main` du backend ou du
frontend. La production (`butterfly.cheridanh.fr`) envoie par Brevo, désactive Swagger et change
de version par la fusion d'une pull request que la CI prépare à chaque tag. Les secrets sont
chiffrés sur le poste par `seal-secrets.sh` et versionnés sans risque.

Chaque nuit, la base et les fichiers téléversés de chaque environnement sont sauvegardés hors du
serveur avec restic, chiffrés dans un stockage objet S3. La restauration a été éprouvée sur le
staging et sa procédure corrigée en conséquence. Healthchecks.io est prévenu de chaque
sauvegarde et reçoit chaque jour l'état du serveur (`server/healthcheck.sh` : k3s, redémarrage en
attente, espace disque). Sur ce serveur, la pré-production Docker Compose est remplacée par
Kubernetes. Elle reste documentée pour un serveur sans Kubernetes.

---

## [v1.8.0](https://github.com/dalton0x0/butterfly-deploy/compare/v1.7.0...v1.8.0) - 2026-11-09

Accompagne le backend v3.3.0 et le frontend v3.3.0 : rôle gestionnaire, blocs informatifs et
inscription publique activable. La démonstration crée une gestionnaire qui voit déjà tous les blocs
et ne reçoit donc aucune assignation et le bloc informatif « Livret d'accueil ». Un bloc déclaré
`"informational": true` n'a ni quiz ni prérequis et n'est assigné à personne.

L'inscription publique est fermée par défaut après la migration du backend. `PREPROD.md` rappelle de
l'ouvrir depuis le tableau de bord avant de tester l'envoi des e-mails. Les textes ne supposent plus
que l'organisme est une école. Le chargement de la démonstration sur le serveur utilise
l'image `node:24-alpine` comme le frontend.

---

## [v1.7.0](https://github.com/dalton0x0/butterfly-deploy/compare/v1.6.0...v1.7.0) - 2026-11-08

Accompagne le backend v3.2.0 et le frontend v3.2.0 qui élargissent les formats de fichier acceptés.
`scripts/reset-demo.sh` remet la pile locale à zéro (base, fichiers téléversés, Redis, cache nginx)
puis recharge la démonstration. Il refuse de tourner quand le `.env` désigne un vrai relais SMTP,
signe d'une pré-production.

La mise à jour de la pré-production se fait par tag sur une combinaison du tableau des versions
compatibles et `PREPROD.md` décrit le retour arrière : tags précédents puis restauration de la
sauvegarde quand une migration Flyway est passée. Le tableau manquait la ligne 1.6.0, ajoutée.

Caddy retire l'en-tête `Server`. `.env.example` ne propose plus de générer `JWT_SECRET` sur un site
en ligne : un secret produit par un tiers peut être connu de lui. Dependabot surveille les actions
GitHub de la CI.

---

## [v1.6.0](https://github.com/dalton0x0/butterfly-deploy/compare/v1.5.0...v1.6.0) - 2026-10-26

Accompagne le backend v3.1.0 et le frontend v3.1.0 où un compte créé par l'administrateur reçoit
une invitation au lieu d'un mot de passe. Le script de démonstration active désormais ses comptes
en lisant l'invitation dans Mailpit, ce qui évite qu'ils restent sans mot de passe. La validité du
lien d'invitation se règle avec `TOKEN_ACCOUNT_ACTIVATION_TTL`, transmise au backend par le
compose. Le guide de pré-production couvre Debian 13 et 12 en plus d'Ubuntu : installation de
`sudo`, `ufw` et `git`, fail2ban branché sur journald et dépôt Docker choisi selon la distribution.

SonarQube démarre de nouveau : le tag `25-community` n'existe pas sur Docker Hub, l'image est
épinglée sur un numéro complet (`25.11.0.114957-community`) et `.env.example` indique comment lister
les plus récents. Le README explique le premier accès et comment repartir d'un volume vide quand le
mot de passe administrateur d'une installation précédente est perdu.

---

## [v1.5.0](https://github.com/dalton0x0/butterfly-deploy/compare/v1.4.0...v1.5.0) - 2026-10-21

Pré-production. `docker-compose.preprod.yml` ajoute Caddy qui obtient et renouvelle le certificat
Let's Encrypt et devient le seul accès public et passe le backend sur le profil `prod` pour que la
pré-production teste la configuration de production : connexion chiffrée à MySQL, Swagger coupé,
journaux limités à la sortie standard. `PREPROD.md` décrit l'installation pas à pas du choix du
serveur aux mises à jour en passant par le DNS, le pare-feu, Brevo et la restauration.
`scripts/backup.sh` sauvegarde la base et les fichiers téléversés avec une rotation sur sept jours
et n'écrit jamais d'archive tronquée. La CI valide aussi le fichier de pré-production.

Un service Redis sans persistance et à mémoire bornée sert de cache au backend (`CACHE_TYPE`). Les
variables des notifications, le slogan des e-mails repris de `APP_TAGLINE` et le plafond des
tentatives de connexion par adresse IP (`RATE_LIMIT_IP_CAPACITY`) atteignent maintenant le backend.
Le script de démonstration appelle l'API `v1`. `loadtest/browse.js` simule avec k6 des apprenants
et un formateur qui parcourent les contenus et cherchent avec des seuils d'acceptation sur le
temps de réponse et le taux d'erreur.

---

## [v1.4.0](https://github.com/dalton0x0/butterfly-deploy/compare/v1.3.2...v1.4.0) - 2026-10-01

Contenus de démonstration. Le dossier `demo` charge par l'API six blocs complets (Git, SQL, Java,
PHP, Spring Boot et Laravel), soit 17 modules, 46 cours, 22 exercices notés et 17 quiz, ainsi qu'un
formateur et deux apprenants assignés à ces blocs. Le chargement passe par l'API et non par la base :
chaque contenu subit les validations d'une saisie dans l'interface et les options de quiz sont
mélangées à l'insertion comme le fait le backend. Aucune migration Flyway n'est concernée, rien ne
peut donc atteindre une base de production par accident. Les adresses des comptes sont confirmées
par le vrai parcours, le jeton étant lu dans Mailpit puis présenté à l'API. Le script peut être
relancé : un compte ou un bloc existant est conservé tel quel et tous les fichiers sont lus avant le
premier appel pour qu'un JSON invalide n'interrompe pas un bloc à moitié créé. `node --env-file`
coupant une valeur sans guillemets au premier `#` là où Docker Compose la garde entière, un mot de
passe administrateur qui en contient un doit être placé entre guillemets dans le `.env`, ce que le
script rappelle en cas de connexion refusée. Le README complète la table des versions compatibles
qui s'arrêtait à la v1.3.0 et décrit enfin l'ordre de démarrage réel : le frontend n'attend plus la
bonne santé du backend depuis la v1.2.0.

---

## [v1.3.2](https://github.com/dalton0x0/butterfly-deploy/compare/v1.3.1...v1.3.2) - 2026-09-25

Les ports de Mailpit et de SonarQube ne sont plus publiés que sur l'interface locale de l'hôte.
L'interface web de Mailpit affiche chaque message capturé, liens de réinitialisation de mot de passe
compris : lancée sur une machine joignable, la pile permettait à n'importe qui de prendre la main sur
un compte, administrateur compris. SonarQube démarre pour sa part avec le compte `admin/admin`. La
variable `LEARNING_QUIZ_ABANDON_GRACE_SECONDS` est retirée, le délai de grâce ayant disparu du
backend en v2.0.0 : la conserver laissait croire à un réglage qui n'agit plus. Les limites du README
décrivent enfin le schéma produit par Flyway et la base non publiée.

---

## [v1.3.1](https://github.com/dalton0x0/butterfly-deploy/compare/v1.3.0...v1.3.1) - 2026-09-23

Le port de la base n'est plus publié sur l'hôte par défaut. Il l'était accompagné d'un commentaire
demandant de le retirer en production, ce qui revenait à livrer un défaut ouvert en comptant sur
la vigilance de celui qui déploie. Le backend joint la base par le réseau interne de Compose,
personne d'autre n'en a besoin : la publication reste disponible en décommentant deux lignes pour
inspecter la base depuis un client SQL. La variable `LOG_FILE_PATH` est retirée, le profil `docker`
n'activant pas la journalisation en fichier : elle laissait croire que les journaux étaient
conservés alors qu'aucun volume ne couvrait ce chemin.

---

## [v1.3.0](https://github.com/dalton0x0/butterfly-deploy/compare/v1.2.0...v1.3.0) - 2026-09-14

Fuseau horaire et journalisation. Le conteneur backend tournait en UTC alors que ses
horodatages partent en JSON sans fuseau : le navigateur les interprétait comme de l'heure locale
et un compte créé peu après minuit à Paris s'affichait daté de la veille. La variable `TZ` aligne
le conteneur sur le fuseau des utilisateurs, ce qui supprime l'écart sans toucher au code et
passe les journaux applicatifs à l'heure locale. Les lignes déjà écrites gardent leur valeur en
UTC, une base de développement mérite donc d'être recréée. Le volume `backend_logs` disparaît :
dans un conteneur, la sortie standard est déjà collectée par Docker et le fichier n'en était
qu'une seconde copie que personne ne lisait dans un volume à sauvegarder. Contrepartie
désormais écrite dans le README, un `docker compose down` emporte ces journaux là où les volumes
survivent. Les versions compatibles des trois dépôts sont documentées, rien ne vérifiant leur
accord au démarrage : un fichier compose récent associé à un backend plus ancien lui fournit des
variables qu'il ignore en silence.

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
