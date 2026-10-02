## Objectifs

- Comprendre pourquoi une équipe a besoin de conventions communes
- Nommer ses branches de façon cohérente
- Écrire des messages de commit selon Conventional Commits
- Comprendre le versionnage sémantique
- Marquer une version publiée avec un tag annoté

## Le besoin

Six mois après le lancement, l'historique du site de l'association ressemble à ceci :

```text
f3a91c2 modifs
8b2e4d1 ok
c7d03f9 correction bug
1e5a8b7 Update index.html
9f2c6e3 wip
4d8b1a0 nouvelle version
```

Et la liste des branches :

```text
emma-test
branche2
nouveau-menu
fix
lucas
```

Le jour où un bug apparaît en production, personne ne sait quel commit l'a introduit. Pour préparer une nouvelle version, impossible de lister ce qui a changé depuis la précédente. Et personne ne sait ce que contiennent les branches `fix` ou `lucas`.

Un historique Git est lu **bien plus souvent** qu'il n'est écrit : pour comprendre l'origine d'un bug, préparer une version, reprendre le travail d'un collègue ou faire relire son code. Des **conventions partagées** rendent cette lecture rapide et permettent même d'automatiser une partie du travail.

## Définitions

> **Convention.** Une règle d'écriture adoptée par toute l'équipe. Elle n'est pas imposée par Git, mais par l'organisation du projet.

> **Conventional Commits.** Une spécification publique qui structure les messages de commit avec un type, une portée facultative et une description.

> **Versionnage sémantique (SemVer).** Une règle de numérotation des versions au format MAJEUR.MINEUR.CORRECTIF, où chaque partie a une signification précise.

> **Tag.** Une étiquette permanente posée sur un commit, généralement pour marquer une version publiée.

## Nommer ses branches

Un **préfixe** indique la nature du travail, suivi d'une description courte en minuscules, avec des tirets :

| Préfixe | Usage | Exemple |
|---------|-------|---------|
| `feature/` | Nouvelle fonctionnalité | `feature/add-password-reset` |
| `fix/` | Correction de bug | `fix/login-validation` |
| `refactor/` | Restructuration sans changement de comportement | `refactor/simplify-quiz-scoring` |
| `docs/` | Documentation | `docs/update-install-guide` |
| `chore/` | Maintenance | `chore/upgrade-dependencies` |

Certaines équipes ajoutent le numéro du ticket : `feature/142-password-reset`. L'important est que toute l'équipe applique la même règle. Sur un projet existant, **adaptez-vous toujours à la convention déjà en place**.

## Conventional Commits

La convention structure chaque message ainsi :

```text
type(portée): description courte à l'impératif

Corps facultatif qui explique le pourquoi de la modification,
les choix faits et leurs conséquences.

Pied facultatif : références de tickets, BREAKING CHANGE.
```

| Type | Usage |
|------|-------|
| `feat` | Nouvelle fonctionnalité |
| `fix` | Correction de bug |
| `refactor` | Restructuration sans changement de comportement |
| `test` | Ajout ou modification de tests |
| `docs` | Documentation |
| `style` | Mise en forme sans effet sur le comportement |
| `perf` | Amélioration des performances |
| `chore` | Maintenance : dépendances, configuration |
| `ci` | Intégration continue |

La **portée** (entre parenthèses) indique la partie du projet concernée : `auth`, `quiz`, `users`. Elle est facultative mais aide beaucoup à la lecture.

La **description** est courte (moins de 72 caractères), à l'impératif, sans point final : on complète mentalement la phrase « Ce commit va... ».

```text
feat(auth): add password reset by email
fix(quiz): reject answers received after the time limit
refactor(users): extract email normalization
docs(readme): document demo content loading
```

Exemple avec un corps :

```text
fix(auth): revoke all sessions when a refresh token is reused

A refresh token presented twice is a strong sign of theft.
Revoking every session of the user forces an attacker out,
at the cost of logging out the legitimate user too.

Closes #87
```

Une rupture de compatibilité se signale par un `!` après le type ou par une ligne `BREAKING CHANGE:` dans le pied :

```text
feat(api)!: return paginated lists everywhere
```

## Le versionnage sémantique

Les versions suivent le format **MAJEUR.MINEUR.CORRECTIF** :

| Partie | S'incrémente quand... | Exemple |
|--------|-----------------------|---------|
| MAJEUR | Une modification casse la compatibilité | 1.4.2 vers 2.0.0 |
| MINEUR | Une fonctionnalité est ajoutée sans rupture | 1.4.2 vers 1.5.0 |
| CORRECTIF | Un bug est corrigé sans ajout | 1.4.2 vers 1.4.3 |

Quand une partie augmente, les parties suivantes repartent à zéro : après 1.4.2, une nouvelle fonctionnalité donne 1.5.0 et non 1.5.2.

Le numéro devient ainsi une **information** pour ceux qui utilisent votre logiciel. Passer de 1.4.2 à 1.4.3 est sans risque. Passer à 2.0.0 demande de lire les notes de version.

Conventional Commits et versionnage sémantique fonctionnent ensemble :

| Commits depuis la dernière version | Nouvelle version |
|------------------------------------|------------------|
| Uniquement des `fix` | Correctif |
| Au moins un `feat` | Mineure |
| Au moins une rupture (`!` ou `BREAKING CHANGE`) | Majeure |

Des outils peuvent même calculer automatiquement la prochaine version et générer le journal des modifications à partir des messages de commit.

## Marquer une version avec un tag

Un tag est une étiquette **permanente** posée sur un commit. Contrairement à une branche, il ne bouge jamais. On utilise un tag **annoté**, qui porte un auteur, une date et un message.

```bash
git tag -a v1.2.0 -m "Add multi-device sessions"
git push origin v1.2.0
```

```bash
git tag                  # lister les tags
git tag -n               # lister avec leur message
git show v1.2.0          # détail du tag et du commit
git switch --detach v1.2.0   # consulter le code tel qu'il était à cette version
```

Toujours créer le tag avec `-a` et `-m`. Un tag sans `-a` est un tag « léger », sans auteur ni date ni message.

## Garder un historique propre

- Des commits **atomiques**, un sujet par commit.
- Des branches **courtes**, fusionnées souvent, pour limiter les conflits.
- Pas de commit « wip » ou « test » dans la branche principale : regroupez-les avant la pull request avec `git reset --soft` ou un rebase interactif.
- Une seule langue pour les messages, souvent l'anglais, et toujours la même.
- Un `CHANGELOG.md` qui résume, version par version, ce qui a changé pour les utilisateurs.

## Exemple complet

L'équipe prépare la version 1.3.0 du site. Voici l'historique depuis la 1.2.0 :

```bash
git log --oneline v1.2.0..HEAD
```

```text
a8c3e21 fix(agenda): show events in local time
7d1f0b4 feat(members): add profile page
2e9a6c8 docs(readme): add contribution guide
f0b52d7 feat(agenda): add monthly view
```

Il y a deux `feat` et aucune rupture : la prochaine version est **1.3.0**. Le journal des modifications s'écrit presque tout seul, section par section. Emma pose le tag :

```bash
git tag -a v1.3.0 -m "Add monthly agenda and member profiles"
git push origin v1.3.0
```

## Les erreurs fréquentes

- **Inventer sa propre convention** dans un projet qui en a déjà une.
- **Des messages au passé ou vagues** (« fixed stuff »), qui n'apprennent rien.
- **Oublier de pousser le tag** : `git push` seul n'envoie pas les tags.
- **Déplacer un tag déjà publié** : tout le monde s'attend à ce qu'une version désigne toujours le même code.

## Retour au besoin

L'historique illisible du début devient une liste de modifications que l'on comprend d'un coup d'œil. Les branches annoncent leur contenu par leur nom. On sait immédiatement si la prochaine version est un correctif, une évolution ou une rupture, et chaque version publiée est marquée par un tag qui ne bougera plus. Les conventions ne coûtent presque rien à appliquer et font gagner un temps considérable à toute l'équipe.

## À retenir

- Un préfixe de branche indique la nature du travail.
- Un message Conventional Commits : `type(portée): description`, à l'impératif.
- Le versionnage sémantique distingue rupture, ajout et correction.
- Un tag annoté, poussé explicitement, marque durablement une version publiée.

## Pour aller plus loin

- La spécification Conventional Commits : [conventionalcommits.org/fr](https://www.conventionalcommits.org/fr/v1.0.0/)
- Le versionnage sémantique : [semver.org/lang/fr](https://semver.org/lang/fr/)
- Pro Git, section 2.6 « Étiquetage » : [git-scm.com/book/fr/v2](https://git-scm.com/book/fr/v2)
