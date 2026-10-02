## Objectifs

- Calculer des indicateurs avec les fonctions d'agrégation
- Regrouper des lignes avec `GROUP BY`
- Filtrer des groupes avec `HAVING`
- Comprendre l'ordre réel d'exécution d'une requête
- Utiliser une sous-requête et `EXISTS`

## Le besoin

La direction pédagogique prépare son bilan trimestriel. Elle veut des **chiffres**, pas des listes :

- le **nombre** total d'inscriptions et la **moyenne** générale des notes ;
- le **chiffre d'affaires** par catégorie ;
- le **nombre d'inscrits** par formation ;
- les apprenants dont la **moyenne** dépasse 14 sur au moins deux formations ;
- les formations **plus chères que la moyenne**.

Les requêtes vues jusqu'ici renvoient une ligne par enregistrement. Ici, il faut **résumer** des centaines de lignes en quelques valeurs, globalement ou groupe par groupe. C'est le rôle des fonctions d'agrégation et de `GROUP BY`.

## Définitions

> **Fonction d'agrégation.** Une fonction qui prend un ensemble de lignes et renvoie une seule valeur : un nombre, une somme, une moyenne, un minimum ou un maximum.

> **Regroupement (GROUP BY).** Le découpage des lignes en groupes qui partagent la même valeur sur une ou plusieurs colonnes. L'agrégation est alors calculée pour chaque groupe.

> **HAVING.** Une clause qui filtre les groupes, après le calcul des agrégats.

> **Sous-requête.** Une requête `SELECT` placée à l'intérieur d'une autre requête.

Les résultats affichés dans ce cours correspondent au jeu de données de l'exercice « Explorer une base de formations ». Vous pouvez donc rejouer chaque requête et comparer.

## Les fonctions d'agrégation

| Fonction | Résultat |
|----------|----------|
| `COUNT(*)` | Nombre de lignes |
| `COUNT(colonne)` | Nombre de valeurs **non `NULL`** de la colonne |
| `COUNT(DISTINCT colonne)` | Nombre de valeurs différentes |
| `SUM(colonne)` | Somme |
| `AVG(colonne)` | Moyenne, en ignorant les `NULL` |
| `MIN(colonne)`, `MAX(colonne)` | Plus petite et plus grande valeur |

```sql
SELECT COUNT(*)                     AS nombre_inscriptions,
       COUNT(note_finale)           AS inscriptions_notees,
       COUNT(DISTINCT apprenant_id) AS apprenants_differents,
       ROUND(AVG(note_finale), 2)   AS moyenne,
       MIN(note_finale)             AS note_min,
       MAX(note_finale)             AS note_max
FROM inscriptions;
```

| nombre_inscriptions | inscriptions_notees | apprenants_differents | moyenne | note_min | note_max |
|---------------------|---------------------|-----------------------|---------|----------|----------|
| 11 | 9 | 5 | 12.94 | 8.00 | 17.50 |

La différence entre `COUNT(*)` et `COUNT(note_finale)` est essentielle : la première compte toutes les inscriptions, la seconde seulement celles qui ont une note.

`AVG` ignore les `NULL` : une inscription non notée ne fait pas baisser la moyenne. C'est généralement ce que l'on veut. Pour compter une absence de note comme un zéro, il faudrait écrire `AVG(COALESCE(note_finale, 0))`.

## Regrouper avec GROUP BY

Sans `GROUP BY`, une fonction d'agrégation résume **toute** la table en une seule ligne. Avec `GROUP BY`, elle calcule une valeur **par groupe**.

Prenons le nombre de formations par catégorie :

```text
Lignes de formations           Groupes formés            Résultat
Java      Développement  ─┐
PHP       Développement  ─┼──► Développement (3)  ──►  Développement | 3
Spring    Développement  ─┘
SQL       Données        ─┬──► Données (2)        ──►  Données       | 2
Analyse   Données        ─┘
Docker    Infrastructure ─┐
Linux     Infrastructure ─┼──► Infrastructure (3) ──►  Infrastructure | 3
Kubernetes Infrastructure┘
```

```sql
SELECT c.nom                  AS categorie,
       COUNT(*)               AS nombre_formations,
       ROUND(AVG(f.prix), 2)  AS prix_moyen,
       MAX(f.prix)            AS prix_max
FROM formations f
INNER JOIN categories c ON c.id = f.categorie_id
GROUP BY c.id, c.nom
ORDER BY nombre_formations DESC;
```

**La règle d'or de `GROUP BY`** : chaque colonne du `SELECT` doit soit figurer dans le `GROUP BY`, soit être à l'intérieur d'une fonction d'agrégation.

```sql
-- Refusé : quel titre afficher pour un groupe qui contient trois formations ?
SELECT c.nom, f.titre, COUNT(*)
FROM formations f
INNER JOIN categories c ON c.id = f.categorie_id
GROUP BY c.nom;
```

MySQL 8 refuse cette requête par défaut, grâce au mode `ONLY_FULL_GROUP_BY`. D'anciennes versions l'acceptaient et renvoyaient un titre choisi au hasard, source de bugs silencieux.

## Filtrer les groupes avec HAVING

`WHERE` et `HAVING` filtrent tous les deux, mais pas au même moment :

| Clause | Filtre | Moment | Peut utiliser un agrégat ? |
|--------|--------|--------|----------------------------|
| `WHERE` | Les **lignes** | Avant le regroupement | Non |
| `HAVING` | Les **groupes** | Après le calcul des agrégats | Oui |

```sql
-- Apprenants ayant une moyenne d'au moins 14 sur au moins deux formations notées
SELECT a.prenom,
       a.nom,
       COUNT(i.note_finale)        AS formations_notees,
       ROUND(AVG(i.note_finale), 2) AS moyenne
FROM apprenants a
INNER JOIN inscriptions i ON i.apprenant_id = a.id
WHERE i.note_finale IS NOT NULL
GROUP BY a.id, a.prenom, a.nom
HAVING COUNT(i.note_finale) >= 2
   AND AVG(i.note_finale) >= 14;
```

| prenom | nom | formations_notees | moyenne |
|--------|-----|-------------------|---------|
| Emma | Petit | 2 | 15.25 |
| Nina | Robert | 2 | 16.25 |

Le `WHERE` écarte d'abord les inscriptions non notées. Le `GROUP BY` forme un groupe par apprenant. Le `HAVING` ne garde que les groupes qui remplissent les deux conditions.

## L'ordre réel d'exécution

L'ordre dans lequel la base **exécute** une requête n'est pas celui dans lequel on l'**écrit** :

| Ordre | Clause | Rôle |
|-------|--------|------|
| 1 | `FROM` et `JOIN` | Assemble les tables |
| 2 | `WHERE` | Filtre les lignes |
| 3 | `GROUP BY` | Forme les groupes |
| 4 | `HAVING` | Filtre les groupes |
| 5 | `SELECT` | Calcule les colonnes du résultat et leurs alias |
| 6 | `ORDER BY` | Trie |
| 7 | `LIMIT` | Limite |

Cet ordre explique beaucoup de messages d'erreur :

- Un alias défini dans le `SELECT` ne peut pas être utilisé dans le `WHERE` : au moment du filtrage, il n'existe pas encore.
- Un agrégat ne peut pas être utilisé dans le `WHERE` : les groupes ne sont pas encore formés.
- En revanche, `ORDER BY` peut utiliser un alias : il est exécuté après le `SELECT`.

## Les sous-requêtes

Une sous-requête calcule une valeur ou une liste utilisée par la requête principale.

### Sous-requête qui renvoie une valeur

```sql
-- Formations plus chères que la moyenne
SELECT titre, prix
FROM formations
WHERE prix > (SELECT AVG(prix) FROM formations);
```

La sous-requête entre parenthèses est calculée d'abord et renvoie une seule valeur, ici 800 sur la base d'exemple. La requête principale compare chaque prix à cette valeur.

### Sous-requête qui renvoie une liste

```sql
-- Apprenants inscrits à au moins une formation de la catégorie Données
SELECT prenom, nom
FROM apprenants
WHERE id IN (
    SELECT i.apprenant_id
    FROM inscriptions i
    INNER JOIN formations f ON f.id = i.formation_id
    WHERE f.categorie_id = 2
);
```

### EXISTS

`EXISTS` teste simplement la présence d'**au moins une** ligne. Il est souvent plus lisible que `IN` pour exprimer « qui a au moins un... ». La sous-requête fait référence à la ligne courante de la requête principale : on parle de sous-requête **corrélée**.

```sql
-- Apprenants ayant au moins une note inférieure à 10
SELECT a.prenom, a.nom
FROM apprenants a
WHERE EXISTS (
    SELECT 1
    FROM inscriptions i
    WHERE i.apprenant_id = a.id
      AND i.note_finale < 10
);
```

`SELECT 1` est une convention : seule compte l'existence d'une ligne, pas son contenu.

## Exemple complet

Le chiffre d'affaires par catégorie, en comptant le prix de la formation pour chaque inscription, avec les catégories sans aucune inscription :

```sql
SELECT c.nom                            AS categorie,
       COUNT(i.formation_id)            AS inscriptions,
       COALESCE(SUM(f.prix), 0)         AS chiffre_affaires
FROM categories c
LEFT JOIN formations f   ON f.categorie_id = c.id
LEFT JOIN inscriptions i ON i.formation_id = f.id
GROUP BY c.id, c.nom
ORDER BY chiffre_affaires DESC;
```

Plusieurs points de ce cours se combinent :

- les `LEFT JOIN` gardent les catégories et formations sans inscription ;
- `COUNT(i.formation_id)` ne compte que les inscriptions réelles, alors que `COUNT(*)` compterait aussi les lignes complétées par `NULL` ;
- attention : `SUM(f.prix)` additionne aussi le prix des formations **sans** inscrit, car la ligne de la formation existe dans le résultat de la jointure. Sur la base d'exemple, la catégorie Infrastructure affiche 1 750 € au lieu de 850 €, à cause de Kubernetes qui n'a aucun inscrit. Pour un chiffre d'affaires juste, on écrit plutôt `SUM(CASE WHEN i.formation_id IS NOT NULL THEN f.prix ELSE 0 END)`.

Ce dernier piège montre qu'il faut toujours vérifier un agrégat sur un petit jeu de données dont on connaît le résultat.

## Les erreurs fréquentes

- **Une colonne dans le `SELECT` ni groupée ni agrégée.**
- **Un agrégat dans le `WHERE`** au lieu du `HAVING`.
- **`COUNT(*)` après un `LEFT JOIN`**, qui compte 1 au lieu de 0 pour les lignes sans correspondance.
- **Oublier que `AVG` ignore les `NULL`**, et comparer des moyennes calculées sur des bases différentes.
- **Sommer une colonne dupliquée par une jointure**, et obtenir un total gonflé.

## Retour au besoin

Chaque indicateur du bilan trimestriel tient en une requête : un total, une moyenne, un regroupement par catégorie, un filtre sur des groupes ou une comparaison avec une moyenne. La base résume elle-même des milliers de lignes, plus vite et plus sûrement qu'un calcul fait dans l'application.

## À retenir

- Les fonctions d'agrégation résument plusieurs lignes en une valeur, `COUNT(colonne)` et `AVG` ignorent les `NULL`.
- Toute colonne du `SELECT` est groupée ou agrégée.
- `WHERE` filtre les lignes avant le regroupement, `HAVING` filtre les groupes après.
- L'ordre d'exécution (`FROM`, `WHERE`, `GROUP BY`, `HAVING`, `SELECT`, `ORDER BY`, `LIMIT`) explique où chaque alias et chaque agrégat est utilisable.
- Une sous-requête compare une valeur à un résultat calculé à part, `EXISTS` teste la présence d'une ligne.

## Pour aller plus loin

- La documentation de MySQL sur les fonctions d'agrégation : [dev.mysql.com/doc](https://dev.mysql.com/doc/refman/8.4/en/aggregate-functions.html)
