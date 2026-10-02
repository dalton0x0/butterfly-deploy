## Objectifs

- Délimiter une transaction avec `@Transactional` et comprendre son fonctionnement
- Connaître les pièges des transactions : appel interne, exceptions vérifiées, effets irréversibles
- Comprendre pourquoi et quoi tester
- Tester un service avec JUnit et Mockito
- Tester un contrôleur avec `@WebMvcTest` et un repository avec `@DataJpaTest`
- Construire une stratégie de tests équilibrée

## Le besoin

Le service d'inscription vérifie qu'un apprenant n'est pas déjà inscrit, que la formation n'est pas complète, puis enregistre l'inscription et envoie un e-mail. Deux inquiétudes subsistent :

**La cohérence.** Si une erreur survient au milieu de l'inscription, après l'enregistrement mais avant la mise à jour du compteur de places, la base se retrouve dans un état incohérent. Et si l'e-mail de confirmation part alors que l'inscription échoue ensuite, l'apprenant reçoit une confirmation pour rien.

**La confiance.** Chaque modification du code peut casser une règle existante. Vérifier à la main, après chaque changement, que les doublons sont refusés, que les formations complètes aussi, que les erreurs renvoient les bons statuts, prend des heures, et finit par être négligé.

Les **transactions** répondent au premier problème, les **tests automatisés** au second.

## Définitions

> **Transaction.** Un groupe d'opérations sur la base appliqué entièrement ou pas du tout.

> **Proxy.** Un objet intermédiaire que Spring place autour d'un bean pour ajouter un comportement, comme l'ouverture et la validation d'une transaction.

> **Test unitaire.** Un test qui vérifie une classe isolée, en remplaçant ses dépendances par des simulacres.

> **Simulacre (mock).** Un objet factice qui imite une dépendance : on programme ses réponses et on vérifie comment il a été appelé.

> **Test en tranche (slice test).** Un test qui démarre seulement une partie de l'application Spring : la couche web, ou la couche de persistance.

> **Régression.** Une fonctionnalité qui fonctionnait et qui est cassée par une modification.

## @Transactional

Une méthode de service annotée `@Transactional` s'exécute dans une transaction. Si elle se termine normalement, les modifications sont **validées**. Si une exception non vérifiée est levée, tout est **annulé**.

```java
@Service
@RequiredArgsConstructor
public class InscriptionServiceImpl implements InscriptionService {

    private final InscriptionRepository inscriptionRepository;
    private final FormationRepository formationRepository;
    private final ApprenantRepository apprenantRepository;
    private final InscriptionProperties properties;

    @Override
    @Transactional
    public InscriptionResponse inscrire(Long apprenantId, Long formationId) {
        Apprenant apprenant = apprenantRepository.findById(apprenantId)
                .orElseThrow(() -> new ResourceNotFoundException("Apprenant", apprenantId));
        Formation formation = formationRepository.findById(formationId)
                .orElseThrow(() -> new ResourceNotFoundException("Formation", formationId));

        if (inscriptionRepository.existsByApprenantIdAndFormationId(apprenantId, formationId)) {
            throw new DuplicateResourceException("L'apprenant est déjà inscrit à cette formation");
        }
        if (inscriptionRepository.countByFormationId(formationId) >= properties.placesMaximum()) {
            throw new BusinessRuleException("La formation est complète");
        }

        Inscription inscription = new Inscription(apprenant, formation, LocalDate.now());
        return InscriptionResponse.fromEntity(inscriptionRepository.save(inscription));
    }

    @Override
    @Transactional(readOnly = true)
    public Page<InscriptionResponse> listerParFormation(Long formationId, Pageable pageable) {
        return inscriptionRepository.findByFormationId(formationId, pageable)
                .map(InscriptionResponse::fromEntity);
    }
}
```

`readOnly = true` signale une transaction de lecture : Hibernate se dispense de surveiller les modifications des entités chargées, ce qui économise de la mémoire et du temps.

## Comment ça fonctionne : le proxy

Spring ne modifie pas votre classe. Il place un **proxy** autour du bean, et c'est ce proxy que reçoivent les autres classes :

```text
Contrôleur ──► Proxy Spring ─────────────────► InscriptionServiceImpl
                 │ 1. ouvre la transaction        inscrire(...)
                 │ 3. valide, ou annule            2. exécute la méthode
                 │    si une exception remonte
```

Ce mécanisme explique la plupart des pièges.

## Les pièges des transactions

### L'appel interne

```java
@Service
public class RapportService {

    public void genererTout() {
        for (Long id : ids) {
            genererUn(id);            // appel direct : le proxy est contourné
        }
    }

    @Transactional
    public void genererUn(Long id) { ... }   // l'annotation est ignorée ici
}
```

Un appel à une méthode de la **même classe** ne passe pas par le proxy : l'annotation de la méthode appelée n'a aucun effet. La transaction doit être placée sur la méthode appelée depuis l'extérieur, ou la logique déplacée dans un autre bean.

### Les exceptions vérifiées

Par défaut, seules les exceptions **non vérifiées** (`RuntimeException` et ses filles) déclenchent l'annulation. Une exception vérifiée, comme `IOException`, laisse la transaction se **valider**. Pour changer ce comportement : `@Transactional(rollbackFor = Exception.class)`. C'est une raison de plus de construire les exceptions métier sur `RuntimeException`.

### Les effets irréversibles

Un e-mail, un appel à un service de paiement ou l'écriture d'un fichier ne s'annulent pas avec la transaction. Envoyer l'e-mail de confirmation **au milieu** de la transaction, puis échouer, informerait l'apprenant d'une inscription qui n'existe pas.

On déclenche ces actions **après** la validation, par exemple avec un événement écouté par `@TransactionalEventListener`, ou avec `TransactionSynchronization` :

```java
TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
    @Override
    public void afterCommit() {
        emailSender.envoyer(apprenant.getEmail(), "Inscription confirmée");
    }
});
```

### La bonne couche

Les transactions se placent sur les **services**, qui connaissent l'unité de travail métier. Pas sur les contrôleurs, qui ne devraient pas connaître la persistance, ni sur chaque méthode de repository, qui n'a qu'une vision partielle de l'opération.

## Pourquoi tester ?

Un test automatisé vérifie en quelques millisecondes ce qu'une vérification manuelle ferait en plusieurs minutes, et il le refait **à chaque modification**. Les tests :

- protègent contre les **régressions** ;
- donnent la **confiance** nécessaire pour refactoriser ;
- servent de **documentation vivante** : un test nommé `inscrire_refuseUneFormationComplete` décrit une règle métier ;
- sont lancés automatiquement par l'**intégration continue** avant chaque fusion.

## Tester un service avec Mockito

Un test unitaire de service remplace les repositories par des **simulacres**. Il ne démarre ni Spring ni la base : il s'exécute en quelques millisecondes.

```java
@ExtendWith(MockitoExtension.class)
class InscriptionServiceImplTest {

    @Mock
    private InscriptionRepository inscriptionRepository;
    @Mock
    private FormationRepository formationRepository;
    @Mock
    private ApprenantRepository apprenantRepository;

    private InscriptionServiceImpl inscriptionService;

    @BeforeEach
    void setUp() {
        InscriptionProperties properties = new InscriptionProperties(20, Duration.ofHours(48), 0.7);
        inscriptionService = new InscriptionServiceImpl(
                inscriptionRepository, formationRepository, apprenantRepository, properties);
    }

    @Test
    void inscrire_refuseUneInscriptionEnDouble() {
        // Arrange : préparer les données et les réponses des simulacres
        when(apprenantRepository.findById(1L)).thenReturn(Optional.of(new Apprenant()));
        when(formationRepository.findById(2L)).thenReturn(Optional.of(new Formation()));
        when(inscriptionRepository.existsByApprenantIdAndFormationId(1L, 2L)).thenReturn(true);

        // Act et Assert : exécuter et vérifier le résultat
        assertThatThrownBy(() -> inscriptionService.inscrire(1L, 2L))
                .isInstanceOf(DuplicateResourceException.class);

        verify(inscriptionRepository, never()).save(any());
    }

    @Test
    void inscrire_refuseUneFormationComplete() {
        when(apprenantRepository.findById(1L)).thenReturn(Optional.of(new Apprenant()));
        when(formationRepository.findById(2L)).thenReturn(Optional.of(new Formation()));
        when(inscriptionRepository.countByFormationId(2L)).thenReturn(20L);

        assertThatThrownBy(() -> inscriptionService.inscrire(1L, 2L))
                .isInstanceOf(BusinessRuleException.class)
                .hasMessageContaining("complète");
    }
}
```

| Élément | Rôle |
|---------|------|
| `@ExtendWith(MockitoExtension.class)` | Active Mockito dans JUnit 5 |
| `@Mock` | Crée un simulacre de la dépendance |
| `when(...).thenReturn(...)` | Programme la réponse du simulacre |
| `verify(..., never()).save(any())` | Vérifie qu'une méthode n'a **pas** été appelée |
| `assertThatThrownBy` | Vérifie qu'une exception précise est levée (bibliothèque AssertJ) |

Un test suit le schéma **Arrange, Act, Assert** : préparer, exécuter, vérifier. Son nom décrit le comportement attendu, et il ne vérifie **qu'une idée** à la fois. Quand il échoue, on sait immédiatement quelle règle est cassée.

Grâce à l'injection par constructeur, le service se construit avec un simple `new` : aucun besoin de Spring pour le tester.

## Les tests en tranche

Certaines vérifications ont besoin d'une partie de Spring. Spring Boot sait démarrer seulement une **tranche** de l'application :

| Annotation | Ce qui est chargé | Ce que l'on teste | Vitesse |
|------------|-------------------|-------------------|---------|
| `@WebMvcTest(FormationController.class)` | La couche web seule, les services sont simulés | Routes, validation, statuts, format JSON | Rapide |
| `@DataJpaTest` | JPA, les repositories et une base de test | Requêtes, contraintes, mapping | Moyenne |
| `@SpringBootTest` | Toute l'application | Scénarios de bout en bout | Lente |

### Tester un contrôleur

```java
@WebMvcTest(FormationController.class)
class FormationControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private FormationService formationService;

    @Test
    void creer_renvoie400SiLeTitreEstVide() throws Exception {
        mockMvc.perform(post("/api/formations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"titre": "", "dureeHeures": 10, "prix": 100, "categorieId": 1}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.validationErrors.titre").exists());

        verifyNoInteractions(formationService);
    }

    @Test
    void lire_renvoie404SiLaFormationNExistePas() throws Exception {
        when(formationService.lire(99L)).thenThrow(new ResourceNotFoundException("Formation", 99L));

        mockMvc.perform(get("/api/formations/99"))
                .andExpect(status().isNotFound());
    }
}
```

`MockMvc` simule des requêtes HTTP sans démarrer de serveur. `@MockitoBean` remplace un bean par un simulacre dans le contexte de test ; il succède à `@MockBean`, supprimé dans Spring Boot 4. `jsonPath` vérifie une valeur précise du JSON renvoyé.

Ce test vérifie que la validation fonctionne et que le gestionnaire global d'erreurs produit les bons statuts : des comportements invisibles dans un test unitaire de service.

### Tester un repository

```java
@DataJpaTest
class InscriptionRepositoryTest {

    @Autowired
    private InscriptionRepository inscriptionRepository;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void countByFormationId_compteSeulementLesInscriptionsDeLaFormation() {
        Formation java = entityManager.persist(uneFormation("Java"));
        Formation sql = entityManager.persist(uneFormation("SQL"));
        Apprenant emma = entityManager.persist(unApprenant("emma"));
        Apprenant lucas = entityManager.persist(unApprenant("lucas"));
        entityManager.persist(new Inscription(emma, java, LocalDate.now()));
        entityManager.persist(new Inscription(lucas, java, LocalDate.now()));
        entityManager.persist(new Inscription(emma, sql, LocalDate.now()));

        assertThat(inscriptionRepository.countByFormationId(java.getId())).isEqualTo(2);
    }
}
```

`uneFormation` et `unApprenant` sont des méthodes utilitaires du test qui construisent des entités valides. Les regrouper dans une classe de fixtures partagée évite de répéter leur construction dans chaque test.

Un test `@DataJpaTest` s'exécute dans une transaction **annulée à la fin** : chaque test repart d'une base propre. Il vérifie que la requête dérivée fait bien ce que l'on croit, et que le mapping correspond au schéma.

## La pyramide des tests

```text
            /\
           /  \        Quelques tests de bout en bout (@SpringBootTest)
          /────\
         /      \      Des tests en tranche (@WebMvcTest, @DataJpaTest)
        /────────\
       /          \    Beaucoup de tests unitaires rapides (Mockito)
      /────────────\
```

Beaucoup de tests unitaires, rapides et précis, pour les règles métier. Moins de tests en tranche pour la couche web et les requêtes. Quelques tests de bout en bout pour les parcours critiques. Cet équilibre donne une suite de tests à la fois **rapide** et **fiable**.

## Exemple complet

Le test du cas nominal de l'inscription, qui vérifie aussi ce qui a été enregistré :

```java
@Test
void inscrire_enregistreLInscriptionDuJour() {
    Apprenant emma = new Apprenant();
    Formation java = new Formation();
    when(apprenantRepository.findById(1L)).thenReturn(Optional.of(emma));
    when(formationRepository.findById(2L)).thenReturn(Optional.of(java));
    when(inscriptionRepository.existsByApprenantIdAndFormationId(1L, 2L)).thenReturn(false);
    when(inscriptionRepository.countByFormationId(2L)).thenReturn(5L);
    when(inscriptionRepository.save(any(Inscription.class))).thenAnswer(appel -> appel.getArgument(0));

    inscriptionService.inscrire(1L, 2L);

    ArgumentCaptor<Inscription> capture = ArgumentCaptor.forClass(Inscription.class);
    verify(inscriptionRepository).save(capture.capture());
    assertThat(capture.getValue().getApprenant()).isSameAs(emma);
    assertThat(capture.getValue().getFormation()).isSameAs(java);
    assertThat(capture.getValue().getInscritLe()).isEqualTo(LocalDate.now());
}
```

`ArgumentCaptor` récupère l'objet réellement passé à `save`, pour vérifier son contenu. La dépendance à `LocalDate.now()` rendrait toutefois ce test fragile autour de minuit : injecter une `Clock`, comme vu dans le premier module, le rendrait parfaitement reproductible.

## Les erreurs fréquentes

- **`@Transactional` sur une méthode appelée depuis la même classe.**
- **Une exception vérifiée** qui laisse passer une transaction à moitié faite.
- **Envoyer un e-mail dans la transaction**, avant la validation.
- **Tout tester avec `@SpringBootTest`**, et une suite de tests qui prend dix minutes.
- **Des tests qui dépendent de l'ordre d'exécution** ou de l'heure courante.
- **Ne tester que le cas nominal**, alors que les bugs se cachent dans les cas d'erreur.

## Retour au besoin

L'inscription est désormais une unité indivisible : une erreur au milieu annule tout, et l'e-mail ne part qu'une fois la transaction validée. Les règles métier sont couvertes par des tests unitaires qui s'exécutent en quelques millisecondes, la validation et les statuts HTTP par des tests de la couche web, les requêtes par des tests de persistance. Chaque modification est vérifiée automatiquement, et une régression est détectée avant d'atteindre la production.

## À retenir

- `@Transactional` sur les services : tout ou rien, `readOnly` pour les lectures.
- Le proxy explique les pièges : un appel interne contourne la transaction.
- Seules les exceptions non vérifiées annulent par défaut, et un effet irréversible attend la validation.
- Mockito pour tester un service sans Spring, `@WebMvcTest` pour la couche web, `@DataJpaTest` pour les repositories.
- La pyramide des tests : beaucoup de tests unitaires, moins de tests en tranche, quelques tests de bout en bout.

## Pour aller plus loin

- La gestion des transactions dans la documentation de Spring : [docs.spring.io/spring-framework/reference/data-access/transaction.html](https://docs.spring.io/spring-framework/reference/data-access/transaction.html)
- Les tests dans la documentation de Spring Boot : [docs.spring.io/spring-boot/reference/testing](https://docs.spring.io/spring-boot/reference/testing/index.html)
