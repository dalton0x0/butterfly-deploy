## Objectifs

- Annuler une modification qui n'a pas encore été enregistrée
- Corriger le dernier commit
- Mettre du travail de côté temporairement
- Choisir entre `revert` et `reset` pour revenir en arrière
- Retrouver un commit que l'on croyait perdu

## Le besoin

Tout le monde se trompe. Quelques situations très courantes :

- Nina a modifié un fichier pendant une heure, le résultat est pire qu'avant. Elle veut **revenir à la dernière version enregistrée**.
- Hugo vient de commiter mais a **oublié un fichier**, et son message contient une faute.
- Léa est au milieu d'une fonctionnalité quand on lui demande une **correction urgente** sur une autre partie du projet. Elle ne veut ni perdre ni commiter son travail inachevé.
- Un commit poussé la veille a introduit un **bug en production**. Il faut l'annuler vite, sans perturber le reste de l'équipe.
- Après une fausse manœuvre, un commit semble avoir **disparu**.

Git propose une commande adaptée à chacune de ces situations. Le point essentiel est de savoir lesquelles sont sans danger et lesquelles **réécrivent l'historique**.

## Définitions

> **Réécrire l'historique.** Modifier ou supprimer des commits existants. Les commits réécrits reçoivent de nouvelles empreintes. C'est sans conséquence sur des commits locaux, mais dangereux sur des commits déjà partagés.

> **Commit parent.** Le commit qui précède un commit donné. `HEAD~1` désigne le parent de `HEAD`, `HEAD~2` le grand-parent, et ainsi de suite.

> **Stash.** Une réserve temporaire où Git range des modifications non commitées pour les ressortir plus tard.

## Annuler une modification non commitée : git restore

```bash
git restore index.html            # abandonne les modifications du fichier
git restore .                     # abandonne toutes les modifications en cours
git restore --staged index.html   # retire le fichier de l'index, sans toucher au contenu
```

| Commande | Effet sur le fichier | Réversible ? |
|----------|----------------------|--------------|
| `git restore fichier` | Revient à la version du dernier commit | **Non** : les modifications sont perdues |
| `git restore --staged fichier` | Reste modifié, mais sort de l'index | Oui |

`git restore` sur un fichier modifié efface **définitivement** vos modifications en cours. Git ne les a jamais enregistrées, il ne pourra pas les retrouver. Faites un `git diff` avant si vous avez un doute.

Vous rencontrerez aussi l'ancienne syntaxe `git checkout -- fichier`, qui fait la même chose.

## Corriger le dernier commit : --amend

Un fichier oublié ou une faute dans le message ? `--amend` remplace le dernier commit par une version corrigée.

```bash
git add fichier-oublie.css
git commit --amend -m "feat(contact): add contact page with styles"
```

Pour garder le message tel quel :

```bash
git commit --amend --no-edit
```

`--amend` ne modifie pas le commit : il en crée un **nouveau** avec une nouvelle empreinte, qui remplace l'ancien. N'utilisez cette commande que sur un commit **qui n'a pas encore été poussé**. Sinon, votre historique ne correspond plus à celui de vos collègues.

## Mettre de côté : git stash

Léa doit changer de branche en urgence, mais son travail n'est pas prêt à être commité.

```bash
git stash push -m "formulaire en cours"   # range les modifications
git switch main                            # le répertoire de travail est propre
# ... correction urgente, commit ...
git switch feature/formulaire
git stash pop                              # ressort les modifications et vide la réserve
```

| Commande | Rôle |
|----------|------|
| `git stash list` | Lister les éléments mis de côté |
| `git stash pop` | Réappliquer le dernier élément et le retirer de la réserve |
| `git stash apply` | Réappliquer sans retirer, pratique pour l'appliquer sur plusieurs branches |
| `git stash drop` | Supprimer un élément de la réserve |

Par défaut, les fichiers non suivis ne sont pas mis de côté. Ajoutez `-u` pour les inclure.

## Annuler un commit partagé : git revert

`git revert` crée un **nouveau commit** qui applique exactement l'inverse d'un commit existant. L'historique est conservé : on ajoute une correction au lieu d'effacer le passé.

```bash
git revert e41b2c7
```

```text
Avant :  A --- B --- C (bug) --- D
Après :  A --- B --- C (bug) --- D --- C' (annule C)
```

C'est la méthode à utiliser sur une branche partagée. Vos collègues récupèrent simplement un commit de plus, rien n'est cassé chez eux. Et l'historique garde la trace du problème et de sa correction.

## Revenir en arrière localement : git reset

`git reset` déplace la branche vers un commit antérieur. Les commits situés après ce point sortent de l'historique de la branche. L'option choisie décide du sort de leurs modifications :

| Option | Les modifications des commits annulés |
|--------|---------------------------------------|
| `--soft` | Restent dans l'index, prêtes à être recommitées |
| `--mixed` (défaut) | Restent dans les fichiers, mais hors de l'index |
| `--hard` | Sont **effacées**, tout comme les modifications en cours |

```text
Avant :  A --- B --- C --- D   (main)
git reset --soft B
Après :  A --- B   (main)       les modifications de C et D sont dans l'index
```

Cas d'usage typiques :

```bash
# J'ai fait trois petits commits locaux, je veux les regrouper en un seul
git reset --soft HEAD~3
git commit -m "feat(contact): add contact form"

# J'ai commité trop tôt, je veux reprendre mes fichiers
git reset HEAD~1

# Je veux tout jeter et revenir à l'état du dernier commit
git reset --hard HEAD
```

## Revert ou reset ?

| Situation | Commande |
|-----------|----------|
| Le commit est déjà poussé et partagé | `git revert` |
| Le commit est local et je veux le refaire autrement | `git reset --soft` |
| Je veux tout jeter et repartir d'un état propre | `git reset --hard`, avec prudence |

Règle d'or : **on ne réécrit jamais un historique déjà partagé**. `--amend`, `reset` et `rebase` sont réservés aux commits locaux.

## Le filet de sécurité : git reflog

Git garde pendant environ 90 jours la trace de toutes les positions prises par `HEAD`, même après un `reset --hard`. Un commit « perdu » n'est en réalité plus référencé par aucune branche, mais il existe encore.

```bash
git reflog
```

```text
9d03a18 HEAD@{0}: reset: moving to HEAD~2
b7a1f0e HEAD@{1}: commit: feat(contact): add contact form
3c9d4e2 HEAD@{2}: commit: fix(home): correct typo
```

```bash
git reset --hard b7a1f0e    # revenir à l'état d'avant la fausse manœuvre
```

Attention : `reflog` ne retrouve que ce qui a été **commité**. Des modifications jamais commitées puis effacées par `restore` ou `reset --hard` sont perdues pour de bon.

## Exemple complet

Le commit `e41b2c7`, poussé hier, a cassé le formulaire de contact en production. En parallèle, Hugo a deux commits locaux mal nommés qu'il veut regrouper.

```bash
# 1. Annuler proprement le commit partagé
git switch main
git pull
git revert e41b2c7
git push

# 2. Réorganiser ses commits locaux, jamais poussés
git switch feature/newsletter
git log --oneline
#   a91c3d2 wip
#   f02b8e1 test
git reset --soft HEAD~2
git commit -m "feat(newsletter): add subscription form"
```

La production est réparée par un nouveau commit visible de tous. Les deux commits brouillons d'Hugo sont devenus un seul commit clair, sans que personne d'autre ne soit affecté.

## Les erreurs fréquentes

- **`git reset --hard` par réflexe** : il efface sans retour les modifications non commitées.
- **`--amend` ou `reset` sur un commit déjà poussé**, suivi d'un `push --force` : les collègues se retrouvent avec un historique divergent.
- **Oublier un stash** : `git stash list` régulièrement, sinon le travail mis de côté s'accumule et se perd de vue.
- **Paniquer** après une fausse manœuvre : un commit n'est presque jamais perdu, `git reflog` le retrouve.

## Retour au besoin

Chaque situation du début a sa réponse. Nina abandonne ses modifications avec `restore`. Hugo corrige son dernier commit avec `--amend` et regroupe ses brouillons avec `reset --soft`. Léa range son travail avec `stash`. L'équipe annule le bug de production avec `revert` sans perturber personne. Et `reflog` rattrape les fausses manœuvres. Savoir annuler sans crainte, c'est ce qui permet d'expérimenter sereinement.

## À retenir

- `git restore` annule des modifications locales, parfois définitivement.
- `--amend` corrige le dernier commit s'il n'est pas encore poussé.
- `git stash` met un travail inachevé de côté.
- `revert` annule proprement un commit partagé, `reset` réécrit l'historique local.
- `git reflog` retrouve un commit perdu après une fausse manœuvre.

## Pour aller plus loin

- Pro Git, section 2.4 « Annuler des actions » et section 7.7 « Reset démystifié » : [git-scm.com/book/fr/v2](https://git-scm.com/book/fr/v2)
