## Objectifs

- Comprendre les trois zones de Git et le rôle de l'index
- Connaître les états d'un fichier suivi par Git
- Enregistrer des modifications avec `add` et `commit`
- Consulter l'état du dépôt, les différences et l'historique
- Écrire un bon commit et exclure les fichiers qui n'ont rien à faire dans le dépôt

## Le besoin

Lucas travaille depuis le matin sur le site de l'association. Il a corrigé une faute sur la page d'accueil, ajouté un formulaire de contact et, pour déboguer, glissé quelques `console.log` dans un fichier JavaScript. Il a aussi un fichier `.env` qui contient la clé d'un service d'envoi d'e-mails.

Il veut maintenant enregistrer son travail. Mais il ne veut pas tout enregistrer d'un bloc :

- la correction de la faute et le formulaire sont **deux sujets différents** : s'il faut un jour annuler le formulaire, il ne veut pas perdre la correction ;
- les `console.log` de débogage ne doivent pas être enregistrés ;
- le fichier `.env` contient un secret : il ne doit **jamais** entrer dans l'historique.

Il lui faut donc un moyen de **choisir précisément** ce qui entre dans chaque enregistrement. C'est exactement le rôle de l'index de Git.

## Définitions

> **Répertoire de travail (working directory).** Les fichiers de votre projet tels que vous les voyez et les modifiez dans votre éditeur.

> **Index (staging area).** Une zone de préparation. On y place les modifications que l'on veut inclure dans le prochain commit, et seulement celles-là.

> **Dépôt local.** L'historique des commits, stocké dans le dossier `.git`.

> **HEAD.** Un pointeur vers le commit sur lequel vous travaillez actuellement, en général le dernier commit de la branche courante.

## Les trois zones

Chaque modification traverse trois zones, de gauche à droite :

```text
 Répertoire de travail        Index               Dépôt local
 (vos fichiers)               (préparation)       (historique)

   modifier  ─────git add────►  préparer  ────git commit────►  enregistrer
```

Une bonne image est celle d'un photographe. Le répertoire de travail, c'est la scène avec tout le monde. L'index, c'est le choix des personnes que l'on place devant l'objectif. Le commit, c'est la photo : elle fige uniquement ce qui a été choisi.

## Les états d'un fichier

Du point de vue de Git, un fichier se trouve toujours dans l'un de ces états :

| État | Signification |
|------|---------------|
| Non suivi (untracked) | Git voit le fichier mais ne l'a jamais enregistré |
| Non modifié (unmodified) | Identique à la dernière version enregistrée |
| Modifié (modified) | Changé depuis le dernier commit, mais pas encore dans l'index |
| Indexé (staged) | La modification est prête à partir dans le prochain commit |

## Le cycle du quotidien

### Voir où l'on en est : git status

`git status` est la commande à lancer sans modération. Elle indique la branche courante et l'état de chaque fichier.

```bash
git status
```

```text
On branch main
Changes not staged for commit:
        modified:   index.html
        modified:   js/app.js

Untracked files:
        contact.html
        .env
```

Git nous dit ici que deux fichiers suivis ont été modifiés et que deux nouveaux fichiers ne sont pas encore suivis.

### Préparer : git add

```bash
git add index.html            # un fichier précis
git add src/                  # tout un dossier
git add -p js/app.js          # choisir morceau par morceau dans un fichier
```

L'option `-p` (patch) est précieuse : Git présente chaque bloc de modifications et demande s'il faut l'inclure. Lucas peut ainsi garder ses corrections utiles de `app.js` et laisser ses `console.log` hors de l'index.

### Enregistrer : git commit

```bash
git commit -m "fix: correct typo on home page"
```

Le message suit l'option `-m`. Sans elle, Git ouvre un éditeur de texte pour saisir un message plus long, avec une ligne de titre et un corps.

## Voir les différences

Avant d'enregistrer, on vérifie ce qui va partir.

```bash
git diff              # modifications pas encore indexées
git diff --staged     # modifications indexées, prêtes pour le commit
```

```diff
-<h1>Bienvenu sur le site</h1>
+<h1>Bienvenue sur le site</h1>
```

Les lignes précédées de `-` sont supprimées, celles précédées de `+` sont ajoutées. Relire son diff avant chaque commit est une excellente habitude : c'est à ce moment que l'on repère un affichage de débogage oublié ou une modification sans rapport avec le sujet du commit.

## Consulter l'historique

```bash
git log                           # historique complet, du plus récent au plus ancien
git log --oneline                 # une ligne par commit
git log --oneline --graph --all   # vue graphique de toutes les branches
git log -p index.html             # historique détaillé d'un seul fichier
git show a3f9c21                  # détail d'un commit : auteur, date, message et diff
```

```text
e41b2c7 feat: add contact form
9d03a18 fix: correct typo on home page
5c8f6e2 feat: add home page
```

## Un bon commit

Un commit doit être **atomique** : une seule modification logique, complète et cohérente. Il doit pouvoir être compris, relu et annulé seul.

| Mauvaise pratique | Pourquoi c'est gênant | Bonne pratique |
|-------------------|------------------------|----------------|
| Un commit par jour avec tout le travail | Impossible d'annuler une partie sans le reste | Un commit par sujet |
| Un commit qui mélange correction et nouvelle fonctionnalité | La relecture devient confuse | Deux commits séparés |
| Un commit qui ne compile pas | Casse le projet pour les collègues | Chaque commit laisse le projet fonctionnel |

Le message explique **pourquoi** la modification a été faite. Le « quoi » se lit déjà dans le diff.

```text
Mauvais : "modifs"
Mauvais : "correction"
Moyen   : "change index.html"
Bon     : "fix(home): correct typo in page title"
```

## Ignorer des fichiers : .gitignore

Certains fichiers ne doivent jamais être versionnés :

- les **dépendances téléchargées** (`node_modules/`, `vendor/`) : on les réinstalle à partir d'un fichier de description ;
- les **fichiers générés** (`target/`, `dist/`) : on les reconstruit à partir du code source ;
- la **configuration locale et les secrets** (`.env`) ;
- les fichiers propres à votre éditeur ou à votre système (`.idea/`, `.DS_Store`).

On les liste dans un fichier `.gitignore` à la racine du projet :

```text
# Dépendances et compilation
node_modules/
target/
vendor/

# Configuration locale et secrets
.env
*.log

# Fichiers d'éditeur et de système
.idea/
.vscode/
.DS_Store
```

| Motif | Signification |
|-------|---------------|
| `.env` | Le fichier `.env`, où qu'il soit |
| `*.log` | Tous les fichiers qui finissent par `.log` |
| `target/` | Le dossier `target` et tout son contenu |
| `!important.log` | Exception : ce fichier reste suivi malgré `*.log` |

Deux pièges à connaître :

- Un fichier **déjà commité** n'est pas retiré par le `.gitignore`. Il faut d'abord le sortir du suivi avec `git rm --cached fichier`, puis commiter.
- Un **secret** commité, même supprimé ensuite, reste lisible dans l'historique. S'il a été poussé sur un dépôt distant, considérez-le comme compromis et changez-le immédiatement.

## Exemple complet

Revenons à Lucas et à ses modifications du matin.

```bash
# 1. Protéger le secret avant toute chose
echo ".env" >> .gitignore
git add .gitignore
git commit -m "chore: ignore local environment file"

# 2. Commit de la correction seule
git add index.html
git diff --staged                  # vérification
git commit -m "fix(home): correct typo in page title"

# 3. Commit du formulaire, sans les console.log
git add contact.html
git add -p js/app.js               # on accepte les blocs utiles, on refuse les console.log
git diff --staged
git commit -m "feat(contact): add contact form"

# 4. Vérification finale
git status
git log --oneline
```

```text
b7a1f0e feat(contact): add contact form
3c9d4e2 fix(home): correct typo in page title
8e2f1a7 chore: ignore local environment file
```

Le secret n'est jamais entré dans l'historique. Les deux sujets sont dans deux commits séparés. Les `console.log` sont restés dans le répertoire de travail, hors de l'historique.

## Les erreurs fréquentes

- **`git add .` sans avoir lu `git status`** : c'est ainsi que des fichiers de configuration locale ou des secrets finissent dans l'historique.
- **Oublier l'index** : modifier un fichier après l'avoir indexé, puis commiter. Seule la version indexée part dans le commit, les modifications suivantes restent de côté.
- **Des messages vides de sens**, qui rendent l'historique inutile le jour où l'on en a besoin.
- **Ajouter le `.gitignore` trop tard**, après avoir commité les fichiers qu'il devait exclure.

## Retour au besoin

Lucas voulait choisir précisément ce qu'il enregistre. L'index lui permet de composer chaque commit comme il le souhaite, fichier par fichier et même bloc par bloc. Le `.gitignore` protège définitivement ses secrets et ses fichiers générés. Son historique raconte clairement l'évolution du projet, sujet par sujet.

## À retenir

- Une modification passe du répertoire de travail à l'index avec `git add`, puis au dépôt avec `git commit`.
- `git status` et `git diff --staged` avant chaque commit.
- Un commit atomique, un message qui explique pourquoi.
- Le `.gitignore` protège le dépôt des fichiers générés et des secrets, dès le premier commit.

## Pour aller plus loin

- Pro Git, chapitre 2 « Les bases de Git » : [git-scm.com/book/fr/v2](https://git-scm.com/book/fr/v2)
- Des modèles de `.gitignore` pour chaque langage : [github.com/github/gitignore](https://github.com/github/gitignore)
