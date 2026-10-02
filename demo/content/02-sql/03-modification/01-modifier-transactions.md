## Objectifs

- Insérer, modifier et supprimer des lignes en SQL
- Adopter les réflexes qui évitent les modifications massives accidentelles
- Choisir le comportement d'une clé étrangère à la suppression
- Comprendre la suppression logique
- Garantir la cohérence des données avec les transactions et les propriétés ACID

## Le besoin

Lire les données ne suffit pas : l'application doit aussi en créer et en modifier. Deux situations montrent que ce n'est pas anodin.

**Le lundi matin**, un stagiaire doit augmenter de 5 % le prix d'une formation. Il écrit :

```sql
UPDATE formations SET prix = prix * 1.05;
```

Il a oublié la condition. **Toutes** les formations viennent d'augmenter. Et personne ne sait plus quels étaient les anciens prix.

**Le mardi**, un apprenant change de formation. L'application doit faire deux opérations : supprimer son inscription à Linux, puis l'inscrire à Kubernetes. Entre les deux, le serveur redémarre. L'apprenant se retrouve **inscrit nulle part**, alors qu'il a payé.

Il faut donc deux choses : des **réflexes de sécurité** pour écrire des modifications sans risque, et un mécanisme qui garantit qu'un **groupe d'opérations** s'applique entièrement ou pas du tout. Ce mécanisme, c'est la transaction.

## Définitions

> **LMD (langage de manipulation des données).** La partie de SQL qui modifie le contenu des tables : `INSERT`, `UPDATE` et `DELETE`.

> **Transaction.** Un groupe d'opérations traité comme une unité indivisible : soit toutes sont appliquées, soit aucune.

> **Validation (COMMIT).** L'instruction qui rend définitives les modifications d'une transaction.

> **Annulation (ROLLBACK).** L'instruction qui annule toutes les modifications d'une transaction en cours.

> **Suppression logique (soft delete).** Marquer une ligne comme supprimée, par exemple avec une date dans une colonne `deleted_at`, au lieu de l'effacer réellement.

## Insérer : INSERT

```sql
INSERT INTO apprenants (prenom, nom, email)
VALUES ('Nina', 'Robert', 'nina.robert@exemple.fr');

-- Plusieurs lignes en une seule requête
INSERT INTO categories (nom)
VALUES ('Sécurité'), ('Cloud'), ('Design');
```

Listez **toujours** les colonnes. Une insertion qui s'appuie sur l'ordre des colonnes de la table (`INSERT INTO apprenants VALUES (...)`) casse, ou pire, range les valeurs dans les mauvaises colonnes, le jour où la structure évolue.

Les colonnes omises prennent leur valeur par défaut, ou `NULL` si elles l'acceptent. Une colonne `NOT NULL` sans valeur par défaut provoque une erreur.

On peut aussi insérer le résultat d'une requête :

```sql
INSERT INTO archives_inscriptions (apprenant_id, formation_id, inscrit_le)
SELECT apprenant_id, formation_id, inscrit_le
FROM inscriptions
WHERE inscrit_le < '2025-01-01';
```

## Modifier : UPDATE

```sql
UPDATE formations
SET prix = prix * 1.05,
    duree_heures = 75
WHERE id = 1;
```

Un `UPDATE` **sans `WHERE`** modifie toutes les lignes de la table. C'est l'une des erreurs les plus coûteuses en production, comme notre stagiaire l'a découvert.

Le réflexe qui protège : écrire d'abord un `SELECT` avec **exactement le même `WHERE`**, vérifier les lignes ciblées et leur nombre, puis transformer la requête en `UPDATE`.

```sql
-- 1. Vérifier : quelles lignes vont changer ?
SELECT id, titre, prix, ROUND(prix * 1.05, 2) AS nouveau_prix
FROM formations
WHERE categorie_id = 1;

-- 2. Modifier, avec le même WHERE
UPDATE formations
SET prix = ROUND(prix * 1.05, 2)
WHERE categorie_id = 1;
```

MySQL indique ensuite le nombre de lignes touchées (`3 rows affected`). Comparez-le à ce que le `SELECT` avait annoncé.

Certains clients SQL, comme MySQL Workbench, activent par défaut un **mode sûr** (`sql_safe_updates`) qui refuse un `UPDATE` ou un `DELETE` sans condition sur une clé. C'est un bon garde-fou.

## Supprimer : DELETE

```sql
DELETE FROM inscriptions
WHERE apprenant_id = 4
  AND formation_id = 7;
```

Mêmes règles que pour `UPDATE` : un `SELECT` de vérification avant, et jamais sans `WHERE`. Pour vider entièrement une table de test, `TRUNCATE TABLE` est plus rapide, mais il ne se limite pas avec une condition et ne s'annule pas avec un `ROLLBACK`.

## Clés étrangères et suppression

Par défaut, une clé étrangère **refuse** la suppression d'une ligne encore référencée. On peut choisir un autre comportement à la création de la contrainte :

| Option | Effet à la suppression du parent | Exemple adapté |
|--------|----------------------------------|----------------|
| `ON DELETE RESTRICT` (défaut) | Suppression refusée tant que des enfants existent | Une catégorie qui contient des formations |
| `ON DELETE CASCADE` | Les enfants sont supprimés avec le parent | Les lignes d'une commande supprimée |
| `ON DELETE SET NULL` | La clé étrangère des enfants passe à `NULL` | Une formation dont le formateur quitte l'organisme |

```sql
CONSTRAINT fk_inscriptions_formation
    FOREIGN KEY (formation_id) REFERENCES formations (id)
    ON DELETE CASCADE
```

`CASCADE` est pratique mais dangereux : une seule suppression peut effacer des milliers de lignes en chaîne, sans message. Réservez-le aux données qui n'ont **aucun sens** sans leur parent.

## La suppression logique

Beaucoup d'applications ne suppriment jamais réellement certaines données :

```sql
ALTER TABLE apprenants ADD COLUMN deleted_at DATETIME NULL;

-- « Supprimer » un apprenant
UPDATE apprenants SET deleted_at = NOW() WHERE id = 4;

-- Les requêtes courantes ignorent les lignes supprimées
SELECT prenom, nom FROM apprenants WHERE deleted_at IS NULL;
```

| Avantages | Contreparties |
|-----------|---------------|
| Les données rattachées (inscriptions, notes) sont préservées | Chaque requête doit filtrer `deleted_at IS NULL` |
| Une restauration reste possible | Les contraintes `UNIQUE` voient encore les lignes supprimées |
| L'historique reste consultable | La table grossit indéfiniment |

Le choix dépend du métier. Des obligations comme le RGPD peuvent aussi imposer une suppression réelle des données personnelles.

## Les transactions

Revenons au changement de formation. Les deux opérations doivent former **une seule unité** :

```sql
START TRANSACTION;

DELETE FROM inscriptions
WHERE apprenant_id = 4 AND formation_id = 7;

INSERT INTO inscriptions (apprenant_id, formation_id, inscrit_le)
VALUES (4, 8, CURDATE());

COMMIT;
```

Tant que le `COMMIT` n'a pas eu lieu, rien n'est définitif. Si le serveur s'arrête au milieu, la base annule automatiquement la transaction inachevée au redémarrage : l'apprenant garde son ancienne inscription.

En cas de problème détecté, `ROLLBACK` annule tout ce qui a été fait depuis `START TRANSACTION` :

```sql
START TRANSACTION;
DELETE FROM inscriptions WHERE formation_id = 3;
-- Vérification : 42 lignes supprimées au lieu des 2 attendues
ROLLBACK;
-- Les 42 inscriptions sont revenues
```

C'est aussi un excellent filet de sécurité pour une modification manuelle en production : on ouvre une transaction, on modifie, on vérifie avec un `SELECT`, et on valide ou on annule.

Par défaut, MySQL est en mode **autocommit** : chaque instruction isolée est sa propre transaction, validée immédiatement. `START TRANSACTION` suspend ce mode jusqu'au `COMMIT` ou au `ROLLBACK`.

## Les propriétés ACID

Une base transactionnelle garantit quatre propriétés, résumées par l'acronyme ACID :

| Propriété | Garantie | Dans notre exemple |
|-----------|----------|--------------------|
| **A**tomicité | Tout ou rien | La désinscription et l'inscription ont lieu ensemble ou pas du tout |
| **C**ohérence | La base passe d'un état valide à un autre, contraintes respectées | Une inscription vers une formation inexistante fait échouer la transaction |
| **I**solation | Les transactions simultanées ne se perturbent pas | Un autre utilisateur ne voit pas l'état intermédiaire « inscrit nulle part » |
| **D**urabilité | Une transaction validée survit à une panne | Après le `COMMIT`, le changement ne peut plus être perdu |

Avec MySQL, ces garanties sont fournies par le moteur de stockage **InnoDB**, utilisé par défaut.

## Dans une application

Dans une application, on écrit rarement `START TRANSACTION` à la main. Les frameworks s'en chargent :

- en Spring, l'annotation `@Transactional` sur une méthode de service ;
- en Laravel, `DB::transaction(function () { ... })`.

Le principe est le même : si le code se termine normalement, la transaction est validée. Si une exception survient, elle est annulée.

## Exemple complet

Le changement de prix du lundi, fait correctement cette fois :

```sql
START TRANSACTION;

-- 1. Vérifier les lignes ciblées
SELECT id, titre, prix
FROM formations
WHERE id = 1;
-- 1 ligne : Java, 1200.00

-- 2. Modifier
UPDATE formations
SET prix = ROUND(prix * 1.05, 2)
WHERE id = 1;
-- 1 row affected

-- 3. Contrôler le résultat
SELECT id, titre, prix FROM formations WHERE id = 1;
-- Java, 1260.00

COMMIT;
```

Si l'étape 2 avait annoncé 8 lignes au lieu d'une, un `ROLLBACK` aurait tout annulé.

## Les erreurs fréquentes

- **`UPDATE` ou `DELETE` sans `WHERE`.**
- **Un `INSERT` sans liste de colonnes.**
- **Des opérations liées exécutées sans transaction**, qui laissent la base dans un état incohérent en cas d'erreur.
- **`ON DELETE CASCADE` par facilité**, et des suppressions en chaîne inattendues.
- **Oublier le `COMMIT`** dans un client SQL, et des modifications qui disparaissent à la déconnexion.

## Retour au besoin

Le stagiaire a désormais deux réflexes : un `SELECT` de vérification avant chaque modification et une transaction qui permet d'annuler. Le changement de formation ne peut plus laisser un apprenant inscrit nulle part : la transaction garantit que les deux opérations réussissent ensemble ou échouent ensemble. La base ne se contente plus de stocker des données, elle protège leur cohérence.

## À retenir

- Listez les colonnes dans un `INSERT`.
- Un `SELECT` avec le même `WHERE` avant chaque `UPDATE` ou `DELETE`, et jamais sans `WHERE`.
- Une transaction applique tout ou rien : `COMMIT` valide, `ROLLBACK` annule.
- ACID : atomicité, cohérence, isolation, durabilité.
- `ON DELETE CASCADE` est puissant et dangereux, la suppression logique préserve l'historique.

## Pour aller plus loin

- La documentation de MySQL sur les transactions : [dev.mysql.com/doc](https://dev.mysql.com/doc/refman/8.4/en/commit.html)
