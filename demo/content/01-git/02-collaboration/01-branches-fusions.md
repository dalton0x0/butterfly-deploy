## Objectifs

- Comprendre ce qu'est une branche et pourquoi elle est si légère
- Créer une branche, passer de l'une à l'autre et la supprimer
- Fusionner une branche et distinguer fast-forward et fusion à trois points
- Comprendre, lire et résoudre un conflit de fusion
- Connaître l'alternative du rebase et ses limites

## Le besoin

Le site de l'association est en ligne. Emma doit y ajouter un espace membre, un travail de deux semaines. Pendant ce temps :

- le site doit rester **stable** : impossible de mettre en ligne un espace membre à moitié terminé ;
- un bug urgent peut être signalé à tout moment et doit être corrigé **immédiatement** ;
- Lucas travaille en parallèle sur une page d'agenda.

Si tout le monde modifie la même version du code, le travail inachevé des uns bloque la mise en ligne des autres. Il faut un moyen de **développer en parallèle** plusieurs évolutions isolées, puis de les **réunir** quand elles sont prêtes. C'est le rôle des branches.

## Définitions

> **Branche.** Un pointeur léger vers un commit. Quand on commite sur une branche, le pointeur avance automatiquement vers le nouveau commit.

> **Fusion (merge).** L'opération qui intègre les commits d'une branche dans une autre.

> **Conflit de fusion.** Une situation où Git ne peut pas fusionner automatiquement, parce que les deux branches ont modifié les mêmes lignes d'un même fichier.

> **Ancêtre commun.** Le dernier commit partagé par deux branches, là où elles se sont séparées.

## Une branche, c'est un simple pointeur

Une branche ne copie aucun fichier. C'est un petit fichier qui contient l'empreinte d'un commit. En créer une est donc **instantané**, même sur un projet énorme.

```text
                 main
                  │
A ─── B ─── C ────┘
                  │
            feature/membres
```

Juste après sa création, `feature/membres` pointe sur le même commit que `main`. Dès qu'Emma commite sur sa branche, seul son pointeur avance :

```text
              main
               │
A ─── B ─── C ─┘
             \
              D ─── E
                    │
             feature/membres
```

`HEAD` indique la branche sur laquelle vous vous trouvez. Les commits partent toujours sur la branche désignée par `HEAD`.

## Manipuler les branches

```bash
git branch                          # lister les branches locales, * marque la courante
git switch -c feature/membres       # créer une branche et s'y placer
git switch main                     # changer de branche
git branch -d feature/membres       # supprimer une branche déjà fusionnée
git branch -D feature/abandonnee    # forcer la suppression d'une branche non fusionnée
```

`git switch` est la commande moderne pour changer de branche. Vous rencontrerez aussi `git checkout`, plus ancien, qui cumule plusieurs rôles et prête à confusion.

Quand on change de branche, Git **remplace les fichiers** du répertoire de travail par ceux de la branche cible. Si vous avez des modifications non commitées qui entrent en conflit, Git refuse de changer de branche : commitez-les ou mettez-les de côté avec `git stash`.

## Fusionner

Une fois l'espace membre terminé, on se place sur la branche qui doit **recevoir** les modifications, puis on fusionne.

```bash
git switch main
git merge feature/membres
```

Deux cas se présentent.

### Cas 1 : fast-forward

Si `main` n'a pas bougé depuis la création de la branche, il suffit d'avancer le pointeur de `main`. Aucun nouveau commit n'est créé.

```text
Avant :   A ─── B ─── C (main) ─── D ─── E (feature)
Après :   A ─── B ─── C ─── D ─── E (main, feature)
```

### Cas 2 : fusion à trois points

Si `main` a évolué entre-temps, par exemple avec une correction urgente, les deux branches ont divergé. Git compare trois versions : l'ancêtre commun et les deux extrémités. Il crée alors un **commit de fusion** qui a deux parents.

```text
Avant :              D ─── E   (feature)
                    /
         A ─── B ─── C ─── F   (main, correction urgente)

Après :              D ─── E
                    /       \
         A ─── B ─── C ─── F ─── M   (main, M = commit de fusion)
```

## Les conflits

Git fusionne automatiquement tant que les deux branches ont modifié des fichiers différents, ou des zones différentes d'un même fichier. Un **conflit** survient quand les deux branches ont modifié **les mêmes lignes**. Git ne peut pas deviner la bonne version : il s'arrête et vous demande de trancher.

```text
Auto-merging index.html
CONFLICT (content): Merge conflict in index.html
Automatic merge failed; fix conflicts and then commit the result.
```

Le fichier contient alors des **marqueurs de conflit** :

```html
<<<<<<< HEAD
<h1>Bienvenue sur le site de l'association</h1>
=======
<h1>Association des Jardins partagés</h1>
>>>>>>> feature/membres
```

| Marqueur | Signification |
|----------|---------------|
| `<<<<<<< HEAD` | Début de la version de la branche courante, celle qui reçoit |
| `=======` | Séparation entre les deux versions |
| `>>>>>>> feature/membres` | Fin de la version de la branche fusionnée |

## Résoudre un conflit, étape par étape

1. Listez les fichiers en conflit avec `git status`. Ils apparaissent comme « both modified ».
2. Ouvrez chaque fichier. Choisissez une version, l'autre, ou une combinaison des deux.
3. Supprimez **tous** les marqueurs `<<<<<<<`, `=======` et `>>>>>>>`.
4. Vérifiez que le projet fonctionne encore.
5. Indexez chaque fichier résolu, puis terminez la fusion.

```html
<h1>Bienvenue à l'Association des Jardins partagés</h1>
```

```bash
git add index.html
git commit          # Git propose un message de fusion par défaut
```

En cas de doute, `git merge --abort` annule toute la fusion et restaure l'état précédent. Les éditeurs comme IntelliJ ou VS Code proposent aussi une vue en trois colonnes qui facilite beaucoup la résolution.

Un conflit n'est pas une erreur : c'est Git qui refuse de prendre une décision à votre place. Des branches **courtes** et fusionnées **souvent** limitent leur taille et leur fréquence.

## Merge ou rebase ?

`git rebase` est une autre façon d'intégrer des modifications. Au lieu de créer un commit de fusion, il **rejoue** les commits de votre branche au-dessus de la branche cible.

```bash
git switch feature/agenda
git rebase main
```

```text
Avant :          D ─── E   (feature/agenda)
                /
       A ─── B ─── C ─── F   (main)

Après :                      D' ─── E'   (feature/agenda)
                            /
       A ─── B ─── C ─── F   (main)
```

| | Merge | Rebase |
|---|-------|--------|
| Historique | Conserve la réalité, avec des commits de fusion | Linéaire et plus lisible |
| Réécrit les commits ? | Non | Oui : D' et E' sont de nouveaux commits |
| Sans danger sur une branche partagée ? | Oui | **Non** |

Le rebase réécrit l'historique. Réservez-le à vos branches personnelles, avant de les partager, par exemple pour mettre votre branche à jour avec `main` avant d'ouvrir une pull request.

## Exemple complet

```bash
# Emma démarre l'espace membre
git switch main
git switch -c feature/membres
# ... plusieurs commits ...

# Un bug urgent arrive : correction sur une branche dédiée
git stash
git switch main
git switch -c fix/footer-link
# ... correction et commit ...
git switch main
git merge fix/footer-link        # fast-forward : main n'avait pas bougé
git branch -d fix/footer-link

# Retour à l'espace membre, terminé quelques jours plus tard
git switch feature/membres
git stash pop
# ... derniers commits ...
git switch main
git merge feature/membres        # fusion à trois points, main a reçu la correction
# conflit sur index.html : résolution, puis
git add index.html
git commit
git branch -d feature/membres
git log --oneline --graph
```

La correction urgente a été mise en ligne sans attendre l'espace membre, et les deux évolutions ont fini réunies dans `main`.

## Les erreurs fréquentes

- **Fusionner depuis la mauvaise branche** : `git merge` intègre la branche nommée **dans la branche courante**. Vérifiez où vous êtes avec `git status`.
- **Laisser des marqueurs de conflit** dans un fichier, qui casse alors le projet.
- **Des branches qui vivent des semaines** sans intégrer `main` : les conflits deviennent énormes.
- **Rebaser une branche partagée**, ce qui oblige les collègues à réparer leur copie.

## Retour au besoin

Grâce aux branches, Emma développe l'espace membre dans son coin, Lucas l'agenda dans le sien, et la version en ligne reste stable. La correction urgente passe par sa propre branche et part en production immédiatement. Quand chaque évolution est prête, la fusion la réunit aux autres, et Git signale précisément les rares endroits où une décision humaine est nécessaire.

## À retenir

- Une branche est un pointeur léger : on en crée une par fonctionnalité ou correction.
- On fusionne depuis la branche qui reçoit les modifications.
- Fast-forward si la cible n'a pas bougé, commit de fusion sinon.
- Un conflit se résout à la main, en supprimant tous les marqueurs, et `git merge --abort` permet de repartir d'un état propre.
- Le rebase donne un historique linéaire mais réécrit les commits : jamais sur une branche partagée.

## Pour aller plus loin

- Pro Git, chapitre 3 « Les branches avec Git » : [git-scm.com/book/fr/v2](https://git-scm.com/book/fr/v2)
- Un exercice interactif et visuel sur les branches : [learngitbranching.js.org](https://learngitbranching.js.org/?locale=fr_FR)
