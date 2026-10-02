## Objectifs

- Identifier les entités, les associations et les cardinalités d'un besoin
- Traduire les relations un à un, un à plusieurs et plusieurs à plusieurs en tables
- Construire une table d'association
- Repérer la redondance et les anomalies qu'elle provoque
- Appliquer les trois premières formes normales

## Le besoin

Lors de la migration du tableur vers la base, un développeur pressé crée une seule table qui reprend exactement les colonnes du fichier :

| id | apprenant | email | formation | categorie | prix | inscrit_le |
|----|-----------|-------|-----------|-----------|------|------------|
| 1 | Emma Petit | emma@exemple.fr | Java | Développement | 1200 | 2026-01-10 |
| 2 | Emma Petit | emma@exemple.fr | SQL | Données | 600 | 2026-01-10 |
| 3 | Lucas Bernard | lucas@exemple.fr | Java | Développement | 1200 | 2026-01-12 |

Cela fonctionne en apparence. Mais très vite :

- le prix de Java augmente : il faut le modifier sur **toutes** les lignes Java. Une ligne oubliée et la formation a deux prix ;
- on crée une nouvelle formation Docker : impossible de l'enregistrer **tant que personne n'y est inscrit** ;
- Lucas se désinscrit de Java et c'était le dernier inscrit : en supprimant sa ligne, on **perd toute trace** de la formation Java et de son prix.

Le problème n'est pas SQL : c'est la **conception** du schéma. Il faut une méthode pour découper les informations en tables qui ne se répètent pas. Cette méthode repose sur deux outils : l'analyse des **cardinalités** et la **normalisation**.

## Définitions

> **Entité.** Un objet du domaine que l'on veut décrire et identifier : un apprenant, une formation, une catégorie. Elle devient généralement une table.

> **Association.** Un lien entre deux entités : un apprenant **suit** une formation, une formation **appartient à** une catégorie.

> **Cardinalité.** Le nombre minimum et maximum d'occurrences d'une entité liées à une occurrence de l'autre. Par exemple, une formation appartient à exactement une catégorie (1,1), une catégorie contient zéro ou plusieurs formations (0,n).

> **Redondance.** La répétition d'une même information à plusieurs endroits de la base.

> **Dépendance fonctionnelle.** Une colonne B dépend d'une colonne A si connaître A suffit à connaître B. Par exemple, l'identifiant d'une formation détermine son titre et son prix.

> **Normalisation.** Une démarche qui découpe les données en tables pour supprimer la redondance, en suivant des règles appelées formes normales.

## Les trois types de relations

| Relation | Exemple | Lecture |
|----------|---------|---------|
| Un à un | Un utilisateur a un profil | Un utilisateur a au plus un profil, un profil appartient à un seul utilisateur |
| Un à plusieurs | Une catégorie contient des formations | Une catégorie contient plusieurs formations, une formation appartient à une seule catégorie |
| Plusieurs à plusieurs | Des apprenants suivent des formations | Un apprenant suit plusieurs formations, une formation accueille plusieurs apprenants |

Pour déterminer le type, on se pose **deux questions**, une dans chaque sens :

1. Pour **une** catégorie, combien de formations au maximum ? Plusieurs.
2. Pour **une** formation, combien de catégories au maximum ? Une.

Réponse : un à plusieurs.

## Traduire chaque relation en tables

### Un à plusieurs : la clé étrangère du côté « plusieurs »

```text
categories (id, nom)
formations (id, categorie_id → categories.id, titre, prix)
```

C'est la formation qui porte `categorie_id`, car chaque formation n'a qu'une catégorie. L'inverse serait impossible : une catégorie ne peut pas stocker une liste de formations dans une seule colonne.

### Un à un : une clé étrangère unique

```sql
CREATE TABLE profils (
    id              BIGINT NOT NULL AUTO_INCREMENT,
    utilisateur_id  BIGINT NOT NULL,
    biographie      TEXT,
    PRIMARY KEY (id),
    CONSTRAINT uk_profils_utilisateur UNIQUE (utilisateur_id),
    CONSTRAINT fk_profils_utilisateur FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs (id)
);
```

La contrainte `UNIQUE` sur la clé étrangère transforme le « un à plusieurs » en « un à un ».

### Plusieurs à plusieurs : une table d'association

Une relation plusieurs à plusieurs ne peut pas se représenter par une simple clé étrangère : il faudrait stocker une liste de formations dans chaque apprenant. On crée une **table d'association** qui porte les deux clés étrangères.

```sql
CREATE TABLE inscriptions (
    apprenant_id  BIGINT        NOT NULL,
    formation_id  BIGINT        NOT NULL,
    inscrit_le    DATE          NOT NULL,
    note_finale   DECIMAL(4,2),
    PRIMARY KEY (apprenant_id, formation_id),
    CONSTRAINT fk_inscriptions_apprenant FOREIGN KEY (apprenant_id) REFERENCES apprenants (id),
    CONSTRAINT fk_inscriptions_formation FOREIGN KEY (formation_id) REFERENCES formations (id)
);
```

```text
apprenants            inscriptions                    formations
┌────┬───────┐        ┌──────────────┬──────────────┐  ┌────┬───────┐
│ id │ prenom│◄───────┤ apprenant_id │ formation_id ├─►│ id │ titre │
├────┼───────┤        ├──────────────┼──────────────┤  ├────┼───────┤
│ 1  │ Emma  │        │ 1            │ 1            │  │ 1  │ Java  │
│ 2  │ Lucas │        │ 1            │ 2            │  │ 2  │ SQL   │
└────┴───────┘        │ 2            │ 1            │  └────┴───────┘
                      └──────────────┴──────────────┘
```

Deux points importants :

- La **clé primaire composée** `(apprenant_id, formation_id)` interdit d'inscrire deux fois le même apprenant à la même formation.
- La table porte les informations **propres à la relation**. La date d'inscription et la note finale n'appartiennent ni à l'apprenant (il a une note par formation) ni à la formation (elle a une note par apprenant), mais à leur **lien**.

## La redondance et ses anomalies

Revenons à la table unique du début. Elle provoque trois types d'anomalies :

| Anomalie | Situation | Conséquence |
|----------|-----------|-------------|
| De mise à jour | Le prix de Java change | Plusieurs lignes à modifier, risque d'incohérence |
| D'insertion | Nouvelle formation sans inscrit | Impossible de l'enregistrer |
| De suppression | Désinscription du dernier inscrit | Perte des informations de la formation |

Toutes ont la même cause : une même information (le prix de Java) est stockée à **plusieurs endroits**. La normalisation élimine ces répétitions.

## Les formes normales

### Première forme normale (1FN) : des valeurs atomiques

Chaque colonne contient **une seule valeur**, indivisible. Pas de liste, pas de groupe répété.

```text
Violation :   apprenants (id, nom, telephones)
              1, Emma, "0601020304, 0702030405"

Correction :  apprenants (id, nom)
              telephones (id, apprenant_id, numero)
```

Avec la liste dans une colonne, impossible de chercher proprement un numéro, d'en supprimer un seul ou de vérifier son format.

### Deuxième forme normale (2FN) : dépendre de toute la clé

Être en 1FN, et chaque colonne non clé dépend de **toute** la clé primaire, pas d'une partie seulement. Cette règle ne concerne que les clés primaires composées.

```text
Violation :   inscriptions (apprenant_id, formation_id, inscrit_le, titre_formation)
```

`titre_formation` ne dépend que de `formation_id`, pas du couple complet. Il est répété dans chaque inscription à la même formation. Il doit rester dans la table `formations`.

### Troisième forme normale (3FN) : ne dépendre que de la clé

Être en 2FN, et aucune colonne non clé ne dépend d'une **autre colonne non clé**.

```text
Violation :   formations (id, titre, categorie_id, nom_categorie)
```

`nom_categorie` dépend de `categorie_id`, qui n'est pas la clé de `formations`. Il est répété pour chaque formation de la catégorie. Il doit rester dans la table `categories`.

Un moyen mnémotechnique résume les trois formes : chaque colonne doit dépendre **de la clé, de toute la clé et de rien d'autre que la clé**.

## Du besoin au schéma : la méthode

1. **Lire le besoin** et souligner les noms communs importants : ce sont les candidats entités.
2. **Lister les attributs** de chaque entité et choisir son identifiant.
3. **Identifier les associations** : les verbes du besoin (« suit », « appartient à », « anime »).
4. **Déterminer les cardinalités** en posant la question dans les deux sens.
5. **Traduire en tables** : une table par entité, une clé étrangère par relation un à plusieurs, une table d'association par relation plusieurs à plusieurs.
6. **Vérifier la normalisation** : pas de liste dans une colonne, pas d'information répétée.

## Exemple complet

Reprenons la table unique du début et normalisons-la.

```text
Avant (une seule table) :
inscriptions_brutes (id, apprenant, email, formation, categorie, prix, inscrit_le)

Après :
categories   (id, nom)
formations  (id, categorie_id → categories, titre, prix)
apprenants  (id, prenom, nom, email)
inscriptions (apprenant_id → apprenants, formation_id → formations, inscrit_le)
```

Vérifions que les anomalies ont disparu :

- **Le prix de Java change** : une seule ligne à modifier dans `formations`.
- **Nouvelle formation Docker** : on l'insère dans `formations`, sans inscription.
- **Dernière désinscription de Java** : on supprime une ligne d'`inscriptions`, la formation reste intacte.

## Dénormaliser, avec raison

Une base en 3FN est le bon point de départ. Il arrive que l'on **dénormalise** volontairement pour des raisons de performance, par exemple en stockant le nombre d'inscrits d'une formation pour éviter de le recompter à chaque affichage. Ce choix doit rester l'exception, être justifié par une mesure réelle et s'accompagner d'un mécanisme qui garde la valeur synchronisée.

## Les erreurs fréquentes

- **Mettre la clé étrangère du mauvais côté** d'une relation un à plusieurs.
- **Stocker une liste dans une colonne** (« 1,4,7 ») au lieu de créer une table d'association.
- **Oublier les attributs de la relation**, et placer la note finale dans la table des apprenants.
- **Recopier un libellé** (nom de catégorie, titre de formation) au lieu de le référencer par sa clé.
- **Dénormaliser par anticipation**, sans problème de performance mesuré.

## Retour au besoin

La table unique mélangeait apprenants, formations et catégories. Découpée selon les cardinalités et normalisée, chaque information n'est plus stockée qu'une fois. Un changement de prix touche une ligne, une formation existe sans inscrit et une désinscription ne détruit plus rien. La base est devenue fiable parce que sa structure reflète fidèlement le domaine.

## À retenir

- Pour trouver une cardinalité, on pose la question dans les deux sens.
- Un à plusieurs : la clé étrangère va du côté « plusieurs ».
- Plusieurs à plusieurs : une table d'association avec deux clés étrangères, qui porte aussi les données de la relation.
- La redondance provoque des anomalies de mise à jour, d'insertion et de suppression.
- La 3FN est l'objectif par défaut : chaque colonne dépend de la clé, de toute la clé et de rien d'autre que la clé.

## Pour aller plus loin

- La méthode Merise et le modèle conceptuel de données (MCD), très utilisés en France pour la conception de bases de données.
- L'outil de modélisation gratuit Looping, conçu pour Merise : [looping-mcd.fr](https://www.looping-mcd.fr/)
