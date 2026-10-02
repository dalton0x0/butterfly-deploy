## Objectifs

- Comprendre ce qu'est une base de données relationnelle et pourquoi on l'utilise
- Connaître le vocabulaire : table, colonne, ligne, clé primaire, clé étrangère
- Choisir un type adapté à chaque colonne
- Créer des tables avec leurs contraintes en SQL
- Relier deux tables et comprendre l'intégrité référentielle

## Le besoin

Un organisme de formation gère ses inscriptions dans un tableur. Chaque ligne décrit une inscription : le nom de l'apprenant, son e-mail, le titre de la formation, son prix, la date d'inscription. Tant qu'il y a trente lignes, tout va bien. Puis l'activité grandit :

- Emma change d'adresse e-mail : il faut la corriger sur **chacune** de ses inscriptions. Une ligne oubliée et l'on ne sait plus quelle adresse est la bonne.
- Quelqu'un saisit « Jav » au lieu de « Java », ou un prix de `-50`. **Rien ne l'empêche.**
- Deux collègues modifient le fichier en même temps : l'un écrase le travail de l'autre.
- Pour savoir combien rapporte chaque formation, il faut des formules fragiles qui cassent dès qu'une colonne est déplacée.

Un tableur est un outil de calcul, pas un outil pour stocker de façon fiable des données partagées. Il nous faut un système qui :

- range chaque information **à un seul endroit** ;
- **refuse** les données incohérentes ;
- supporte **plusieurs utilisateurs** simultanés ;
- permet d'**interroger** les données de mille façons avec un langage dédié.

C'est exactement ce qu'offre une base de données relationnelle.

## Définitions

> **Base de données relationnelle.** Un ensemble de données organisées en tables reliées entre elles. Elle est gérée par un logiciel appelé SGBD (système de gestion de bases de données) : MySQL, PostgreSQL, SQL Server, Oracle.

> **Table.** Un ensemble de données de même nature, par exemple tous les apprenants. Elle ressemble à un tableau, mais sa structure est stricte.

> **Colonne.** Un attribut de la table, avec un nom et un type précis : `email`, de type texte de 100 caractères au plus.

> **Ligne (enregistrement).** Une occurrence de ce que représente la table : un apprenant précis.

> **Clé primaire.** La colonne, ou le groupe de colonnes, qui identifie chaque ligne de façon unique. Elle ne peut être ni vide ni en double.

> **Clé étrangère.** Une colonne qui contient la valeur de la clé primaire d'une autre table. Elle matérialise un lien entre deux tables.

> **SQL (Structured Query Language).** Le langage standard pour créer la structure d'une base, puis lire et modifier ses données.

## De la feuille de calcul aux tables

Au lieu d'une seule grande feuille, on sépare les informations par sujet. Chaque table ne décrit qu'**une seule chose** :

```text
apprenants                         formations
┌────┬────────┬─────────────────┐  ┌────┬────────────┬──────────┐
│ id │ prenom │ email           │  │ id │ titre      │ prix     │
├────┼────────┼─────────────────┤  ├────┼────────────┼──────────┤
│ 1  │ Emma   │ emma@exemple.fr │  │ 1  │ Java       │ 1200.00  │
│ 2  │ Lucas  │ lucas@exemple.fr│  │ 2  │ SQL        │  600.00  │
└────┴────────┴─────────────────┘  └────┴────────────┴──────────┘
```

Si Emma change d'adresse, on ne modifie qu'**une seule ligne**. Toutes ses inscriptions, qui désignent l'apprenant numéro 1, en profitent automatiquement.

## Les types de colonnes

Choisir le bon type, c'est garantir que la colonne ne contient que des valeurs sensées, et optimiser l'espace utilisé.

| Type | Contenu | Exemple |
|------|---------|---------|
| `INT` | Entier jusqu'à environ 2 milliards | Une durée en heures |
| `BIGINT` | Très grand entier | Un identifiant |
| `DECIMAL(10,2)` | Nombre décimal exact : 10 chiffres dont 2 après la virgule | Un prix, un solde |
| `VARCHAR(n)` | Texte de longueur variable, n caractères au plus | Un nom, un e-mail |
| `TEXT` | Texte long | Une description |
| `DATE` | Une date | Une date de naissance |
| `DATETIME` | Une date et une heure | Un horodatage d'inscription |
| `BOOLEAN` | Vrai ou faux, stocké en `TINYINT(1)` par MySQL | Une formation publiée ou non |

Pour de l'argent, utilisez **toujours** `DECIMAL`, jamais `FLOAT` ou `DOUBLE`. Les nombres à virgule flottante sont stockés en binaire et ne représentent pas exactement certaines valeurs décimales : `0.1 + 0.2` n'y vaut pas exactement `0.3`. Sur des milliers d'opérations, les centimes finissent par se perdre.

Pour les textes, dimensionnez `VARCHAR` selon la réalité métier : une adresse e-mail dépasse rarement 100 caractères, un code postal français en fait 5.

## Créer une table

```sql
CREATE TABLE apprenants (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    prenom      VARCHAR(50)  NOT NULL,
    nom         VARCHAR(50)  NOT NULL,
    email       VARCHAR(100) NOT NULL,
    inscrit_le  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uk_apprenants_email UNIQUE (email)
);
```

Lisons cette instruction ligne par ligne :

- `BIGINT NOT NULL AUTO_INCREMENT` : un entier obligatoire, que MySQL remplit automatiquement avec 1, 2, 3...
- `VARCHAR(50) NOT NULL` : un texte de 50 caractères au plus, obligatoire.
- `DEFAULT CURRENT_TIMESTAMP` : si aucune valeur n'est fournie, la date et l'heure courantes sont utilisées.
- `PRIMARY KEY (id)` : la colonne `id` identifie chaque apprenant.
- `CONSTRAINT uk_apprenants_email UNIQUE (email)` : deux apprenants ne peuvent pas avoir la même adresse.

## Les contraintes

Les contraintes font respecter les règles **par la base elle-même**. Peu importe l'application qui écrit dedans, une interface web, un script ou un collègue en ligne de commande : une donnée qui viole une contrainte est **refusée**.

| Contrainte | Rôle | Exemple de refus |
|------------|------|------------------|
| `PRIMARY KEY` | Identifiant unique et non nul | Deux lignes avec `id = 1` |
| `NOT NULL` | Valeur obligatoire | Un apprenant sans prénom |
| `UNIQUE` | Pas de doublon | Deux comptes avec la même adresse |
| `FOREIGN KEY` | La valeur doit exister dans la table référencée | Une formation dans une catégorie inexistante |
| `CHECK` | La valeur respecte une condition | Une durée de `-5` heures |
| `DEFAULT` | Valeur utilisée quand aucune n'est fournie | (ne refuse rien) |

```sql
INSERT INTO apprenants (prenom, nom, email) VALUES ('Emma', 'Petit', 'emma@exemple.fr');
INSERT INTO apprenants (prenom, nom, email) VALUES ('Emma', 'Durand', 'emma@exemple.fr');
```

```text
ERROR 1062 (23000): Duplicate entry 'emma@exemple.fr' for key 'apprenants.uk_apprenants_email'
```

Nommer ses contraintes (`uk_apprenants_email` plutôt qu'un nom généré comme `UK8f3a9c2e`) rend le message d'erreur immédiatement compréhensible. Un préfixe usuel : `pk_` pour une clé primaire, `fk_` pour une clé étrangère, `uk_` pour une unicité, `ck_` pour un `CHECK`.

## Relier deux tables

Une formation appartient à une catégorie. Plutôt que de répéter le nom de la catégorie dans chaque formation, la table `formations` porte une **clé étrangère** qui désigne une ligne de `categories`.

```sql
CREATE TABLE categories (
    id   BIGINT      NOT NULL AUTO_INCREMENT,
    nom  VARCHAR(50) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_categories_nom UNIQUE (nom)
);

CREATE TABLE formations (
    id            BIGINT        NOT NULL AUTO_INCREMENT,
    categorie_id  BIGINT        NOT NULL,
    titre         VARCHAR(150)  NOT NULL,
    duree_heures  INT           NOT NULL,
    prix          DECIMAL(8,2)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_formations_categorie FOREIGN KEY (categorie_id) REFERENCES categories (id),
    CONSTRAINT ck_formations_duree CHECK (duree_heures > 0),
    CONSTRAINT ck_formations_prix CHECK (prix >= 0)
);
```

```text
categories                    formations
┌────┬───────────────┐        ┌────┬──────────────┬─────────┐
│ id │ nom           │◄───────┤ id │ categorie_id │ titre   │
├────┼───────────────┤        ├────┼──────────────┼─────────┤
│ 1  │ Développement │        │ 1  │ 1            │ Java    │
│ 2  │ Données       │        │ 2  │ 2            │ SQL     │
└────┴───────────────┘        │ 3  │ 1            │ PHP     │
                              └────┴──────────────┴─────────┘
```

La clé étrangère garantit l'**intégrité référentielle** : une référence pointe toujours vers une ligne qui existe.

```sql
INSERT INTO formations (categorie_id, titre, duree_heures, prix) VALUES (99, 'Docker', 21, 450);
-- ERROR 1452 : Cannot add or update a child row: a foreign key constraint fails

DELETE FROM categories WHERE id = 1;
-- ERROR 1451 : Cannot delete or update a parent row: a foreign key constraint fails
```

Impossible de créer une formation dans une catégorie inexistante, ni de supprimer une catégorie qui contient encore des formations.

## Clé naturelle ou clé technique ?

Une **clé naturelle** vient du métier : un numéro ISBN pour un livre, une adresse e-mail pour un utilisateur. Une **clé technique** (ou clé de substitution) est un identifiant sans signification, souvent un entier auto-incrémenté.

| | Clé naturelle | Clé technique |
|---|---------------|---------------|
| Exemple | `email` | `id` auto-incrémenté |
| Peut changer ? | Oui : une personne change d'adresse | Non, jamais |
| Taille | Souvent longue | Un entier compact |
| Impact d'un changement | Toutes les clés étrangères à mettre à jour | Aucun |

On privilégie en général une **clé technique** comme clé primaire, et une contrainte `UNIQUE` sur la donnée métier. On obtient les deux garanties : un identifiant stable et l'absence de doublon métier.

## Exemple complet

L'organisme veut aussi enregistrer les formateurs. Chaque formation a un formateur responsable, un formateur a une adresse unique et un tarif horaire.

```sql
CREATE TABLE formateurs (
    id             BIGINT        NOT NULL AUTO_INCREMENT,
    prenom         VARCHAR(50)   NOT NULL,
    nom            VARCHAR(50)   NOT NULL,
    email          VARCHAR(100)  NOT NULL,
    tarif_horaire  DECIMAL(6,2)  NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_formateurs_email UNIQUE (email),
    CONSTRAINT ck_formateurs_tarif CHECK (tarif_horaire > 0)
);

ALTER TABLE formations ADD COLUMN formateur_id BIGINT NULL;
ALTER TABLE formations
    ADD CONSTRAINT fk_formations_formateur FOREIGN KEY (formateur_id) REFERENCES formateurs (id);
```

La colonne `formateur_id` accepte `NULL` : une formation peut exister avant qu'on lui attribue un formateur. Mais si elle est renseignée, elle désigne forcément un formateur existant.

## Les erreurs fréquentes

- **`FLOAT` pour un montant**, et des centimes qui disparaissent.
- **Une clé primaire métier qui change** (un e-mail), et des clés étrangères à mettre à jour partout.
- **Oublier les contraintes** en se disant que l'application vérifiera. Tôt ou tard, un script ou une autre application écrira dans la base sans passer par ces vérifications.
- **Des `VARCHAR(255)` partout** par habitude, sans réfléchir à la donnée réelle.
- **Des noms de colonnes ambigus** comme `data` ou `valeur`.

## Retour au besoin

L'adresse d'Emma n'est plus stockée qu'à un seul endroit. Les saisies incohérentes, prix négatif, formation dans une catégorie inexistante ou adresse en double, sont refusées par la base elle-même. Et plusieurs utilisateurs peuvent y travailler en même temps. Reste à apprendre comment découper correctement les informations en tables : c'est l'objet du cours suivant sur les cardinalités et la normalisation.

## À retenir

- Une table par type d'objet, une clé primaire par table.
- Le type de colonne décrit la donnée : `DECIMAL` pour l'argent, jamais `FLOAT`.
- Les contraintes protègent les données quelle que soit l'application qui écrit.
- Une clé étrangère garantit qu'une référence pointe toujours vers une ligne existante.
- Une clé technique comme clé primaire, une contrainte `UNIQUE` sur la donnée métier.

## Pour aller plus loin

- La documentation de MySQL sur `CREATE TABLE` et les types de données : [dev.mysql.com/doc](https://dev.mysql.com/doc/refman/8.4/en/)
