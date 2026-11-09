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
ssh -L 8443:127.0.0.1:8080 <utilisateur>@<serveur> \
  kubectl --kubeconfig .kube/config port-forward -n argocd svc/argocd-server 8080:443
```

puis https://localhost:8443. Le certificat est autosigné : l'avertissement du navigateur est
attendu, le tunnel SSH assurant déjà le chiffrement.

Le port local 8443 évite un conflit fréquent : 8080 est souvent déjà pris sur le poste (pile
Docker Compose locale, serveur de développement). Dans ce cas, `ssh` n'ouvre pas le tunnel et le
navigateur joint le service local en HTTP, d'où l'erreur `SSL_ERROR_RX_RECORD_TOO_LONG`.
