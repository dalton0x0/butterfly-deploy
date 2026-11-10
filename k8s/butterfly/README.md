# Butterfly sur Kubernetes

Manifestes de l'application, organisés avec Kustomize : une base commune et un dossier par
environnement, qui la reprend et la complète.

```text
butterfly/
  base/                 Commun à tous les environnements
    mysql.yaml          Base de données (StatefulSet, volume de 5 Go)
    redis.yaml          Cache, sans persistance
    backend.yaml        API Spring Boot et volume des fichiers téléversés (10 Go)
    frontend.yaml       nginx : interface Vue et réacheminement de /api
    middlewares.yaml    Traefik : redirection HTTPS et en-tête HSTS
    network-policies.yaml
    backend.env         Configuration non sensible du backend
  staging/              https://staging.butterfly.cheridanh.fr
    ingress.yaml        Domaine et certificat
    mailpit.yaml        Capture des e-mails
    backend.env         Adresses publiques et messagerie
    secrets/            Secrets chiffrés (SealedSecrets)
  seal-secrets.sh       Production des secrets chiffrés
```

Pour voir le résultat final d'un environnement, tel qu'Argo CD l'applique :

```bash
kubectl kustomize k8s/butterfly/staging
```

## Principes

- **Même image partout.** Les images publiées par la CI sont celles de Docker Compose. Seule
  la configuration change, par variables d'environnement.
- **Version fixée par le dépôt.** Chaque environnement désigne ses images par l'étiquette
  `sha-<commit>`, immuable. Déployer une version revient à modifier cette étiquette dans le
  `kustomization.yaml` de l'environnement.
- **Moindre privilège.** Aucun conteneur ne tourne en root, aucun ne peut élever ses
  privilèges, et le réseau n'autorise que les flux nécessaires : Traefik vers l'interface,
  l'interface vers le backend, le backend vers MySQL, Redis et Mailpit.
- **Données protégées.** Les volumes ne sont jamais supprimés par Argo CD.

### Profil Spring `docker` et non `prod`

Le backend tourne avec le profil `docker`, celui de Docker Compose. Le profil `prod` est fait
pour une installation classique sur un serveur, et convient mal à un conteneur :

- il écrit ses journaux dans un fichier, dans le conteneur. Sous Kubernetes, seule la sortie
  standard est collectée (`kubectl logs`) : le fichier serait une copie que personne ne lit,
  perdue à chaque redémarrage ;
- il exige TLS vers la base de données. Ici, MySQL et le backend communiquent dans le cluster,
  sur un réseau privé que les NetworkPolicies réservent au backend.

Le profil `docker` applique en revanche les migrations Flyway au démarrage et journalise sur
la sortie standard. Ce qui doit différer en production (Swagger désactivé) se règle par
variable d'environnement, dans le dossier de l'environnement.

## Mettre en service un environnement

Exemple du staging. Les commandes se lancent depuis la racine du dépôt, sur le poste.

### 1. Prérequis

- Un enregistrement DNS `A` de `staging.butterfly.cheridanh.fr` vers l'adresse du serveur.
  cert-manager ne peut pas obtenir de certificat avant sa propagation
  (`dig +short staging.butterfly.cheridanh.fr`).
- `kubeseal` (`brew install kubeseal`) et le certificat `k8s/sealed-secrets-cert.pem`
  (voir `k8s/README.md`).
- Un fichier de comptes pour Swagger, hors du dépôt :

  ```bash
  htpasswd -nB <utilisateur> > ~/swagger.htpasswd
  ```

- Un jeton GitHub pour lire les images privées : GitHub, Settings, Developer settings,
  Personal access tokens, **Tokens (classic)**, avec le seul droit `read:packages`. GHCR n'accepte
  que les jetons classiques, pas ceux à granularité fine.

### 2. Chiffrer les secrets

```bash
k8s/butterfly/seal-secrets.sh staging
```

Le script demande chaque valeur, sans l'afficher, et écrit les fichiers chiffrés dans
`k8s/butterfly/staging/secrets/`. Générer les mots de passe et la clé JWT avec
`openssl rand -base64 48`, et les ranger dans le gestionnaire de mots de passe avant de les
saisir : un secret chiffré ne se relit pas.

| Secret              | Contenu                                                     |
|---------------------|-------------------------------------------------------------|
| `mysql-credentials` | Utilisateur et mot de passe de l'application, mot de passe root |
| `backend-secrets`   | Clé JWT, e-mail et mot de passe de l'administrateur         |
| `swagger-htpasswd`  | Comptes autorisés à consulter Swagger                       |
| `ghcr-pull`         | Jeton de lecture des images                                 |

Chaque secret chiffré n'est valable que dans son namespace : ceux du staging ne servent pas
en production, et inversement.

### 3. Choisir la version

Dans `k8s/butterfly/staging/kustomization.yaml`, remplacer les deux `newTag` par les
étiquettes `sha-...` des images à déployer. Elles sont visibles sur GitHub, dans la page
Packages de chaque dépôt.

### 4. Activer

Commiter les secrets chiffrés, la version et le fichier `k8s/apps/butterfly-staging.yaml`,
puis pousser sur `main`. Argo CD crée le namespace et déploie l'ensemble.

### 5. Vérifier

Sur le serveur :

```bash
kubectl -n butterfly-staging get pods           # tous Running et prêts (1/1)
kubectl -n butterfly-staging get sealedsecrets  # SYNCED à True
kubectl -n butterfly-staging get certificate    # READY à True, en une à deux minutes
```

Depuis le poste :

```bash
curl -sI http://staging.butterfly.cheridanh.fr   # redirection permanente vers https://
curl -sI https://staging.butterfly.cheridanh.fr  # 200 et strict-transport-security
```

Le premier démarrage est le plus long : MySQL initialise la base, puis le backend applique
toutes les migrations Flyway. Compter quelques minutes.

## Exploitation

### Déployer une nouvelle version

Modifier les étiquettes `newTag` de l'environnement, commiter et pousser. Argo CD remplace les
pods. Le backend s'arrête avant que le nouveau ne démarre (stratégie `Recreate`) : l'API est
indisponible pendant environ une minute.

### Modifier un secret

```bash
k8s/butterfly/seal-secrets.sh staging backend-secrets
```

puis commiter et pousser. Le contrôleur met à jour le Secret, mais les pods gardent les
anciennes valeurs, lues à leur démarrage. Les redémarrer, sur le serveur :

```bash
kubectl -n butterfly-staging rollout restart deployment backend
```

Exception : MySQL ne lit `mysql-credentials` qu'à l'initialisation d'une base vierge. Pour
changer un mot de passe existant, le modifier d'abord dans MySQL (`ALTER USER`), puis
dans le secret.

### Consulter les e-mails du staging (Mailpit)

L'interface n'est pas exposée. Elle s'ouvre par un tunnel SSH, comme Argo CD :

```bash
ssh -t -L 8025:127.0.0.1:8025 <utilisateur>@<serveur> \
  kubectl --kubeconfig .kube/config port-forward -n butterfly-staging svc/mailpit 8025:8025
```

puis http://localhost:8025.

### Journaux

```bash
kubectl -n butterfly-staging logs deployment/backend -f
kubectl -n butterfly-staging logs deployment/backend --previous   # avant le dernier redémarrage
```

### Données

Les volumes (base de données, fichiers téléversés) sont des dossiers du serveur, créés par
le provisionneur `local-path` de k3s. Ils survivent aux redémarrages et aux mises à jour,
mais pas à la perte du serveur : leur sauvegarde hors du serveur reste à mettre en place.
