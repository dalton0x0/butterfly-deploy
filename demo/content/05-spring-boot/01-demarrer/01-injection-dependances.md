## Objectifs

- Comprendre ce qu'est un framework et ce qu'apportent Spring et Spring Boot
- Comprendre le problème du couplage fort entre classes
- Définir l'inversion de contrôle, l'injection de dépendances et les beans
- Déclarer des beans avec les annotations et avec `@Bean`
- Injecter par constructeur et gérer plusieurs implémentations
- Connaître le cycle de vie d'un bean singleton

## Le besoin

Une API de gestion de formations, écrite en Java pur, finit par ressembler à ceci :

```java
public class InscriptionService {

    private final InscriptionRepository repository = new InscriptionRepository(
            new ConnexionBase("jdbc:mysql://localhost:3306/formations", "root", "secret"));
    private final EmailSender emailSender = new SmtpEmailSender("smtp.exemple.fr", 587);

    public void inscrire(Long apprenantId, Long formationId) {
        // ...
        emailSender.envoyer(email, "Inscription confirmée");
    }
}
```

Chaque classe **fabrique elle-même** les objets dont elle a besoin. Les conséquences s'accumulent :

- **impossible de tester** `InscriptionService` sans une vraie base de données et un vrai serveur d'e-mails ;
- **impossible de changer** de fournisseur d'e-mails sans modifier toutes les classes qui en créent un ;
- la **configuration** (adresse de la base, mot de passe) est dispersée et écrite en dur ;
- chaque service crée **sa propre connexion** à la base, et l'application en ouvre des centaines ;
- il faut encore écrire soi-même le serveur HTTP, la conversion JSON, la gestion des transactions, la sécurité...

Toute application d'entreprise a ces mêmes besoins d'infrastructure. Plutôt que de les réécrire, on s'appuie sur un **framework** qui les fournit, et qui prend en charge la création et l'assemblage des objets.

## Définitions

> **Framework.** Un cadre de développement qui fournit une infrastructure prête à l'emploi et impose une structure. Contrairement à une bibliothèque, que votre code appelle, c'est le framework qui appelle votre code au bon moment.

> **Dépendance.** Un objet dont une classe a besoin pour fonctionner : `InscriptionService` dépend d'un repository et d'un service d'e-mail.

> **Couplage fort.** Une classe qui crée elle-même ses dépendances concrètes est soudée à elles : on ne peut plus les remplacer sans la modifier.

> **Inversion de contrôle (IoC).** Le principe selon lequel ce n'est plus la classe qui crée ses dépendances, mais un mécanisme extérieur qui les lui fournit.

> **Injection de dépendances.** La technique qui met en œuvre l'inversion de contrôle : les dépendances sont passées à la classe, le plus souvent par son constructeur.

> **Conteneur Spring (ApplicationContext).** Le cœur de Spring : il crée les objets de l'application, les relie entre eux et gère leur cycle de vie.

> **Bean.** Un objet créé et géré par le conteneur Spring.

## Spring et Spring Boot

**Spring** est un framework Java créé en 2003, devenu la référence de l'écosystème Java en entreprise. Il fournit un conteneur d'injection de dépendances et de nombreux modules : web, accès aux données, sécurité, messagerie, traitements par lots.

Spring seul demandait beaucoup de configuration. **Spring Boot**, apparu en 2014, simplifie considérablement son utilisation :

| Apport | Rôle | Exemple |
|--------|------|---------|
| **Starters** | Des dépendances Maven qui regroupent tout ce qu'il faut pour un usage | `spring-boot-starter-web` apporte Spring MVC, Tomcat et Jackson |
| **Auto-configuration** | Configure automatiquement les composants selon ce qui est présent dans le projet | Le pilote MySQL est détecté : une source de données est créée |
| **Serveur embarqué** | L'application contient son serveur web et se lance comme un simple programme | `java -jar formations.jar` |
| **Configuration externalisée** | Un fichier `application.yml` et des variables d'environnement | L'adresse de la base change sans recompiler |
| **Supervision** | Des points de santé et de métriques prêts à l'emploi | `/actuator/health` |

Le point de départ le plus simple est **Spring Initializr** ([start.spring.io](https://start.spring.io)), qui génère un projet Maven ou Gradle avec les dépendances choisies.

```java
@SpringBootApplication
public class FormationsApplication {

    public static void main(String[] args) {
        SpringApplication.run(FormationsApplication.class, args);
    }
}
```

`@SpringBootApplication` active trois mécanismes : la configuration Spring, l'auto-configuration et la **détection automatique** des composants dans le package de cette classe et ses sous-packages. `SpringApplication.run` démarre le conteneur, crée tous les beans, puis lance le serveur web.

## L'inversion de contrôle

Reprenons le service d'inscription. Au lieu de créer ses dépendances, il les **reçoit** :

```java
@Service
public class InscriptionService {

    private final InscriptionRepository repository;
    private final EmailSender emailSender;

    public InscriptionService(InscriptionRepository repository, EmailSender emailSender) {
        this.repository = repository;
        this.emailSender = emailSender;
    }

    public void inscrire(Long apprenantId, Long formationId) {
        // ...
        emailSender.envoyer(email, "Inscription confirmée");
    }
}
```

```text
Sans Spring                              Avec Spring

InscriptionService                       Conteneur Spring
  ├─ new InscriptionRepository(...)        ├─ crée InscriptionRepository
  └─ new SmtpEmailSender(...)              ├─ crée SmtpEmailSender
                                           └─ crée InscriptionService(repository, emailSender)
Le service fabrique ses dépendances      Le conteneur fabrique et assemble tout
```

Au démarrage, Spring constate que `InscriptionService` a besoin d'un `InscriptionRepository` et d'un `EmailSender`. Il trouve les beans correspondants, les crée si nécessaire, et les passe au constructeur. Le **contrôle** de la création est **inversé** : il passe de la classe au conteneur.

`EmailSender` est ici une **interface**. Le service ne sait pas s'il reçoit un envoi SMTP, un service externe ou une implémentation factice. C'est exactement le principe vu dans le bloc Java avec les interfaces, automatisé par Spring.

## Déclarer des beans

### Par les annotations

Les classes annotées sont détectées automatiquement lors du démarrage :

| Annotation | Rôle | Couche |
|------------|------|--------|
| `@Component` | Bean générique | Tout composant |
| `@Service` | Logique métier | Service |
| `@Repository` | Accès aux données, avec traduction des exceptions de persistance | Persistance |
| `@RestController` | Contrôleur web qui renvoie des données | Web |
| `@Configuration` | Classe de configuration contenant des méthodes `@Bean` | Configuration |

`@Service`, `@Repository` et `@RestController` sont des spécialisations de `@Component`. Elles documentent le rôle de la classe et certaines ajoutent un comportement, comme la traduction des exceptions pour `@Repository`.

### Par une méthode @Bean

Pour un objet d'une **bibliothèque externe**, que l'on ne peut pas annoter, on le déclare dans une classe de configuration :

```java
@Configuration
public class HorlogeConfig {

    @Bean
    public Clock clock() {
        return Clock.systemDefaultZone();
    }
}
```

La valeur renvoyée par la méthode devient un bean, injectable partout. Injecter une `Clock` plutôt qu'appeler `LocalDateTime.now()` directement permet de **fixer l'heure dans les tests** : on passe une horloge figée, et le comportement lié aux dates devient reproductible.

```java
@Service
public class QuizService {

    private final Clock clock;

    public QuizService(Clock clock) {
        this.clock = clock;
    }

    public boolean estExpire(LocalDateTime limite) {
        return LocalDateTime.now(clock).isAfter(limite);
    }
}
```

## Toujours injecter par constructeur

Spring sait injecter de trois façons :

```java
// 1. Par constructeur : recommandé
public InscriptionService(InscriptionRepository repository) {
    this.repository = repository;
}

// 2. Par setter
@Autowired
public void setRepository(InscriptionRepository repository) { ... }

// 3. Directement dans le champ : à éviter
@Autowired
private InscriptionRepository repository;
```

L'injection par **constructeur** est la bonne pratique :

- les dépendances sont `final` : l'objet est **complet et immuable** dès sa création, jamais dans un état intermédiaire ;
- les dépendances sont **visibles** dans la signature : on sait immédiatement de quoi la classe a besoin ;
- la classe se **teste sans Spring**, avec un simple `new` et des implémentations factices ;
- une dépendance circulaire (A a besoin de B qui a besoin de A) est détectée au démarrage.

Avec un seul constructeur, l'annotation `@Autowired` est inutile. **Lombok** peut générer ce constructeur avec `@RequiredArgsConstructor`, qui prend en paramètre tous les champs `final` :

```java
@Service
@RequiredArgsConstructor
public class InscriptionService {

    private final InscriptionRepository repository;
    private final EmailSender emailSender;
}
```

Un constructeur qui réclame huit dépendances est un **signal** : la classe a probablement trop de responsabilités et gagnerait à être découpée.

## Plusieurs implémentations

Si deux beans implémentent la même interface, Spring ne sait pas lequel injecter :

```text
Parameter 1 of constructor in InscriptionService required a single bean, but 2 were found:
    - smtpEmailSender
    - brevoEmailSender
```

Le démarrage échoue, et c'est une bonne chose : l'ambiguïté est signalée immédiatement. Deux solutions :

```java
@Service
@Primary                          // choisi par défaut quand plusieurs candidats existent
public class SmtpEmailSender implements EmailSender { ... }
```

```java
public InscriptionService(@Qualifier("brevoEmailSender") EmailSender emailSender) { ... }
```

On peut aussi activer une implémentation selon la configuration, par exemple une implémentation qui se contente de journaliser les e-mails en développement.

## Le cycle de vie d'un bean

Par défaut, un bean a la portée **singleton** : le conteneur en crée **une seule instance**, partagée par toute l'application pendant toute sa durée de vie.

```text
Démarrage         Fonctionnement                          Arrêt
  crée les beans    la même instance de InscriptionService   détruit les beans
  une seule fois    traite toutes les requêtes HTTP
```

Conséquence essentielle : un service reçoit des **requêtes simultanées** de plusieurs utilisateurs sur des threads différents. Il ne doit donc **pas** conserver d'état propre à une requête dans ses attributs :

```java
@Service
public class PanierService {

    private List<Long> formationsChoisies = new ArrayList<>();   // DANGER : partagé par tous les utilisateurs

    public void ajouter(Long formationId) {
        formationsChoisies.add(formationId);   // Emma et Lucas remplissent le même panier
    }
}
```

Les attributs d'un service sont ses **dépendances**, `final` et sans état. Les données propres à un utilisateur vivent en base, en session ou dans les paramètres des méthodes.

## Exemple complet

Un service d'inscription testable, avec une horloge et un envoi d'e-mails injectés :

```java
public interface EmailSender {
    void envoyer(String destinataire, String sujet);
}

@Component
public class JournalEmailSender implements EmailSender {

    private static final Logger log = LoggerFactory.getLogger(JournalEmailSender.class);

    @Override
    public void envoyer(String destinataire, String sujet) {
        log.info("E-mail simulé vers {} : {}", destinataire, sujet);
    }
}

@Service
@RequiredArgsConstructor
public class InscriptionService {

    private final EmailSender emailSender;
    private final Clock clock;

    public String inscrire(String email) {
        LocalDate aujourdhui = LocalDate.now(clock);
        emailSender.envoyer(email, "Inscription confirmée le " + aujourdhui);
        return "Inscription enregistrée";
    }
}
```

Et son test, **sans démarrer Spring** :

```java
class InscriptionServiceTest {

    @Test
    void inscrire_envoieUnEmailDate() {
        List<String> sujets = new ArrayList<>();
        EmailSender factice = (destinataire, sujet) -> sujets.add(sujet);
        Clock horlogeFixe = Clock.fixed(Instant.parse("2026-09-01T10:00:00Z"), ZoneOffset.UTC);

        InscriptionService service = new InscriptionService(factice, horlogeFixe);
        service.inscrire("emma@exemple.fr");

        assertEquals(List.of("Inscription confirmée le 2026-09-01"), sujets);
    }
}
```

`EmailSender` n'ayant qu'une méthode, une lambda suffit à l'implémenter. Le test est rapide, reproductible, et n'envoie aucun e-mail.

## Les erreurs fréquentes

- **Créer ses dépendances avec `new`** dans un service au lieu de les recevoir.
- **`@Autowired` sur les champs**, qui empêche de construire la classe sans Spring.
- **Un état propre à une requête** dans les attributs d'un bean singleton.
- **Placer une classe hors du package de l'application**, et un bean jamais détecté.
- **Des constructeurs à dix paramètres**, signe d'une classe qui en fait trop.

## Retour au besoin

`InscriptionService` ne fabrique plus rien : il déclare ses besoins dans son constructeur, et le conteneur Spring les lui fournit. On peut désormais le tester avec des implémentations factices, changer de fournisseur d'e-mails en ajoutant un bean, et centraliser la configuration. Spring Boot fournit en plus le serveur web, la conversion JSON et l'auto-configuration. Le cours suivant montre comment organiser un projet et sa configuration.

## À retenir

- Spring Boot apporte starters, auto-configuration, serveur embarqué et configuration externalisée.
- Inversion de contrôle : le conteneur crée les beans et injecte leurs dépendances.
- Injection par constructeur, dépendances `final`, sans `@Autowired` sur les champs.
- `@Primary` ou `@Qualifier` quand plusieurs implémentations existent.
- Un bean est un singleton partagé : pas d'état propre à une requête dans ses attributs.

## Pour aller plus loin

- La documentation de Spring Boot : [docs.spring.io/spring-boot](https://docs.spring.io/spring-boot/)
- Le guide officiel pour démarrer : [spring.io/guides](https://spring.io/guides)
