# Déploiement Kubernetes (k3s et Argo CD)

Ce dossier décrit tout ce qui tourne sur le cluster. Argo CD le surveille et applique chaque
changement poussé sur `main` : le dépôt est la source de vérité, et une modification faite à la
main sur le cluster est annulée à la synchronisation suivante.

Docker Compose, à la racine du dépôt, reste l'outil du développement local.

## Organisation

```text
k8s/
  apps/   Applications Argo CD, une par composant (modèle « app of apps »)
```

Le dossier s'enrichira au fil des étapes : cert-manager, puis Butterfly avec une base commune et
une variante par environnement (staging, prod).

## Démarrage d'un cluster

Trois étapes manuelles, une seule fois par serveur, depuis le dossier `server/` :

1. `harden.sh` : durcissement du système (utilisateur dédié, SSH par clé, pare-feu, fail2ban).
2. `k3s-config.yaml` puis l'installeur officiel de k3s.
3. `install-argocd.sh` : Argo CD, accès au dépôt et application racine.

Argo CD crée ensuite tout le reste à partir de `k8s/apps`.

## Accès à Argo CD

L'interface n'est pas exposée sur Internet. Elle s'ouvre depuis le poste local à travers un
tunnel SSH :

```bash
ssh -L 8080:127.0.0.1:8080 <utilisateur>@<serveur> \
  kubectl --kubeconfig .kube/config port-forward -n argocd svc/argocd-server 8080:443
```

puis https://localhost:8080. Le certificat est autosigné : l'avertissement du navigateur est
attendu, le tunnel SSH assurant déjà le chiffrement.
