## Objectifs

- Lire les données d'une table avec `SELECT`
- Calculer des colonnes et les renommer
- Filtrer les lignes avec `WHERE` et ses opérateurs
- Comprendre et traiter correctement la valeur `NULL`
- Trier, limiter, paginer et éliminer les doublons

## Le besoin

La base de l'organisme de formation contient maintenant des centaines de formations et des milliers d'inscriptions. Chaque jour, l'équipe a des questions :

- le service commercial veut **les formations de moins de 500 €** pour une campagne ;
- la direction veut **les 5 formations les plus chères** ;
- le secrétariat cherche **les inscriptions pas encore notées** ;
- le site web doit afficher le catalogue **20 formations par page**, triées par titre.

Parcourir les tables à la main est impossible. Il faut un moyen de **décrire précisément** le résultat voulu et de laisser la base le calculer. C'est le rôle de l'instruction `SELECT`.

## Définitions

> **Requête.** Une instruction SQL envoyée à la base. Une requête de lecture renvoie un résultat sous forme de tableau de lignes et de colonnes.

> **Projection.** Le choix des colonnes à afficher, décrit après `SELECT`.

> **Sélection (filtre).** Le choix des lignes à garder, décrit dans la clause `WHERE`.

> **NULL.** Un marqueur qui signifie « valeur inconnue ou absente ». Ce n'est ni zéro, ni une chaîne vide.

> **Alias.** Un nom temporaire donné à une colonne ou à une table dans une requête, avec le mot-clé `AS`.

## La base d'exemple

Les cours de ce module s'appuient sur la base de formations :

```text
categories   (id, nom)
formations   (id, categorie_id, titre, duree_heures, prix)
apprenants   (id, prenom, nom, email, ville)
inscriptions (apprenant_id, formation_id, inscrit_le, note_finale)
```

## Sélectionner des colonnes

```sql
SELECT titre, prix
FROM formations;
```

| titre | prix |
|-------|------|
| Java | 1200.00 |
| PHP | 950.00 |
| SQL | 600.00 |

`SELECT *` renvoie toutes les colonnes. C'est pratique pour explorer une table dans un outil comme MySQL Workbench, mais à éviter dans une application :

- il ramène des données inutiles, ce qui coûte du réseau et de la mémoire ;
- il peut exposer des colonnes sensibles ajoutées plus tard ;
- le code qui dépend de l'ordre des colonnes casse le jour où la table évolue.

## Calculer et renommer

Une colonne du résultat peut être un **calcul**. L'alias `AS` lui donne un nom lisible.

```sql
SELECT titre,
       prix,
       prix * 1.2              AS prix_ttc,
       ROUND(prix / duree_heures, 2) AS prix_par_heure
FROM formations;
```

| titre | prix | prix_ttc | prix_par_heure |
|-------|------|----------|----------------|
| Java | 1200.00 | 1440.000 | 17.14 |
| SQL | 600.00 | 720.000 | 17.14 |

Quelques fonctions utiles :

| Fonction | Exemple | Résultat |
|----------|---------|----------|
| `CONCAT` | `CONCAT(prenom, ' ', nom)` | Emma Petit |
| `UPPER`, `LOWER` | `UPPER(nom)` | PETIT |
| `ROUND` | `ROUND(17.1428, 2)` | 17.14 |
| `YEAR`, `MONTH` | `YEAR(inscrit_le)` | 2026 |
| `DATEDIFF` | `DATEDIFF('2026-03-01', '2026-02-01')` | 28 |

## Filtrer avec WHERE

`WHERE` décrit la condition qu'une ligne doit remplir pour faire partie du résultat.

```sql
SELECT titre, prix
FROM formations
WHERE prix < 500
  AND duree_heures >= 20;
```

| Opérateur | Exemple | Signification |
|-----------|---------|---------------|
| `=`, `<>` | `titre <> 'Java'` | Égal, différent |
| `<`, `<=`, `>`, `>=` | `prix >= 300` | Comparaisons |
| `BETWEEN a AND b` | `prix BETWEEN 200 AND 500` | Intervalle, bornes **incluses** |
| `IN (...)` | `categorie_id IN (1, 3)` | Appartient à une liste |
| `LIKE` | `titre LIKE 'Java%'` | Correspond à un motif |
| `AND`, `OR`, `NOT` | `NOT (prix > 1000)` | Combinaisons logiques |

### Rechercher un motif avec LIKE

| Caractère | Remplace | Exemple | Trouve |
|-----------|----------|---------|--------|
| `%` | N'importe quelle suite de caractères, même vide | `'%sql%'` | « SQL », « Initiation SQL », « MySQL avancé » |
| `_` | Exactement un caractère | `'PH_'` | « PHP » |

Avec la collation par défaut de MySQL, `LIKE` ne tient pas compte de la casse : `'%sql%'` trouve aussi « SQL ».

### Attention à la priorité de AND et OR

`AND` est évalué **avant** `OR`, comme la multiplication avant l'addition. Sans parenthèses, le résultat peut surprendre.

```sql
-- Intention : formations des catégories 1 ou 2, et de moins de 500 euros
SELECT titre FROM formations
WHERE categorie_id = 1 OR categorie_id = 2 AND prix < 500;
-- Compris comme : categorie_id = 1 OR (categorie_id = 2 AND prix < 500)
-- Toutes les formations de la catégorie 1 remontent, même à 1200 euros !

-- Correct :
SELECT titre FROM formations
WHERE (categorie_id = 1 OR categorie_id = 2)
  AND prix < 500;
```

Mettez des parenthèses dès que vous mélangez `AND` et `OR`. Ici, `categorie_id IN (1, 2)` serait encore plus lisible.

## La valeur NULL

`NULL` signifie « inconnu ». Une note pas encore attribuée n'est pas zéro : elle est inconnue.

SQL applique alors une **logique à trois valeurs** : vrai, faux et **inconnu**. Toute comparaison avec `NULL` donne « inconnu », et `WHERE` ne garde que les lignes où la condition est **vraie**.

```sql
SELECT * FROM inscriptions WHERE note_finale = NULL;    -- aucune ligne, jamais
SELECT * FROM inscriptions WHERE note_finale IS NULL;   -- les inscriptions non notées
SELECT * FROM inscriptions WHERE note_finale IS NOT NULL;
```

Ce comportement a des conséquences inattendues :

```sql
-- Ne renvoie PAS les inscriptions non notées :
SELECT * FROM inscriptions WHERE note_finale < 10;
-- Ne les renvoie pas non plus :
SELECT * FROM inscriptions WHERE NOT (note_finale < 10);
```

`COALESCE` remplace un `NULL` par une valeur de repli, dans l'affichage ou dans un calcul :

```sql
SELECT apprenant_id,
       COALESCE(note_finale, 0)          AS note_calculee,
       COALESCE(ville, 'Non renseignée') AS ville
FROM inscriptions i
JOIN apprenants a ON a.id = i.apprenant_id;
```

## Trier avec ORDER BY

```sql
SELECT titre, prix
FROM formations
ORDER BY prix DESC, titre ASC;
```

- `ASC` trie par ordre croissant, c'est la valeur par défaut. `DESC` trie par ordre décroissant.
- Plusieurs critères se séparent par des virgules : on trie par prix, puis par titre à prix égal.
- On peut trier sur une colonne calculée ou sur son alias.

Sans `ORDER BY`, l'ordre des lignes n'est **pas garanti**. Il dépend de la façon dont la base a stocké et lu les données, et peut changer d'une exécution à l'autre.

## Limiter et paginer

```sql
-- Les 5 formations les plus chères
SELECT titre, prix
FROM formations
ORDER BY prix DESC
LIMIT 5;

-- Pagination : page 3 avec 20 éléments par page
SELECT titre, prix
FROM formations
ORDER BY titre, id
LIMIT 20 OFFSET 40;
```

Le calcul de l'`OFFSET` est simple : `(numéro de page - 1) × taille de page`. Pour la page 3 : `(3 - 1) × 20 = 40`.

Une pagination **sans tri** peut renvoyer la même ligne sur deux pages, ou en oublier une. Et si le tri porte sur une colonne non unique (le titre), ajoutez une colonne unique (l'id) en dernier critère pour garantir un ordre stable.

## Éliminer les doublons

```sql
SELECT DISTINCT ville
FROM apprenants
ORDER BY ville;
```

`DISTINCT` supprime les lignes identiques du résultat. Il s'applique à **l'ensemble** des colonnes sélectionnées : `SELECT DISTINCT ville, nom` supprime les couples identiques.

## L'ordre d'écriture d'une requête

```sql
SELECT    colonnes ou calculs
FROM      table
WHERE     conditions sur les lignes
ORDER BY  tri
LIMIT     nombre OFFSET décalage;
```

Cet ordre est imposé par la syntaxe. Le module suivant montrera que la base, elle, **exécute** ces clauses dans un autre ordre.

## Exemple complet

Répondons aux quatre questions du début.

```sql
-- 1. Formations de moins de 500 euros pour la campagne
SELECT titre, prix
FROM formations
WHERE prix < 500
ORDER BY prix;

-- 2. Les 5 formations les plus chères
SELECT titre, prix
FROM formations
ORDER BY prix DESC
LIMIT 5;

-- 3. Inscriptions pas encore notées, les plus anciennes d'abord
SELECT apprenant_id, formation_id, inscrit_le
FROM inscriptions
WHERE note_finale IS NULL
ORDER BY inscrit_le;

-- 4. Deuxième page du catalogue, 20 formations par page
SELECT id, titre, prix
FROM formations
ORDER BY titre, id
LIMIT 20 OFFSET 20;
```

## Les erreurs fréquentes

- **`= NULL` au lieu de `IS NULL`** : la requête ne renvoie rien et ne signale aucune erreur.
- **Oublier les parenthèses** en mélangeant `AND` et `OR`.
- **Paginer sans `ORDER BY`**, et des lignes qui sautent d'une page à l'autre.
- **`SELECT *` dans le code d'une application.**
- **Oublier que `BETWEEN` inclut ses bornes.**

## Retour au besoin

Chacune des questions de l'équipe tient maintenant en quelques lignes de SQL. La base parcourt les données, applique les filtres, trie et pagine : l'application n'a plus qu'à afficher le résultat. Il reste une limite : ces requêtes ne lisent qu'**une seule table**. Afficher le nom de la catégorie ou le prénom de l'apprenant demande de combiner les tables, avec les jointures du cours suivant.

## À retenir

- Nommez les colonnes utiles plutôt que `SELECT *`.
- `WHERE` filtre les lignes, `AND` passe avant `OR` : utilisez des parenthèses.
- On teste `NULL` avec `IS NULL`, jamais avec `=`, et une comparaison avec `NULL` n'est jamais vraie.
- Sans `ORDER BY`, l'ordre des résultats n'est pas garanti.
- `LIMIT` et `OFFSET` paginent, toujours avec un tri stable.

## Pour aller plus loin

- La documentation de MySQL sur `SELECT` : [dev.mysql.com/doc](https://dev.mysql.com/doc/refman/8.4/en/select.html)
