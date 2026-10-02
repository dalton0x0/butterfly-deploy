## Objectifs

- Comprendre le décalage entre objets et tables et le rôle d'un ORM
- Distinguer JPA, Hibernate et Spring Data JPA
- Mapper une classe sur une table avec `@Entity` et les annotations de colonnes
- Gérer le schéma avec des migrations Flyway et Hibernate en `validate`
- Décrire les relations entre entités et choisir leur côté propriétaire
- Choisir le mode de chargement des relations et comprendre le contexte de persistance

## Le besoin

L'API de formations stocke ses données en mémoire : au moindre redémarrage, tout disparaît. Il faut une base MySQL. Avec JDBC, l'accès bas niveau de Java, chaque lecture ressemble à ceci :

```java
String sql = "SELECT f.id, f.titre, f.prix, c.id, c.nom FROM formations f JOIN categories c ON c.id = f.categorie_id WHERE f.id = ?";
try (Connection connexion = dataSource.getConnection();
     PreparedStatement requete = connexion.prepareStatement(sql)) {
    requete.setLong(1, id);
    try (ResultSet resultat = requete.executeQuery()) {
        if (resultat.next()) {
            Formation formation = new Formation();
            formation.setId(resultat.getLong(1));
            formation.setTitre(resultat.getString(2));
            formation.setPrix(resultat.getBigDecimal(3));
            Categorie categorie = new Categorie();
            categorie.setId(resultat.getLong(4));
            // ... et ainsi de suite, colonne par colonne
        }
    }
}
```

Pour chaque classe et chaque requête, il faut écrire le SQL, lire chaque colonne, reconstruire les objets et leurs relations à la main. C'est long, répétitif et source d'erreurs : une colonne ajoutée à la table oblige à modifier toutes les requêtes concernées.

Le fond du problème est un **décalage** entre deux mondes : Java manipule des **objets** reliés par des références, la base stocke des **lignes** reliées par des clés étrangères. Un outil qui fait automatiquement la traduction entre les deux s'appelle un ORM.

## Définitions

> **ORM (Object-Relational Mapping).** Un outil qui fait correspondre des classes à des tables et des objets à des lignes. Il génère le SQL et reconstruit les objets automatiquement.

> **JPA (Jakarta Persistence API).** La spécification standard de Java pour la persistance : un ensemble d'annotations et d'interfaces.

> **Hibernate.** L'implémentation de JPA la plus répandue, utilisée par défaut par Spring Boot. C'est elle qui génère et exécute le SQL.

> **Spring Data JPA.** Une surcouche qui génère automatiquement les classes d'accès aux données (les repositories) à partir de simples interfaces.

> **Entité.** Une classe dont les instances sont persistées en base, marquée `@Entity`.

> **Mapping.** La correspondance décrite entre une classe et une table, un attribut et une colonne.

> **Contexte de persistance.** L'ensemble des entités chargées et suivies par Hibernate pendant une transaction.

## Les trois niveaux

```text
Votre code (services)
        │  formationRepository.findById(1)
┌───────▼──────────┐
│  Spring Data JPA │  génère l'implémentation du repository
└───────┬──────────┘
┌───────▼──────────┐
│  JPA (standard)  │  annotations @Entity, @Id, @ManyToOne...
│  Hibernate       │  génère : SELECT ... FROM formations WHERE id = ?
└───────┬──────────┘
┌───────▼──────────┐
│  JDBC + MySQL    │
└──────────────────┘
```

Le starter `spring-boot-starter-data-jpa` et le pilote `mysql-connector-j` suffisent pour démarrer.

## Une entité

```java
@Entity
@Table(name = "formations")
@Getter
@Setter
@NoArgsConstructor
public class Formation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150, unique = true)
    private String titre;

    @Column(name = "duree_heures", nullable = false)
    private Integer dureeHeures;

    @Column(nullable = false, precision = 8, scale = 2)
    private BigDecimal prix;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Niveau niveau;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;
}
```

| Annotation | Rôle |
|------------|------|
| `@Entity` | La classe est persistante |
| `@Table(name = "formations")` | Nom de la table, sinon celui de la classe |
| `@Id` | L'attribut qui correspond à la clé primaire |
| `@GeneratedValue(IDENTITY)` | L'identifiant est attribué par la base, avec `AUTO_INCREMENT` |
| `@Column` | Nom, longueur, nullabilité, précision de la colonne |
| `@Enumerated(STRING)` | Stocke le **nom** de l'énumération et non sa position |

Par défaut, Spring Boot traduit les noms en **snake_case** : l'attribut `dureeHeures` correspond à la colonne `duree_heures`, même sans `@Column(name = ...)`.

Quelques règles importantes :

- **Toujours `EnumType.STRING`.** Avec la valeur par défaut `ORDINAL`, la base stocke la **position** du cas : 0, 1, 2. Ajouter un cas au milieu de l'énumération décale silencieusement toutes les données existantes.
- **Un constructeur sans argument** est exigé par JPA : Hibernate l'utilise pour créer les objets avant de les remplir.
- **Pas de `@Data` de Lombok** sur une entité : son `equals`, son `hashCode` et son `toString` parcourent les relations, et provoquent des chargements inattendus, voire des boucles infinies.
- **`BigDecimal`** pour les montants, comme `DECIMAL` en SQL.

## Qui crée le schéma ?

La propriété `spring.jpa.hibernate.ddl-auto` indique à Hibernate quoi faire du schéma au démarrage :

| Valeur | Effet | Usage |
|--------|-------|-------|
| `create-drop` | Crée le schéma au démarrage, le supprime à l'arrêt | Tests |
| `update` | Ajoute les tables et colonnes manquantes, sans jamais rien supprimer ni renommer | Prototypage uniquement |
| `validate` | Vérifie que le schéma correspond aux entités, et échoue sinon | Avec un outil de migration |
| `none` | Ne fait rien | Production |

`update` semble pratique, mais il est dangereux au-delà d'un prototype : il ne renomme jamais une colonne (il en crée une nouvelle, vide), ne supprime rien, et le schéma réel finit par diverger d'un environnement à l'autre sans que personne ne sache comment.

En projet réel, le schéma est géré par des **migrations versionnées** avec **Flyway** ou Liquibase :

```text
src/main/resources/db/migration/
  V1__initial_schema.sql
  V2__add_formation_level.sql
  V3__widen_description.sql
```

Au démarrage, Flyway applique dans l'ordre les scripts qui ne l'ont pas encore été, et note dans une table les versions appliquées. Chaque évolution du schéma devient un script **relu, versionné et identique** sur tous les environnements. Hibernate se contente de `validate` : une entité modifiée sans la migration correspondante fait échouer le démarrage immédiatement, en développement plutôt qu'en production.

## Les relations

### Plusieurs à un : @ManyToOne

Plusieurs formations appartiennent à une catégorie. Côté Java, la formation possède une **référence** vers l'objet `Categorie`, là où la table possède une **clé étrangère**.

```java
@ManyToOne(fetch = FetchType.LAZY, optional = false)
@JoinColumn(name = "categorie_id", nullable = false)
private Categorie categorie;
```

```text
Java : formation.getCategorie().getNom()
SQL  : formations.categorie_id → categories.id
```

### Un à plusieurs, côté inverse : @OneToMany

Une catégorie peut connaître ses formations :

```java
@OneToMany(mappedBy = "categorie")
private List<Formation> formations = new ArrayList<>();
```

`mappedBy = "categorie"` indique que la relation est **déjà décrite** par l'attribut `categorie` de `Formation`. C'est ce côté, celui qui porte la clé étrangère, qui est le **propriétaire** de la relation : c'est lui qu'Hibernate lit pour écrire la clé étrangère. Modifier seulement la liste `formations` d'une catégorie ne change **rien** en base.

Une relation bidirectionnelle n'est pas obligatoire. Beaucoup de relations n'ont besoin que du côté `@ManyToOne`, plus simple.

### Plusieurs à plusieurs : une entité d'association

`@ManyToMany` existe, mais dès que la relation porte des **données** (une date d'inscription, une note), on crée une **entité d'association**, comme la table d'association du bloc SQL :

```java
@Entity
@Table(name = "inscriptions",
        uniqueConstraints = @UniqueConstraint(name = "uk_inscription_apprenant_formation",
                columnNames = {"apprenant_id", "formation_id"}))
@Getter
@NoArgsConstructor
public class Inscription {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    private Apprenant apprenant;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    private Formation formation;

    @Column(nullable = false)
    private LocalDate inscritLe;

    @Setter
    private BigDecimal noteFinale;

    public Inscription(Apprenant apprenant, Formation formation, LocalDate inscritLe) {
        this.apprenant = apprenant;
        this.formation = formation;
        this.inscritLe = inscritLe;
    }
}
```

| Relation | Annotation | Exemple |
|----------|------------|---------|
| Plusieurs à un | `@ManyToOne` | Une formation a une catégorie |
| Un à plusieurs | `@OneToMany(mappedBy = ...)` | Une catégorie a des formations |
| Un à un | `@OneToOne` | Un utilisateur a un profil |
| Plusieurs à plusieurs avec données | Entité d'association + deux `@ManyToOne` | Une inscription relie un apprenant et une formation |

## Chargement paresseux ou immédiat

| Mode | Comportement |
|------|--------------|
| `LAZY` | La relation est chargée seulement quand on y accède |
| `EAGER` | La relation est chargée en même temps que l'entité |

Les relations `@ManyToOne` et `@OneToOne` sont `EAGER` **par défaut**, les `@OneToMany` sont `LAZY`. Passez systématiquement les relations en `LAZY` et chargez explicitement ce dont chaque cas d'usage a besoin (le cours suivant montre comment). Un `EAGER` généralisé charge des objets en cascade et peut ramener la moitié de la base pour afficher une simple liste.

En mode `LAZY`, Hibernate place un **proxy** à la place de l'objet : un objet vide qui déclenche une requête au premier accès. Cet accès doit avoir lieu **pendant une transaction**. En dehors, Hibernate lève une `LazyInitializationException`.

La propriété `spring.jpa.open-in-view=false` est recommandée : elle rend ce problème **visible** tout de suite au lieu de le masquer par des requêtes lancées discrètement pendant la sérialisation de la réponse JSON, loin de toute transaction maîtrisée.

## Le contexte de persistance

Pendant une transaction, les entités chargées sont **suivies** par Hibernate. Modifier un attribut suffit : à la validation de la transaction, Hibernate détecte le changement (c'est le **dirty checking**) et envoie l'`UPDATE` correspondant.

```java
@Transactional
public void augmenterPrix(Long id, BigDecimal pourcentage) {
    Formation formation = formationRepository.findById(id).orElseThrow();
    formation.setPrix(formation.getPrix().multiply(BigDecimal.ONE.add(pourcentage)));
    // aucun save() : l'UPDATE est envoyé automatiquement à la fin de la transaction
}
```

| État | Signification |
|------|---------------|
| Nouvelle (transient) | Créée avec `new`, inconnue d'Hibernate |
| Gérée (managed) | Chargée ou sauvegardée dans la transaction en cours, suivie |
| Détachée (detached) | La transaction est terminée, l'entité n'est plus suivie |

## Exemple complet

La migration Flyway et les entités correspondantes, cohérentes entre elles :

```sql
-- V1__initial_schema.sql
CREATE TABLE categories (
    id  BIGINT      NOT NULL AUTO_INCREMENT,
    nom VARCHAR(50) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_categories_nom UNIQUE (nom)
);

CREATE TABLE formations (
    id            BIGINT        NOT NULL AUTO_INCREMENT,
    categorie_id  BIGINT        NOT NULL,
    titre         VARCHAR(150)  NOT NULL,
    duree_heures  INT           NOT NULL,
    prix          DECIMAL(8,2)  NOT NULL,
    niveau        VARCHAR(20)   NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_formations_titre UNIQUE (titre),
    CONSTRAINT fk_formations_categorie FOREIGN KEY (categorie_id) REFERENCES categories (id)
);
```

```java
@Entity
@Table(name = "categories")
@Getter
@NoArgsConstructor
public class Categorie {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50, unique = true)
    private String nom;
}
```

```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false
```

Si un développeur ajoute un attribut à `Formation` sans écrire la migration `V2`, le démarrage échoue avec un message qui nomme la colonne manquante.

## Les erreurs fréquentes

- **`EnumType.ORDINAL`**, et des données décalées à l'ajout d'un cas.
- **`@Data` sur une entité.**
- **`ddl-auto: update` en production.**
- **Modifier seulement le côté `mappedBy`** d'une relation, et rien n'est enregistré.
- **Des relations `EAGER` partout.**
- **Accéder à une relation `LAZY` hors transaction.**
- **Renvoyer une entité depuis un contrôleur**, au lieu d'un DTO.

## Retour au besoin

Les formations survivent maintenant aux redémarrages, et aucune ligne de JDBC n'a été écrite : Hibernate génère le SQL et reconstruit les objets et leurs relations. Le schéma évolue par des migrations Flyway relues et versionnées, et Hibernate vérifie au démarrage que les entités lui correspondent. Il reste à écrire les requêtes elles-mêmes, ce que Spring Data JPA simplifie encore davantage.

## À retenir

- JPA est la spécification, Hibernate l'implémentation, Spring Data JPA la surcouche.
- Une entité par table, `EnumType.STRING` toujours, pas de `@Data`.
- Le schéma est géré par des migrations Flyway, Hibernate se contente de `validate`.
- Le côté qui porte la clé étrangère est le propriétaire de la relation, et une relation qui porte des données devient une entité d'association.
- Relations en `LAZY`, `open-in-view=false`, et les entités gérées sont mises à jour automatiquement à la fin de la transaction.

## Pour aller plus loin

- La documentation de Spring Data JPA : [docs.spring.io/spring-data/jpa/reference](https://docs.spring.io/spring-data/jpa/reference/)
- La documentation de Flyway : [documentation.red-gate.com/flyway](https://documentation.red-gate.com/flyway)
