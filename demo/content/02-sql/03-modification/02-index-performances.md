## Objectifs

- Comprendre pourquoi une requête devient lente quand une table grossit
- Comprendre le fonctionnement d'un index
- Créer un index simple, un index unique et un index composé
- Lire un plan d'exécution avec `EXPLAIN`
- Éviter les écritures qui empêchent l'utilisation d'un index
- Reconnaître le problème N+1 côté application

## Le besoin

La plateforme a connu un grand succès : la table `inscriptions` compte maintenant **3 millions** de lignes. Depuis quelques semaines, les utilisateurs se plaignent :

- la page « Mes inscriptions » met **4 secondes** à s'afficher ;
- la recherche d'un apprenant par e-mail est lente ;
- aux heures de pointe, le serveur de base de données sature.

Les requêtes sont pourtant correctes et renvoient les bons résultats. Le problème n'est pas **ce que** la base calcule, mais **comment** elle le calcule. Pour trouver les inscriptions d'un apprenant, elle lit les 3 millions de lignes une par une. Il faut lui donner un moyen d'aller directement aux bonnes lignes : un index.

## Définitions

> **Parcours complet (full table scan).** La lecture de toutes les lignes d'une table pour trouver celles qui répondent à une condition.

> **Index.** Une structure de données annexe, triée, qui permet de retrouver rapidement les lignes correspondant à une valeur sans parcourir toute la table.

> **Plan d'exécution.** La stratégie choisie par la base pour exécuter une requête : ordre des tables, index utilisés, nombre de lignes estimé.

> **Sélectivité.** La capacité d'une colonne à distinguer les lignes. Une adresse e-mail est très sélective (une ligne par valeur), un booléen très peu (la moitié des lignes par valeur).

## L'analogie du livre

Cherchez le mot « transaction » dans un livre de 600 pages :

- **sans index**, il faut lire les 600 pages ;
- **avec l'index** en fin de livre, on cherche le mot dans une liste triée par ordre alphabétique, qui indique directement « pages 212 et 347 ».

Un index de base de données fonctionne de la même façon. C'est une copie triée d'une ou plusieurs colonnes, où chaque valeur pointe vers les lignes correspondantes.

## Comment fonctionne un index

MySQL utilise une structure appelée **arbre B+**. Sans entrer dans les détails, c'est un arbre équilibré dont chaque niveau réduit massivement l'espace de recherche, comme un annuaire où l'on choisit d'abord la bonne lettre, puis la bonne page, puis la bonne ligne.

| Nombre de lignes | Parcours complet | Recherche par index |
|------------------|------------------|---------------------|
| 1 000 | 1 000 lectures | environ 3 lectures |
| 1 000 000 | 1 000 000 lectures | environ 4 lectures |
| 1 000 000 000 | 1 000 000 000 lectures | environ 5 lectures |

Le coût d'une recherche par index grandit très lentement avec la taille de la table. C'est ce qui rend les bases de données utilisables sur des volumes énormes.

## Créer un index

```sql
CREATE INDEX idx_inscriptions_apprenant ON inscriptions (apprenant_id);
CREATE UNIQUE INDEX uk_apprenants_email ON apprenants (email);

SHOW INDEX FROM inscriptions;          -- lister les index d'une table
DROP INDEX idx_inscriptions_apprenant ON inscriptions;
```

Certains index sont créés **automatiquement** :

- la clé primaire est toujours indexée ;
- une contrainte `UNIQUE` crée un index unique ;
- avec InnoDB, une clé étrangère crée un index si aucun index utilisable n'existe déjà sur sa colonne.

## Lire un plan d'exécution avec EXPLAIN

`EXPLAIN` affiche la stratégie que la base compte suivre, **sans exécuter** la requête.

```sql
EXPLAIN
SELECT * FROM inscriptions WHERE apprenant_id = 42;
```

Avant la création de l'index :

| type | key | rows |
|------|-----|------|
| ALL | NULL | 2987451 |

Après :

| type | key | rows |
|------|-----|------|
| ref | idx_inscriptions_apprenant | 6 |

| Colonne | À surveiller |
|---------|--------------|
| `type` | `ALL` signifie un parcours complet. `range` (intervalle), `ref` (égalité sur un index), `eq_ref` et `const` (une seule ligne) indiquent l'usage d'un index |
| `key` | L'index effectivement utilisé, `NULL` si aucun |
| `rows` | Le nombre **estimé** de lignes examinées |
| `Extra` | `Using filesort` signale un tri coûteux, `Using index` une lecture faite uniquement dans l'index |

`EXPLAIN ANALYZE`, disponible depuis MySQL 8.0.18, exécute réellement la requête et affiche les temps mesurés.

## L'index composé

Un index peut porter sur **plusieurs colonnes**. Il est alors trié par la première colonne, puis par la deuxième à valeur égale de la première, comme un annuaire trié par nom puis par prénom.

```sql
CREATE INDEX idx_inscriptions_apprenant_date ON inscriptions (apprenant_id, inscrit_le);
```

L'**ordre** des colonnes est déterminant. Un annuaire trié par nom puis prénom aide à trouver « Petit Emma » ou tous les « Petit », mais pas toutes les « Emma ». C'est la **règle du préfixe gauche** :

| Condition | Index utilisable ? |
|-----------|--------------------|
| `WHERE apprenant_id = 3` | Oui, première colonne |
| `WHERE apprenant_id = 3 AND inscrit_le >= '2026-01-01'` | Oui, les deux colonnes |
| `WHERE apprenant_id = 3 ORDER BY inscrit_le` | Oui, et le tri est gratuit |
| `WHERE inscrit_le >= '2026-01-01'` | Non, la première colonne manque |

Règle pratique pour choisir l'ordre : d'abord les colonnes testées par **égalité**, ensuite celle testée par **intervalle** ou utilisée pour le **tri**.

## Les écritures qui empêchent l'usage d'un index

L'index contient les valeurs **brutes** des colonnes, triées. Dès que la condition transforme la colonne, la base ne peut plus utiliser cet ordre.

```sql
-- Une fonction appliquée à la colonne indexée
WHERE YEAR(inscrit_le) = 2026                                   -- index ignoré
WHERE inscrit_le >= '2026-01-01' AND inscrit_le < '2027-01-01'  -- index utilisé

-- Un calcul sur la colonne
WHERE prix * 1.2 > 1000        -- index ignoré
WHERE prix > 1000 / 1.2        -- index utilisé

-- Un joker en début de motif
WHERE email LIKE '%@exemple.fr'   -- index ignoré : on ne sait pas par où commencer
WHERE email LIKE 'emma%'          -- index utilisé : comme chercher les mots qui commencent par « emma »
```

Autre piège fréquent : comparer une colonne texte à un nombre (`WHERE code_postal = 75001` sur une colonne `VARCHAR`) oblige MySQL à convertir chaque valeur et l'empêche d'utiliser l'index.

## Le coût des index

Un index n'est pas gratuit :

- il occupe de l'**espace disque**, parfois autant que la table elle-même ;
- chaque `INSERT`, `UPDATE` ou `DELETE` doit aussi **mettre à jour** tous les index concernés, ce qui ralentit les écritures.

Un index sur une colonne peu sélective, comme un booléen `publiee`, sert rarement : la base préfère souvent lire toute la table plutôt que la moitié des lignes par l'index.

On indexe donc les colonnes réellement utilisées pour **filtrer**, **joindre** ou **trier** dans les requêtes **fréquentes**. La décision se prend en mesurant avec `EXPLAIN`, pas au jugé.

## Le problème N+1

Une grande partie des lenteurs ne vient pas d'une requête lente, mais d'un **trop grand nombre** de requêtes rapides. Afficher 50 apprenants avec leurs formations en lançant :

```text
1 requête   : SELECT * FROM apprenants LIMIT 50
50 requêtes : SELECT * FROM inscriptions WHERE apprenant_id = ?   (une par apprenant)
```

donne **51 requêtes**, chacune avec son aller-retour réseau. Une seule jointure, ou une requête groupée avec `WHERE apprenant_id IN (...)`, suffit. On retrouvera ce problème avec les ORM, JPA en Java et Eloquent en PHP, qui le rendent très facile à provoquer sans s'en apercevoir.

## Exemple complet

Diagnostiquons la page « Mes inscriptions ».

```sql
EXPLAIN
SELECT f.titre, i.inscrit_le, i.note_finale
FROM inscriptions i
INNER JOIN formations f ON f.id = i.formation_id
WHERE i.apprenant_id = 42
ORDER BY i.inscrit_le DESC;
```

Le plan montre `type = ALL` sur `inscriptions` et `Using filesort` : parcours complet puis tri. La requête filtre par égalité sur `apprenant_id` et trie par `inscrit_le`. L'index adapté :

```sql
CREATE INDEX idx_inscriptions_apprenant_date ON inscriptions (apprenant_id, inscrit_le);
```

Nouveau plan : `type = ref`, `key = idx_inscriptions_apprenant_date`, quelques lignes examinées et plus de `filesort`. La page passe de 4 secondes à quelques millisecondes.

## Les erreurs fréquentes

- **Indexer toutes les colonnes** par précaution, et ralentir toutes les écritures.
- **Un index composé dans le mauvais ordre**, inutilisable pour les requêtes réelles.
- **Une fonction sur une colonne indexée** dans le `WHERE`.
- **Optimiser au jugé**, sans `EXPLAIN` ni mesure.
- **Chercher la lenteur dans une requête** alors qu'elle vient du nombre de requêtes.

## Retour au besoin

Les requêtes n'ont pas changé, mais la base dispose désormais d'un chemin direct vers les lignes utiles. `EXPLAIN` a permis de trouver précisément où elle perdait du temps, et un seul index composé bien choisi a réglé la page la plus consultée. Optimiser, c'est mesurer d'abord, puis agir sur le point qui coûte réellement.

## À retenir

- Un index évite le parcours complet d'une table, et son coût de recherche grandit très lentement avec le volume.
- `EXPLAIN` montre si un index est utilisé : `type = ALL` est un signal d'alerte.
- Dans un index composé, l'ordre des colonnes compte : égalités d'abord, intervalle ou tri ensuite.
- Une fonction sur une colonne indexée ou un joker en début de `LIKE` empêche l'usage de l'index.
- Chaque index ralentit les écritures : on indexe ce que les requêtes fréquentes utilisent vraiment.

## Pour aller plus loin

- La documentation de MySQL sur l'optimisation et les index : [dev.mysql.com/doc](https://dev.mysql.com/doc/refman/8.4/en/optimization-indexes.html)
- Le site « Use The Index, Luke » qui explique les index en profondeur : [use-the-index-luke.com/fr](https://use-the-index-luke.com/fr)
