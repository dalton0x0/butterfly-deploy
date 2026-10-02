## Objectifs

- Comprendre les problèmes concrets qu'un gestionnaire de versions résout
- Connaître le vocabulaire de base : dépôt, commit, branche, dépôt distant
- Comprendre le modèle distribué de Git et sa façon de stocker l'historique
- Installer, configurer Git et créer son premier dépôt

## Le besoin

Imaginez que vous développez seul un site pour une association. Un soir, vous modifiez le fichier de mise en page pour ajouter un menu. Le lendemain, plus rien ne s'affiche correctement. Qu'avez-vous changé exactement ? Vous ne vous en souvenez plus. Vous n'avez aucune copie de la version qui fonctionnait.

Pour éviter cela, beaucoup finissent par dupliquer leurs fichiers à la main :

```text
projet/
  index.html
  index_v2.html
  index_v2_corrige.html
  index_final.html
  index_final_VRAIMENT_final.html
```

Cette méthode pose rapidement plusieurs problèmes :

- **Impossible de savoir ce qui a changé** entre deux versions sans comparer les fichiers ligne à ligne.
- **Impossible de savoir pourquoi** une modification a été faite, ni par qui.
- **Le dossier grossit** et devient illisible : quelle est la bonne version ?
- **À plusieurs, c'est ingérable.** Deux personnes modifient le même fichier, s'envoient leurs versions par e-mail, et l'une écrase le travail de l'autre sans s'en rendre compte.

Dans une équipe de développement, le problème est multiplié : des dizaines de personnes modifient des centaines de fichiers chaque jour. Il faut un outil qui garde la trace de **tout**, permette de revenir en arrière et de travailler en parallèle sans se gêner. Cet outil, c'est un **gestionnaire de versions**.

## Définitions

> **Gestionnaire de versions (VCS, Version Control System).** Logiciel qui enregistre l'évolution d'un ensemble de fichiers au fil du temps. Il permet de consulter n'importe quelle version passée, de comparer deux versions et de fusionner le travail de plusieurs personnes.

> **Dépôt (repository).** Le projet suivi par Git : vos fichiers et tout leur historique. L'historique est stocké dans un dossier caché nommé `.git` à la racine du projet.

> **Commit.** Un instantané du projet enregistré à un moment précis. Il porte un auteur, une date, un message qui explique la modification et un identifiant unique.

> **Branche.** Une ligne de développement indépendante. Elle permet de travailler sur une fonctionnalité sans toucher à la version stable.

> **Dépôt distant (remote).** Une copie du dépôt hébergée sur un serveur, par exemple sur GitHub, qui sert à partager le travail avec d'autres personnes.

## Ce que Git apporte concrètement

Reprenons le problème du menu cassé. Avec Git, vous auriez enregistré un commit « ajout du menu ». Il suffit alors de trois commandes pour comprendre et réparer :

```bash
git log --oneline          # voir la liste des commits
git diff HEAD~1            # voir exactement ce qui a changé depuis le commit précédent
git restore index.html     # revenir à la dernière version enregistrée du fichier
```

| Besoin | Réponse de Git |
|--------|----------------|
| Savoir ce qui a changé | `git diff` montre les lignes ajoutées et supprimées |
| Savoir qui a changé quoi et pourquoi | Chaque commit porte un auteur, une date et un message |
| Revenir à une version qui fonctionnait | On peut restaurer n'importe quel commit passé |
| Tester une idée sans risque | Une branche isole le travail expérimental |
| Travailler à plusieurs | Git fusionne automatiquement le travail de chacun et signale les conflits |

## Un peu d'histoire

Git a été créé en 2005 par **Linus Torvalds**, le créateur de Linux. L'équipe du noyau Linux, des milliers de contributeurs dans le monde entier, venait de perdre l'accès gratuit à l'outil qu'elle utilisait. Linus a conçu Git en quelques semaines avec trois objectifs : la rapidité, la capacité à gérer des projets énormes et un fonctionnement entièrement **distribué**.

Aujourd'hui, Git est devenu la référence absolue. Presque toutes les entreprises et tous les projets open source l'utilisent.

## Le modèle distribué

Les anciens outils, comme SVN, étaient **centralisés** : l'historique n'existait que sur un serveur. Chaque développeur n'avait que la dernière version des fichiers. Sans connexion au serveur, impossible d'enregistrer son travail ou de consulter l'historique. Si le serveur tombait en panne sans sauvegarde, tout l'historique était perdu.

Git est **distribué** : chaque développeur possède une **copie complète** du dépôt, avec tout son historique.

```text
Modèle centralisé (SVN)               Modèle distribué (Git)

      [ Serveur + historique ]              [ GitHub : dépôt complet ]
       /        |        \                    /          |          \
  [fichiers] [fichiers] [fichiers]    [dépôt complet] [dépôt complet] [dépôt complet]
   Emma       Lucas      Nina           Emma           Lucas           Nina
```

Conséquences concrètes :

- **Presque tout se fait en local** : commit, historique, création de branche. C'est instantané et fonctionne sans réseau, dans le train comme en avion.
- **Chaque copie est une sauvegarde complète.** Si le serveur disparaît, n'importe quel développeur peut le reconstituer.
- **Le serveur sert à partager**, pas à stocker à la place de chacun. On envoie ses commits quand on le décide.

## Git n'est pas GitHub

C'est une confusion fréquente chez les débutants.

| | Git | GitHub, GitLab, Bitbucket |
|---|-----|---------------------------|
| Nature | Un logiciel installé sur votre poste | Des services en ligne |
| Rôle | Gérer l'historique d'un projet | Héberger des dépôts Git et faciliter la collaboration |
| Fonctions | Commits, branches, fusions | Pull requests, relecture de code, tickets, intégration continue |
| Fonctionne sans Internet ? | Oui | Non |

On peut utiliser Git sans jamais toucher à GitHub. En revanche, GitHub n'a aucun sens sans Git.

## Comment Git stocke l'historique

Beaucoup d'outils anciens enregistraient une **liste de différences** : « à la version 2, la ligne 12 a changé ». Pour reconstruire une version, il fallait rejouer toutes les différences depuis le début.

Git fonctionne autrement : chaque commit est un **instantané** complet de l'état du projet. Pour ne pas gaspiller d'espace, un fichier qui n'a pas changé n'est pas recopié : Git pointe simplement vers la version déjà stockée.

```text
Commit 1         Commit 2         Commit 3
index.html v1    index.html v2    index.html v2  (même contenu, pas de copie)
style.css v1     style.css v1     style.css v2
```

Chaque commit est identifié par une **empreinte** (hash SHA-1) de 40 caractères, calculée à partir de son contenu, par exemple `a3f9c21e8b...`. Les 7 premiers caractères suffisent en pratique pour le désigner : `a3f9c21`. Comme l'empreinte dépend du contenu, la moindre modification d'un commit passé changerait son identifiant. L'historique est donc protégé contre les altérations silencieuses.

## Installer et configurer Git

Téléchargez Git sur le site officiel git-scm.com, ou utilisez le gestionnaire de paquets de votre système. Vérifiez ensuite l'installation :

```bash
git --version
```

Avant le premier commit, déclarez votre identité. Elle sera inscrite dans chacun de vos commits, c'est ainsi que l'équipe saura qui a fait quoi.

```bash
git config --global user.name "Emma Petit"
git config --global user.email "emma.petit@exemple.fr"

# Nom de la branche créée par défaut dans un nouveau dépôt
git config --global init.defaultBranch main

# Vérifier la configuration
git config --list
```

L'option `--global` enregistre le réglage pour tous vos projets. Sans elle, il ne s'applique qu'au dépôt courant, ce qui est pratique pour utiliser une adresse professionnelle sur un projet d'entreprise et une adresse personnelle ailleurs.

## Créer ou récupérer un dépôt

Deux situations se présentent.

**Démarrer le suivi d'un projet existant** : `git init` crée le dossier caché `.git`. À partir de ce moment, le dossier devient un dépôt Git.

```bash
mkdir site-association
cd site-association
git init
```

```text
Initialized empty Git repository in /home/emma/site-association/.git/
```

**Récupérer un projet qui existe déjà sur un serveur** : `git clone` télécharge le dépôt complet, historique compris.

```bash
git clone https://github.com/exemple/site-association.git
```

Ne supprimez jamais le dossier `.git` : il contient tout l'historique. Sans lui, votre projet redevient un simple dossier de fichiers.

## Exemple complet

Emma démarre le site de l'association avec Git.

```bash
mkdir site-association && cd site-association
git init
echo "<h1>Association des Jardins</h1>" > index.html
git add index.html
git commit -m "feat: add home page"
```

Deux semaines et plusieurs commits plus tard, la page d'accueil est cassée. Emma consulte l'historique :

```bash
git log --oneline
```

```text
e41b2c7 feat: add navigation menu
9d03a18 style: change title color
5c8f6e2 feat: add home page
```

Elle voit que le menu a été ajouté en dernier. Elle affiche ce commit en détail avec `git show e41b2c7`, repère la balise mal fermée et la corrige. Sans Git, elle aurait dû relire tout le fichier à la recherche de l'erreur.

## Les erreurs fréquentes

- **Oublier de configurer son identité.** Les commits portent alors un nom générique, parfois celui de la machine. L'équipe ne sait plus qui a fait quoi.
- **Lancer `git init` dans le mauvais dossier**, par exemple dans son dossier personnel. Git se met alors à suivre tous vos fichiers. Vérifiez toujours avec `pwd` où vous êtes.
- **Créer un dépôt dans un dépôt.** Un `git init` dans un sous-dossier d'un projet déjà suivi crée un dépôt imbriqué qui provoque des comportements déroutants.
- **Confondre Git et GitHub**, et croire qu'il faut Internet pour enregistrer son travail.

## Retour au besoin

Le dossier rempli de copies `index_final_VRAIMENT_final.html` disparaît. Il reste un seul fichier `index.html`, et Git garde en mémoire chacune de ses versions avec leur date, leur auteur et la raison de la modification. On peut comparer, revenir en arrière et travailler à plusieurs. Les cours suivants montrent comment enregistrer ces versions au quotidien.

## À retenir

- Un gestionnaire de versions garde l'historique complet : quoi, qui, quand et pourquoi.
- Git est distribué : chacun possède tout l'historique en local, le serveur sert à partager.
- Un commit est un instantané identifié par une empreinte unique.
- Git est l'outil, GitHub est un service d'hébergement.
- `git init` crée un dépôt, `git clone` en récupère un existant.

## Pour aller plus loin

- Le livre officiel Pro Git, traduit en français : [git-scm.com/book/fr/v2](https://git-scm.com/book/fr/v2), chapitre 1 « Démarrage rapide ».
