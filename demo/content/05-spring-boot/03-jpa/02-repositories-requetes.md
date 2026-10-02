## Objectifs

- Comprendre ce qu'apporte le motif repository de Spring Data
- Créer un repository et utiliser les opérations héritées
- Écrire des requêtes dérivées du nom des méthodes
- Écrire des requêtes JPQL avec `@Query` et savoir quand recourir au SQL natif
- Renvoyer des projections et paginer
- Détecter et corriger le problème N+1

## Le besoin

Avec les entités en place, il faut maintenant lire et écrire les données. Même avec JPA, écrire soi-même chaque méthode d'accès reste répétitif :

```java
public class FormationDao {

    @PersistenceContext
    private EntityManager entityManager;

    public Optional<Formation> findById(Long id) {
        return Optional.ofNullable(entityManager.find(Formation.class, id));
    }

    public List<Formation> findByNiveau(Niveau niveau) {
        return entityManager.createQuery("SELECT f FROM Formation f WHERE f.niveau = :niveau", Formation.class)
                .setParameter("niveau", niveau)
                .getResultList();
    }

    // ... save, delete, count, pagination, pour chaque entité
}
```

Chaque entité demande les mêmes opérations de base : chercher par identifiant, enregistrer, supprimer, compter, paginer. Et beaucoup de recherches ne sont que des variations simples : par niveau, par titre, par prix maximum.

Spring Data JPA part d'un constat : ce code est **toujours le même**. Il suffit donc de **déclarer** ce que l'on veut, et Spring écrit l'implémentation.

## Définitions

> **Repository.** Une interface qui décrit l'accès aux données d'une entité. Spring Data en génère l'implémentation au démarrage.

> **Requête dérivée.** Une requête que Spring Data construit à partir du nom de la méthode : `findByTitre` produit `WHERE titre = ?`.

> **JPQL (Jakarta Persistence Query Language).** Un langage de requête proche de SQL, qui manipule des entités et leurs attributs plutôt que des tables et des colonnes.

> **Projection.** Une requête qui ne renvoie qu'une partie des données, sous forme de DTO ou d'interface, au lieu d'entités complètes.

> **Problème N+1.** Une requête pour charger une liste, puis une requête supplémentaire par élément pour charger une relation.

## Un repository

Il suffit de déclarer une interface qui étend `JpaRepository`, en précisant le type de l'entité et celui de son identifiant :

```java
public interface FormationRepository extends JpaRepository<Formation, Long> {
}
```

Aucune classe à écrire : au démarrage, Spring Data génère une implémentation et l'enregistre comme bean. Elle s'injecte ensuite dans les services :

```java
@Service
@RequiredArgsConstructor
public class FormationService {

    private final FormationRepository formationRepository;
}
```

L'interface hérite d'un ensemble d'opérations prêtes à l'emploi :

| Méthode | Rôle |
|---------|------|
| `save(entite)` | Insère une nouvelle entité ou met à jour une existante |
| `saveAll(entites)` | Enregistre plusieurs entités |
| `findById(id)` | Renvoie un `Optional`, vide si l'identifiant n'existe pas |
| `findAll()`, `findAll(pageable)` | Toutes les entités, ou une page |
| `existsById(id)` | Test d'existence |
| `count()` | Nombre de lignes |
| `deleteById(id)`, `delete(entite)` | Suppression |

`findById` renvoie un `Optional` : l'absence de résultat est explicite, et se traite avec `orElseThrow` :

```java
Formation formation = formationRepository.findById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Formation", id));
```

## Les requêtes dérivées

Spring Data construit la requête à partir du **nom de la méthode**, en l'analysant mot par mot :

```java
public interface FormationRepository extends JpaRepository<Formation, Long> {

    Optional<Formation> findByTitreIgnoreCase(String titre);

    boolean existsByTitreIgnoreCase(String titre);

    List<Formation> findByNiveauOrderByTitreAsc(Niveau niveau);

    Page<Formation> findByPrixLessThanEqual(BigDecimal prixMax, Pageable pageable);

    List<Formation> findByCategorieNomAndNiveau(String nomCategorie, Niveau niveau);

    long countByCategorieId(Long categorieId);
}
```

```text
findByNiveauOrderByTitreAsc
│      │      │
│      │      └── ORDER BY titre ASC
│      └── WHERE niveau = ?
└── SELECT ... (une liste d'entités)
```

| Mot-clé | Traduction SQL |
|---------|----------------|
| `findBy`, `existsBy`, `countBy`, `deleteBy` | Le type d'opération |
| `And`, `Or` | `AND`, `OR` |
| `LessThan`, `GreaterThanEqual`, `Between` | `<`, `>=`, `BETWEEN` |
| `Containing`, `StartingWith` | `LIKE '%...%'`, `LIKE '...%'` |
| `IgnoreCase` | Comparaison sans tenir compte de la casse |
| `In` | `IN (...)` |
| `IsNull`, `IsNotNull` | `IS NULL`, `IS NOT NULL` |
| `OrderBy...Asc`, `OrderBy...Desc` | `ORDER BY` |
| `CategorieNom` | Traverse la relation : `WHERE categorie.nom = ?` |

Un nom mal formé, ou un attribut qui n'existe pas, fait **échouer le démarrage** : l'erreur est détectée tout de suite, pas devant l'utilisateur.

Les requêtes dérivées sont idéales pour les recherches simples. Au-delà de deux ou trois critères, le nom devient illisible (`findByNiveauAndPrixLessThanEqualAndCategorieNomOrderByTitreAsc`) : passez à `@Query`.

## JPQL avec @Query

**JPQL** ressemble à SQL, mais manipule des **entités et leurs attributs**, pas des tables et des colonnes.

```java
@Query("""
        SELECT f FROM Formation f
        WHERE f.categorie.id = :categorieId
          AND f.prix BETWEEN :prixMin AND :prixMax
        ORDER BY f.prix
        """)
List<Formation> rechercher(@Param("categorieId") Long categorieId,
                           @Param("prixMin") BigDecimal prixMin,
                           @Param("prixMax") BigDecimal prixMax);
```

| SQL | JPQL |
|-----|------|
| `FROM formations` (la table) | `FROM Formation f` (l'entité) |
| `f.categorie_id` (la colonne) | `f.categorie.id` (l'attribut, en suivant la relation) |
| `JOIN categories c ON c.id = f.categorie_id` | `JOIN f.categorie c` (la jointure suit la relation) |

Les paramètres nommés (`:categorieId`) sont transmis **séparément** de la requête : aucune injection SQL possible, exactement comme une requête préparée.

JPQL sait aussi modifier en masse :

```java
@Modifying
@Query("UPDATE Formation f SET f.prix = f.prix * :coefficient WHERE f.categorie.id = :categorieId")
int augmenterPrix(@Param("categorieId") Long categorieId, @Param("coefficient") BigDecimal coefficient);
```

## Le SQL natif

Une requête SQL native reste possible avec `nativeQuery = true` :

```java
@Query(value = "SELECT * FROM formations WHERE MATCH(titre) AGAINST (:terme)", nativeQuery = true)
List<Formation> rechercherTexteIntegral(@Param("terme") String terme);
```

Elle se justifie au **cas par cas** : une fonctionnalité propre à MySQL comme la recherche en texte intégral, ou une optimisation mesurée. Elle lie le code à un moteur de base précis et échappe à certaines vérifications d'Hibernate.

| Besoin | Outil |
|--------|-------|
| Une recherche simple sur un ou deux critères | Requête dérivée |
| Plusieurs critères, une jointure, une agrégation | JPQL avec `@Query` |
| Une fonction propre à MySQL, une optimisation mesurée | SQL natif, en dernier recours |

## Les projections

Pour une liste qui n'affiche que quelques colonnes, charger des entités complètes avec leurs relations est un gaspillage. On peut renvoyer **directement un DTO** depuis la requête :

```java
public record FormationResume(Long id, String titre, String categorie) {}

@Query("""
        SELECT new fr.exemple.formations.dtos.response.FormationResume(f.id, f.titre, c.nom)
        FROM Formation f JOIN f.categorie c
        ORDER BY f.titre
        """)
List<FormationResume> listerResumes();
```

Hibernate ne sélectionne que les trois colonnes utiles, et ne crée aucune entité à suivre.

## La pagination

Un paramètre `Pageable` suffit pour paginer une requête dérivée ou une requête `@Query` :

```java
Page<Formation> findByNiveau(Niveau niveau, Pageable pageable);
```

```java
Pageable pageable = PageRequest.of(0, 20, Sort.by("titre"));
Page<Formation> page = formationRepository.findByNiveau(Niveau.DEBUTANT, pageable);

page.getContent();         // les 20 formations de la page
page.getTotalElements();   // le nombre total de formations débutant
page.getTotalPages();
```

Spring Data exécute deux requêtes : une pour la page, une `COUNT` pour le total.

## Le problème N+1

```java
List<Formation> formations = formationRepository.findAll();          // 1 requête
formations.forEach(f -> System.out.println(f.getCategorie().getNom()));   // + 1 requête par formation
```

```text
SELECT * FROM formations
SELECT * FROM categories WHERE id = 1
SELECT * FROM categories WHERE id = 2
SELECT * FROM categories WHERE id = 1   (mise en cache, parfois évitée)
...
```

Avec 100 formations, jusqu'à 101 requêtes partent vers la base. C'est le **problème N+1**, l'une des causes les plus fréquentes de lenteur avec un ORM. Il est sournois : invisible en développement avec cinq lignes, il fait s'effondrer les performances en production avec des milliers.

Activez `spring.jpa.show-sql=true` en développement pour voir les requêtes générées et le repérer.

Trois solutions courantes :

```java
// 1. JOIN FETCH : la relation est chargée dans la même requête
@Query("SELECT f FROM Formation f JOIN FETCH f.categorie")
List<Formation> findAllAvecCategorie();

// 2. EntityGraph : la même chose, sur une méthode existante
@EntityGraph(attributePaths = "categorie")
Page<Formation> findAll(Pageable pageable);
```

```yaml
# 3. Chargement groupé global : les relations sont chargées par lots
spring:
  jpa:
    properties:
      hibernate:
        default_batch_fetch_size: 20
```

| Solution | Nombre de requêtes pour 100 formations |
|----------|----------------------------------------|
| Aucune | jusqu'à 101 |
| `JOIN FETCH` ou `@EntityGraph` | 1 |
| Chargement par lots de 20 | 1 + 5 |

`JOIN FETCH` sur une **collection** (`@OneToMany`) combiné à une pagination force Hibernate à charger tous les résultats puis à paginer **en mémoire**, avec un avertissement. Préférez alors le chargement par lots.

## Exemple complet

Le repository des inscriptions, avec les trois styles de requêtes :

```java
public interface InscriptionRepository extends JpaRepository<Inscription, Long> {

    boolean existsByApprenantIdAndFormationId(Long apprenantId, Long formationId);

    long countByFormationId(Long formationId);

    @EntityGraph(attributePaths = "apprenant")
    Page<Inscription> findByFormationId(Long formationId, Pageable pageable);

    @Query("""
            SELECT AVG(i.noteFinale) FROM Inscription i
            WHERE i.apprenant.id = :apprenantId AND i.noteFinale IS NOT NULL
            """)
    Optional<Double> moyenneDeLApprenant(@Param("apprenantId") Long apprenantId);
}
```

- `existsBy...` vérifie un doublon avant l'inscription.
- `countBy...` compare le nombre d'inscrits à la capacité.
- `findByFormationId` avec `@EntityGraph` liste les inscrits avec leur nom, sans N+1.
- `moyenneDeLApprenant` calcule une agrégation directement en base.

## Les erreurs fréquentes

- **Réécrire à la main** ce que `JpaRepository` fournit déjà.
- **Des noms de méthodes dérivées interminables** au lieu d'une `@Query`.
- **Du SQL natif par habitude**, sans besoin réel.
- **Concaténer une valeur** dans une `@Query` au lieu d'un paramètre nommé.
- **Ignorer les requêtes générées**, et découvrir le N+1 en production.
- **`findAll()` sans pagination** sur une grande table.

## Retour au besoin

Le `FormationDao` écrit à la main disparaît : une interface suffit, et Spring Data en génère l'implémentation. Les recherches simples s'expriment par le nom d'une méthode, les plus complexes en JPQL, et le SQL natif reste disponible pour les cas particuliers. En surveillant les requêtes générées et en chargeant explicitement les relations utiles, on évite le problème N+1. Il reste à maîtriser les transactions et à tester tout cela : c'est l'objet du cours suivant.

## À retenir

- Un repository est une interface, Spring Data écrit l'implémentation.
- Requêtes dérivées pour les cas simples, `@Query` en JPQL au-delà, SQL natif au cas par cas.
- Des paramètres nommés, jamais de concaténation.
- Des projections pour ne charger que ce qui est affiché, et une pagination pour toute liste.
- Surveillez les requêtes générées, et corrigez le N+1 avec `JOIN FETCH`, `@EntityGraph` ou le chargement par lots.

## Pour aller plus loin

- Les méthodes de requête dans la documentation de Spring Data JPA : [docs.spring.io/spring-data/jpa/reference/jpa/query-methods.html](https://docs.spring.io/spring-data/jpa/reference/jpa/query-methods.html)
