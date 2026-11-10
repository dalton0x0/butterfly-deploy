# Déploiement Kubernetes (k3s et Argo CD)

Ce dossier décrit tout ce qui tourne sur le cluster. Argo CD le surveille et applique chaque
changement poussé sur `main` : le dépôt est la source de vérité, et une modification faite à la
main sur le cluster est annulée à la synchronisation suivante.

Docker Compose, à la racine du dépôt, reste l'outil du développement local.

## Organisation

```text
k8s/
  apps/                         Applications Argo CD, une par composant (« app of apps »)
  infrastructure/
    cert-issuers/               Émetteurs Let's Encrypt (test et production)
    traefik/                    Réglages du Traefik fourni par k3s (IP réelle des clients)
  sealed-secrets-cert.pem       Certificat public de Sealed Secrets pour chiffrer hors ligne
```

Le dossier s'enrichira de Butterfly, avec une base commune et une variante par environnement
(staging, prod).

## Démarrage d'un cluster

Trois étapes manuelles, une seule fois par serveur, depuis le dossier `server/` :

1. `harden.sh` : durcissement du système (utilisateur dédié, SSH par clé, pare-feu, fail2ban).
2. `k3s-config.yaml` puis l'installeur officiel de k3s, en version épinglée :

   ```bash
   sudo install -D -m 644 k3s-config.yaml /etc/rancher/k3s/config.yaml
   curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.36.6+k3s1 sh -
   ```

   La version de Kubernetes suit celle des outils installés dessus et non la dernière
   publiée : cert-manager 1.21 n'est supporté que jusqu'à Kubernetes 1.36. Avant toute
   montée de version de k3s, vérifier la matrice de compatibilité de cert-manager et
   d'Argo CD.
3. `install-argocd.sh` : Argo CD, accès au dépôt et application racine.

Argo CD crée ensuite tout le reste à partir de `k8s/apps`.

## Accès à Argo CD

L'interface n'est pas exposée sur Internet. Elle s'ouvre depuis le poste local à travers un
tunnel SSH :

```bash
ssh -t -L 8443:127.0.0.1:8080 <utilisateur>@<serveur> \
  kubectl --kubeconfig .kube/config port-forward -n argocd svc/argocd-server 8080:443
```

puis https://localhost:8443. Le certificat est autosigné : l'avertissement du navigateur est
attendu, le tunnel SSH assurant déjà le chiffrement.

L'option `-t` attache un terminal à la commande distante : quand la connexion SSH se coupe,
`kubectl port-forward` reçoit le signal et s'arrête. Sans elle, il continue de tourner sur le
serveur et occupe le port 8080, ce qui fait échouer le tunnel suivant (`address already in use`).
Pour retrouver et arrêter un tel processus, sur le serveur :

```bash
sudo ss -ltnp 'sport = :8080'   # affiche le pid du processus qui occupe le port
kill <pid>
```

`pgrep port-forward` ne le trouve pas : le kubectl de k3s est le binaire k3s lancé sous un autre
nom et la ligne de commande visible ne contient pas `port-forward`.

Dans le navigateur, l'adresse est celle du port local du tunnel : https://localhost:8443. Le port
8080 affiché par `kubectl port-forward` est celui du serveur.

Le port local 8443 évite un conflit fréquent : 8080 est souvent déjà pris sur le poste (pile
Docker Compose locale, serveur de développement). Dans ce cas, `ssh` n'ouvre pas le tunnel et le
navigateur joint le service local en HTTP, d'où l'erreur `SSL_ERROR_RX_RECORD_TOO_LONG`.

## Secrets (Sealed Secrets)

Un secret ne va jamais en clair dans le dépôt. Il est chiffré sur le poste avec `kubeseal` et le
certificat public du contrôleur. Seul le contrôleur, dans le cluster, détient la clé privée qui le
déchiffre : le fichier chiffré se commite sans risque.

### Chiffrer un secret

Le certificat public est versionné (`k8s/sealed-secrets-cert.pem`) : le chiffrement se fait hors
ligne sans accès au cluster.

```bash
brew install kubeseal

kubectl create secret generic <nom> -n <namespace> \
  --from-literal=CLE=valeur --dry-run=client -o yaml \
  | kubeseal --cert k8s/sealed-secrets-cert.pem --format yaml > <fichier>.sealed.yaml
```

Le secret chiffré est lié à son nom et à son namespace : il ne se déchiffre pas ailleurs. Garder les
valeurs en clair dans un gestionnaire de mots de passe, jamais dans un fichier du dépôt.

### Récupérer le certificat public

Après l'installation du contrôleur ou après un renouvellement de clé sur le serveur :

```bash
kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o jsonpath='{.items[0].data.tls\.crt}' | base64 -d
```

Le résultat se copie dans `k8s/sealed-secrets-cert.pem`. Il est public : il ne permet que de chiffrer.

### Sauvegarder la clé privée

Indispensable : si le cluster est perdu, sa clé privée disparaît avec lui et plus aucun secret du
dépôt ne peut être déchiffré. Une fois après l'installation, puis après chaque renouvellement :

```bash
kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml \
  > sealed-secrets-key.yaml
```

Ranger ce fichier dans un gestionnaire de mots de passe ou sur un support chiffré, **jamais dans
Git**, puis le supprimer du serveur (`shred -u sealed-secrets-key.yaml`).

Le renouvellement automatique de la clé (tous les 30 jours par défaut) est désactivé : chaque
nouvelle clé devrait sinon être sauvegardée à son tour.

### Restaurer la clé sur un nouveau cluster

Après l'installation d'Argo CD, avant la synchronisation des applications qui contiennent des
secrets :

```bash
kubectl apply -f sealed-secrets-key.yaml
kubectl -n kube-system delete pod -l app.kubernetes.io/name=sealed-secrets
```

Le contrôleur redémarre avec l'ancienne clé, et tous les secrets du dépôt redeviennent lisibles.
