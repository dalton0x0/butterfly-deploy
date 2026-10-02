## Objectifs

- Comprendre le rôle d'un dépôt distant et des branches de suivi
- Relier un dépôt local à un dépôt distant
- Envoyer et récupérer des modifications avec `push`, `fetch` et `pull`
- Comprendre le rôle d'une pull request et le déroulé d'une contribution
- Connaître les règles qui protègent une branche partagée

## Le besoin

Jusqu'ici, le dépôt d'Emma n'existe que sur son ordinateur. Trois problèmes apparaissent :

- **Partager** : Lucas et Nina rejoignent le projet. Comment récupèrent-ils le code et l'historique ? Comment Emma reçoit-elle leur travail ?
- **Sauvegarder** : si l'ordinateur d'Emma tombe en panne, tout est perdu.
- **Contrôler la qualité** : avant qu'une modification n'arrive dans la version en ligne, l'équipe veut la relire et vérifier que les tests passent.

Il faut un **point de rencontre** commun où chacun envoie et récupère les commits, et un **processus de relecture** avant l'intégration. C'est le rôle des dépôts distants et des pull requests.

## Définitions

> **Dépôt distant (remote).** Une copie du dépôt hébergée sur un serveur : GitHub, GitLab, Bitbucket ou un serveur d'entreprise. On le désigne par un nom court, par convention `origin`.

> **Branche de suivi (remote-tracking branch).** Une copie locale, en lecture seule, de l'état d'une branche distante lors de la dernière synchronisation. Par exemple `origin/main`.

> **Branche amont (upstream).** La branche distante associée à une branche locale. Elle permet de lancer `git push` et `git pull` sans préciser où envoyer ni d'où récupérer.

> **Pull request (merge request sur GitLab).** Une demande de fusion d'une branche dans une autre, ouverte sur la plateforme d'hébergement. Elle sert d'espace de relecture et de vérification avant la fusion.

## Relier un dépôt local à un dépôt distant

Après avoir créé un dépôt vide sur GitHub, on le déclare dans le dépôt local :

```bash
git remote add origin https://github.com/emma/site-association.git
git remote -v                     # vérifier les dépôts distants déclarés
```

```text
origin  https://github.com/emma/site-association.git (fetch)
origin  https://github.com/emma/site-association.git (push)
```

Un dépôt obtenu avec `git clone` a déjà son `origin` configuré, et sa branche `main` est déjà reliée à `origin/main`.

## Envoyer ses commits : git push

```bash
git push -u origin main    # premier envoi : -u relie main à origin/main
git push                   # envois suivants
```

`push` envoie les commits locaux qui n'existent pas encore sur le serveur. Git **refuse** un `push` si le dépôt distant contient des commits que vous n'avez pas encore récupérés :

```text
! [rejected]        main -> main (fetch first)
error: failed to push some refs
hint: Updates were rejected because the remote contains work that you do not have locally.
```

Ce refus protège le travail des autres : il faut d'abord intégrer leurs commits, puis renvoyer.

## Récupérer le travail des autres : fetch et pull

| Commande | Effet |
|----------|-------|
| `git fetch` | Télécharge les nouveaux commits et met à jour `origin/main`, sans toucher à vos fichiers ni à votre branche |
| `git pull` | `fetch` puis intégration dans la branche courante, par fusion ou par rebase selon la configuration |

```bash
git fetch origin
git log --oneline main..origin/main    # commits arrivés sur le serveur, absents en local
git diff main origin/main              # différences détaillées
git merge origin/main                  # intégrer quand on est prêt
```

`fetch` suivi d'une lecture de l'historique est plus prudent qu'un `pull` à l'aveugle : vous voyez ce qui arrive avant de l'intégrer. Beaucoup d'équipes configurent `git config --global pull.rebase true` pour que `pull` rejoue les commits locaux au-dessus des commits distants, ce qui évite des commits de fusion inutiles.

## Le danger de push --force

`git push --force` remplace l'historique distant par le vôtre. Les commits que vos collègues ont poussés entre-temps disparaissent de la branche.

```text
Serveur :  A ─── B ─── C (commit de Lucas)
Local :    A ─── B ─── D (votre commit, après un reset)

git push --force   →   Serveur :  A ─── B ─── D      le commit de Lucas a disparu
```

Sur une branche partagée, c'est à proscrire. Si vous devez vraiment forcer, par exemple après un rebase de **votre** branche de fonctionnalité, utilisez `--force-with-lease` : il refuse l'envoi si quelqu'un a poussé depuis votre dernière récupération.

## Les pull requests

Une pull request n'est pas une commande Git mais une fonction des plateformes d'hébergement. Elle transforme la fusion en un **moment d'échange** :

- les collègues **relisent** le code et laissent des commentaires ligne par ligne ;
- l'**intégration continue** lance automatiquement les tests, la compilation et l'analyse de qualité ;
- l'auteur répond aux remarques en ajoutant des commits sur sa branche : la pull request se met à jour toute seule ;
- la fusion n'a lieu qu'une fois les relectures approuvées et les vérifications au vert.

Une bonne description de pull request répond à trois questions : **quoi** (ce qui change), **pourquoi** (le besoin ou le ticket d'origine) et **comment vérifier** (les étapes pour tester).

## Le déroulé type d'une contribution

```bash
# 1. Partir d'une base à jour
git switch main
git pull

# 2. Une branche par fonctionnalité
git switch -c feature/password-reset

# 3. Développer par commits atomiques
git add ...
git commit -m "feat(auth): add password reset form"

# 4. Publier la branche
git push -u origin feature/password-reset

# 5. Ouvrir la pull request sur la plateforme, répondre aux relectures
git commit -m "fix(auth): handle expired reset token"
git push

# 6. Fusion par la plateforme une fois approuvée, puis nettoyage local
git switch main
git pull
git branch -d feature/password-reset
```

## Protéger la branche principale

Sur un projet d'équipe, la branche `main` est généralement **protégée** par des règles de la plateforme :

| Règle | Effet |
|-------|-------|
| Pas de push direct | Toute modification passe par une pull request |
| Relecture obligatoire | Au moins une approbation d'un collègue |
| Vérifications obligatoires | Les tests et l'analyse doivent être au vert |
| Pas de push forcé | L'historique partagé ne peut pas être réécrit |

`main` reste ainsi toujours dans un état **déployable**.

## Exemple complet

Nina rejoint l'équipe et doit ajouter une page « Mentions légales ».

```bash
git clone https://github.com/emma/site-association.git
cd site-association
git switch -c feature/legal-notice
# ... création de la page ...
git add mentions-legales.html
git commit -m "feat(legal): add legal notice page"
git push -u origin feature/legal-notice
```

Elle ouvre une pull request. Emma relit et demande d'ajouter un lien dans le pied de page. Nina ajoute un commit et pousse : la pull request se met à jour. Pendant ce temps, Lucas a fusionné sa page agenda dans `main`. Nina met sa branche à jour :

```bash
git fetch origin
git rebase origin/main
git push --force-with-lease    # autorisé : c'est sa propre branche
```

L'intégration continue passe au vert, Emma approuve, la pull request est fusionnée. Nina récupère `main` et supprime sa branche locale.

## Les erreurs fréquentes

- **Travailler directement sur `main`** au lieu d'une branche de fonctionnalité.
- **`push --force` sur une branche partagée**, qui efface le travail des autres.
- **Des pull requests énormes**, impossibles à relire sérieusement. Mieux vaut plusieurs petites pull requests ciblées.
- **Oublier de mettre sa base à jour** avant de créer une branche, ce qui prépare des conflits inutiles.

## Retour au besoin

Le dépôt distant sert de point de rencontre : chacun y envoie ses commits et y récupère ceux des autres, et il constitue une sauvegarde. La pull request ajoute la relecture et les vérifications automatiques avant toute intégration. Avec une branche principale protégée, aucune modification n'arrive en ligne sans avoir été relue et testée.

## À retenir

- `origin` désigne par convention le dépôt distant principal.
- `push` envoie, `fetch` récupère sans intégrer, `pull` récupère et intègre.
- Jamais de `push --force` sur une branche partagée, `--force-with-lease` sur sa propre branche si nécessaire.
- La pull request est le lieu de la relecture et des vérifications automatiques.

## Pour aller plus loin

- Pro Git, section 2.5 « Travailler avec des dépôts distants » et chapitre 5 « Git distribué » : [git-scm.com/book/fr/v2](https://git-scm.com/book/fr/v2)
- La documentation GitHub sur les pull requests : [docs.github.com](https://docs.github.com/fr/pull-requests)
