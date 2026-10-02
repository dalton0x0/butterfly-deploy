## Objectifs

- Comprendre pourquoi un schéma normalisé impose de combiner les tables
- Écrire une jointure interne avec `INNER JOIN`
- Conserver les lignes sans correspondance avec `LEFT JOIN`
- Enchaîner plusieurs jointures pour traverser une table d'association
- Éviter les pièges classiques : `LEFT JOIN` filtré et produit cartésien

## Le besoin

La normalisation a rangé chaque information à un seul endroit. Mais l'écran « Mes inscriptions » d'un apprenant doit afficher, sur une même ligne :

| Formation | Catégorie | Inscrit le | Note |
|-----------|-----------|------------|------|
| Java | Développement | 10/01/2026 | 16,5 |
| SQL | Données | 10/01/2026 | 14 |

Or ces informations sont réparties dans **trois tables** : `inscriptions` (la date et la note), `formations` (le titre) et `categories` (le nom de la catégorie). La table `inscriptions` ne contient que des identifiants : `formation_id = 1`. Il faut un moyen de **reconstituer** l'information complète en suivant les clés étrangères. C'est le rôle des jointures.

## Définitions

> **Jointure.** Une opération qui combine les lignes de deux tables selon une condition, le plus souvent l'égalité entre une clé étrangère et la clé primaire qu'elle référence.

> **Condition de jointure.** L'expression placée après `ON` qui décrit comment les lignes se correspondent : `ON f.id = i.formation_id`.

> **Jointure interne (INNER JOIN).** Ne garde que les lignes qui ont une correspondance dans les deux tables.

> **Jointure externe gauche (LEFT JOIN).** Garde toutes les lignes de la table de gauche, avec ou sans correspondance dans celle de droite.

## Le principe d'une jointure

Prenons deux petites tables :

```text
formations                              categories
┌────┬──────────────┬───────────┐       ┌────┬───────────────┐
│ id │ categorie_id │ titre     │       │ id │ nom           │
├────┼──────────────┼───────────┤       ├────┼───────────────┤
│ 1  │ 1            │ Java      │       │ 1  │ Développement │
│ 2  │ 2            │ SQL       │       │ 2  │ Données       │
│ 3  │ 1            │ PHP       │       │ 3  │ Infrastructure│
└────┴──────────────┴───────────┘       └────┴───────────────┘
```

Une jointure associe chaque formation à la catégorie dont l'`id` est égal à son `categorie_id` :

```text
Java  (categorie_id 1)  ──►  Développement (id 1)
SQL   (categorie_id 2)  ──►  Données       (id 2)
PHP   (categorie_id 1)  ──►  Développement (id 1)
```

## INNER JOIN

```sql
SELECT f.titre, c.nom AS categorie
FROM formations f
INNER JOIN categories c ON c.id = f.categorie_id;
```

| titre | categorie |
|-------|-----------|
| Java | Développement |
| SQL | Données |
| PHP | Développement |

Lisons la requête :

- `FROM formations f` : on part de la table `formations`, désignée par l'**alias** `f`.
- `INNER JOIN categories c` : on la combine avec `categories`, alias `c`.
- `ON c.id = f.categorie_id` : une formation et une catégorie vont ensemble quand l'identifiant de la catégorie est égal à la clé étrangère de la formation.

Les alias raccourcissent l'écriture et lèvent toute ambiguïté : les deux tables ont une colonne `id`, et `f.id` ou `c.id` précise laquelle on veut. Écrire `JOIN` seul est équivalent à `INNER JOIN`.

La catégorie « Infrastructure » n'apparaît pas : aucune formation ne lui correspond. C'est la définition de la jointure **interne**.

## LEFT JOIN

Le secrétariat veut la liste de **tous** les apprenants avec leurs inscriptions, y compris ceux qui ne sont inscrits nulle part. Un `INNER JOIN` les ferait disparaître.

`LEFT JOIN` garde **toutes** les lignes de la table de gauche. Quand il n'y a pas de correspondance, les colonnes de la table de droite valent `NULL`.

```sql
SELECT a.prenom, a.nom, i.formation_id, i.note_finale
FROM apprenants a
LEFT JOIN inscriptions i ON i.apprenant_id = a.id;
```

| prenom | nom | formation_id | note_finale |
|--------|-----|--------------|-------------|
| Emma | Petit | 1 | 16.50 |
| Emma | Petit | 4 | 14.00 |
| Lucas | Bernard | 1 | 9.50 |
| ... | ... | ... | ... |
| Tom | Moreau | NULL | NULL |

Tom apparaît, sans inscription. La table « de gauche » est celle qui est écrite **avant** le mot `LEFT JOIN`.

## Trouver ce qui n'a pas de correspondance

Combiné à `IS NULL`, le `LEFT JOIN` répond à une question très fréquente : « qui n'a pas de... ? »

```sql
-- Apprenants inscrits à aucune formation
SELECT a.prenom, a.nom
FROM apprenants a
LEFT JOIN inscriptions i ON i.apprenant_id = a.id
WHERE i.apprenant_id IS NULL;

-- Formations sans aucun inscrit
SELECT f.titre
FROM formations f
LEFT JOIN inscriptions i ON i.formation_id = f.id
WHERE i.formation_id IS NULL;
```

On teste une colonne de la table de droite qui ne peut pas être `NULL` quand la correspondance existe, typiquement sa clé.

## Les types de jointures

| Jointure | Lignes conservées |
|----------|-------------------|
| `INNER JOIN` | Seulement celles qui correspondent des deux côtés |
| `LEFT JOIN` | Toutes celles de gauche, complétées par `NULL` à droite |
| `RIGHT JOIN` | Toutes celles de droite. Rarement utilisé : on inverse l'ordre des tables et on écrit un `LEFT JOIN` |
| `CROSS JOIN` | Toutes les combinaisons possibles, sans condition |

MySQL ne propose pas de `FULL OUTER JOIN`, qui garderait les lignes sans correspondance des deux côtés.

## Enchaîner les jointures

Pour l'écran « Mes inscriptions », il faut traverser trois tables. Chaque `JOIN` ajoute une table au résultat en suivant une clé étrangère.

```sql
SELECT f.titre,
       c.nom AS categorie,
       i.inscrit_le,
       i.note_finale
FROM inscriptions i
INNER JOIN formations f ON f.id = i.formation_id
INNER JOIN categories c ON c.id = f.categorie_id
WHERE i.apprenant_id = 1
ORDER BY i.inscrit_le;
```

```text
inscriptions ──formation_id──► formations ──categorie_id──► categories
```

Et pour voir « qui suit quoi » dans tout l'organisme, on traverse la table d'association dans les deux sens :

```sql
SELECT a.prenom, a.nom, f.titre, i.note_finale
FROM inscriptions i
INNER JOIN apprenants a ON a.id = i.apprenant_id
INNER JOIN formations f ON f.id = i.formation_id
ORDER BY a.nom, f.titre;
```

## Le piège du LEFT JOIN filtré

On veut **tous** les apprenants, avec leurs formations **réussies** seulement (note d'au moins 10). Première tentative :

```sql
SELECT a.prenom, i.note_finale
FROM apprenants a
LEFT JOIN inscriptions i ON i.apprenant_id = a.id
WHERE i.note_finale >= 10;
```

Tom et tous ceux qui n'ont aucune réussite disparaissent. Pourquoi ? Le `WHERE` s'applique **après** la jointure. Pour Tom, `i.note_finale` vaut `NULL`, et `NULL >= 10` n'est pas vrai : la ligne est éliminée. Le `LEFT JOIN` se comporte alors comme un `INNER JOIN`.

La condition sur la table de droite doit aller dans le `ON` :

```sql
SELECT a.prenom, i.note_finale
FROM apprenants a
LEFT JOIN inscriptions i ON i.apprenant_id = a.id AND i.note_finale >= 10;
```

Cette fois, la condition décide **quelles inscriptions** sont associées, sans jamais éliminer d'apprenant.

## Le produit cartésien

Une jointure dont la condition est absente ou fausse associe **chaque** ligne de la première table à **chaque** ligne de la seconde. 1 000 apprenants et 50 formations donnent 50 000 lignes.

```sql
-- Condition oubliée : chaque inscription est associée à chaque formation
SELECT i.apprenant_id, f.titre
FROM inscriptions i
INNER JOIN formations f ON f.id = f.id;
```

Si un résultat compte beaucoup plus de lignes que prévu, ou si des valeurs semblent dupliquées, vérifiez d'abord vos conditions `ON`.

## Exemple complet

Construisons l'écran « Mes inscriptions » d'Emma, avec les formations non notées affichées comme telles.

```sql
SELECT f.titre                                         AS formation,
       c.nom                                           AS categorie,
       DATE_FORMAT(i.inscrit_le, '%d/%m/%Y')           AS inscrit_le,
       COALESCE(CAST(i.note_finale AS CHAR), 'En cours') AS note
FROM apprenants a
INNER JOIN inscriptions i ON i.apprenant_id = a.id
INNER JOIN formations f   ON f.id = i.formation_id
INNER JOIN categories c   ON c.id = f.categorie_id
WHERE a.email = 'emma.petit@exemple.fr'
ORDER BY i.inscrit_le, f.titre;
```

| formation | categorie | inscrit_le | note |
|-----------|-----------|------------|------|
| Java | Développement | 10/01/2026 | 16.50 |
| SQL | Données | 10/01/2026 | 14.00 |
| Spring Boot | Développement | 02/03/2026 | En cours |

## Les erreurs fréquentes

- **Oublier la condition `ON`** ou se tromper de colonne, et obtenir un produit cartésien.
- **Filtrer la table de droite d'un `LEFT JOIN` dans le `WHERE`**, ce qui annule son effet.
- **Colonnes ambiguës** : `SELECT id` avec deux tables qui ont une colonne `id` provoque une erreur. Préfixez par l'alias.
- **`INNER JOIN` quand on voulait tout garder**, et des lignes qui disparaissent sans message.

## Retour au besoin

L'écran « Mes inscriptions » est reconstitué en une seule requête, à partir de trois tables normalisées. La normalisation évite la redondance au stockage, les jointures recomposent l'information à la lecture : les deux vont ensemble. Le cours suivant montre comment aller plus loin en calculant des totaux, des moyennes et des indicateurs.

## À retenir

- Une jointure suit une clé étrangère vers la clé primaire qu'elle référence.
- `INNER JOIN` garde les correspondances, `LEFT JOIN` garde toute la table de gauche.
- `LEFT JOIN` suivi de `IS NULL` trouve les lignes sans correspondance.
- Une table d'association se traverse avec deux jointures.
- Une condition sur la table de droite d'un `LEFT JOIN` va dans le `ON`, pas dans le `WHERE`.

## Pour aller plus loin

- La documentation de MySQL sur les jointures : [dev.mysql.com/doc](https://dev.mysql.com/doc/refman/8.4/en/join.html)
