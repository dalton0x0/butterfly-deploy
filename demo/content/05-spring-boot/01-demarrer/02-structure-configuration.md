## Objectifs

- Organiser un projet Spring Boot en couches aux responsabilités claires
- Comprendre la structure d'un projet Maven
- Configurer l'application avec `application.yml` et des variables d'environnement
- Adapter la configuration par environnement avec les profils
- Lire une configuration typée et validée avec `@ConfigurationProperties`
- Journaliser correctement et superviser l'application avec Actuator

## Le besoin

L'API de formations doit fonctionner dans trois environnements :

| Environnement | Base de données | Journaux | Documentation de l'API |
|---------------|-----------------|----------|------------------------|
| Poste du développeur | MySQL local, mot de passe simple | Très détaillés | Visible |
| Recette | Serveur de test | Détaillés | Visible |
| Production | Serveur sécurisé, mot de passe secret | Sobres | Masquée |

Si ces valeurs sont écrites dans le code, il faut **recompiler** pour chaque environnement, et le mot de passe de production finit dans le dépôt Git, visible de tous. Par ailleurs, sans organisation claire, le projet devient un enchevêtrement où les contrôleurs écrivent du SQL et les entités envoient des e-mails.

Il faut donc deux choses : une **architecture** où chaque classe a une place et un rôle précis, et une **configuration externalisée**, qui change selon l'environnement sans toucher au code.

## Définitions

> **Architecture en couches.** Une organisation où l'application est découpée en couches superposées, chacune ne dépendant que de celle du dessous.

> **Configuration externalisée.** Des réglages lus hors du code compilé : fichier de configuration, variables d'environnement, arguments de lancement.

> **Profil.** Un nom d'environnement (`dev`, `prod`...) qui active une configuration particulière.

> **Propriété.** Une valeur de configuration identifiée par une clé hiérarchique : `spring.datasource.url`.

> **Variable d'environnement.** Une valeur définie par le système d'exploitation ou le conteneur Docker, lue par l'application au démarrage.

## L'architecture en couches

Une API Spring Boot s'organise généralement en couches, chacune avec une responsabilité claire :

```text
        Requête HTTP (JSON)
               │
      ┌────────▼────────┐
      │   Contrôleur    │  reçoit, valide, renvoie
      └────────┬────────┘
               │  DTO
      ┌────────▼────────┐
      │     Service     │  règles métier, transactions
      └────────┬────────┘
               │  entités
      ┌────────▼────────┐
      │   Repository    │  accès aux données
      └────────┬────────┘
               │  SQL
           Base MySQL
```

| Couche | Rôle | Ne fait pas |
|--------|------|-------------|
| Contrôleur | Reçoit la requête HTTP, valide l'entrée, renvoie la réponse | Aucune logique métier, aucun SQL |
| Service | Porte la logique métier et les transactions | Ne connaît pas HTTP |
| Repository | Accède à la base de données | Aucune règle métier |
| Entité | Représente une table | Ne sort pas de l'application |
| DTO | Définit ce que l'API reçoit et renvoie | Aucune logique |

Chaque couche ne connaît que celle qui est **juste en dessous**. Cette séparation a des bénéfices concrets :

- une règle métier se trouve toujours au même endroit, dans un service ;
- on peut tester un service sans serveur HTTP, et un contrôleur sans base de données ;
- remplacer MySQL par PostgreSQL ne touche que la couche de persistance.

## La structure d'un projet

Spring Initializr génère un projet **Maven** avec une structure standard :

```text
formations/
  pom.xml                                dépendances et configuration du build
  src/
    main/
      java/fr/exemple/formations/
        FormationsApplication.java       classe principale
        controllers/
        services/
          impl/
        repositories/
        entities/
        dtos/
          request/
          response/
        exceptions/
        configs/
        properties/
      resources/
        application.yml                  configuration commune
        application-dev.yml              configuration du profil dev
        db/migration/                    scripts de migration du schéma
    test/
      java/fr/exemple/formations/        tests
```

Cette organisation par **type technique** est la plus répandue. Sur de gros projets, on rencontre aussi une organisation par **domaine métier** (un package `inscription`, un package `formation`), chacun contenant ses propres couches.

Le fichier `pom.xml` déclare les dépendances :

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-validation</artifactId>
    </dependency>
</dependencies>
```

```bash
./mvnw spring-boot:run      # lancer l'application
./mvnw test                 # lancer les tests
./mvnw package              # produire le fichier target/formations.jar
```

`mvnw` est le **Maven Wrapper** : il télécharge la bonne version de Maven, sans rien installer sur le poste.

## Le fichier application.yml

La configuration vit dans `src/main/resources/application.yml`. Le format YAML représente la hiérarchie des clés par l'**indentation**.

```yaml
server:
  port: 8080

spring:
  application:
    name: formations
  datasource:
    url: jdbc:mysql://${DB_HOST:localhost}:3306/formations
    username: ${DB_USERNAME:formations}
    password: ${DB_PASSWORD}
  jpa:
    open-in-view: false
```

| Syntaxe | Signification |
|---------|---------------|
| `${DB_PASSWORD}` | Lit la variable d'environnement `DB_PASSWORD`. Le démarrage échoue si elle est absente |
| `${DB_HOST:localhost}` | Lit `DB_HOST`, ou utilise `localhost` si elle est absente |

Les **secrets** ne s'écrivent jamais en dur dans un fichier versionné : ils viennent de variables d'environnement, fournies par le poste du développeur, par Docker ou par la plateforme d'hébergement.

On peut aussi utiliser le format `application.properties`, plus ancien, où chaque clé s'écrit sur une ligne : `spring.datasource.url=...`.

## Les profils

Un **profil** active une configuration propre à un environnement. Le fichier `application-dev.yml` **complète et surcharge** `application.yml` quand le profil `dev` est actif.

```text
application.yml         configuration commune à tous les environnements
application-dev.yml     base locale, journaux détaillés, Swagger actif
application-prod.yml    journaux sobres, Swagger désactivé
```

```yaml
# application-dev.yml
logging:
  level:
    fr.exemple.formations: DEBUG
springdoc:
  swagger-ui:
    enabled: true
```

```bash
# Activer un profil au lancement
SPRING_PROFILES_ACTIVE=prod java -jar formations.jar
```

Un bean peut aussi n'exister que dans certains profils :

```java
@Component
@Profile("dev")
public class JournalEmailSender implements EmailSender { ... }   // e-mails simulés en développement
```

## La configuration typée

Pour lire une propriété, on voit souvent `@Value` :

```java
@Value("${formations.inscription.places-maximum}")
private int placesMaximum;
```

Dispersée dans vingt classes, cette approche pose problème : une faute de frappe dans la clé ne se voit qu'au démarrage, les valeurs ne sont pas validées, et il est difficile de savoir quelles propriétés existent.

On regroupe plutôt les propriétés d'un même sujet dans un **record** annoté `@ConfigurationProperties` :

```yaml
formations:
  inscription:
    places-maximum: 20
    delai-annulation: 48h
    seuil-reussite: 0.7
```

```java
@Validated
@ConfigurationProperties(prefix = "formations.inscription")
public record InscriptionProperties(

        @Positive
        int placesMaximum,

        @NotNull
        Duration delaiAnnulation,

        @DecimalMin("0.0") @DecimalMax("1.0")
        double seuilReussite
) {
}
```

```java
@SpringBootApplication
@ConfigurationPropertiesScan
public class FormationsApplication { ... }
```

```java
@Service
@RequiredArgsConstructor
public class InscriptionService {

    private final InscriptionProperties properties;

    public boolean estComplete(int nombreInscrits) {
        return nombreInscrits >= properties.placesMaximum();
    }
}
```

| Avantage | Détail |
|----------|--------|
| Typage | `48h` devient directement une `Duration`, `places-maximum` un `int` |
| Validation au démarrage | `places-maximum: -5` fait échouer le démarrage avec un message clair, au lieu d'un bug en production |
| Regroupement | Toutes les propriétés d'un sujet sont visibles dans un seul fichier |
| Testabilité | Dans un test, on construit simplement `new InscriptionProperties(20, Duration.ofHours(48), 0.7)` |

La clé `places-maximum` (en kebab-case dans le YAML) est associée automatiquement au composant `placesMaximum` : c'est le **relaxed binding** de Spring Boot. La variable d'environnement `FORMATIONS_INSCRIPTION_PLACESMAXIMUM` peut aussi la surcharger.

## Les journaux

Spring Boot fournit **SLF4J** avec **Logback**. Chaque classe déclare son logger, ou utilise l'annotation `@Slf4j` de Lombok.

```java
@Slf4j
@Service
public class InscriptionService {

    public void inscrire(Long apprenantId, Long formationId) {
        log.info("Inscription de l'apprenant id : {} à la formation id : {}", apprenantId, formationId);
        // ...
        log.debug("Places restantes : {}", placesRestantes);
    }
}
```

| Niveau | Usage |
|--------|-------|
| `ERROR` | Une erreur qui empêche une opération |
| `WARN` | Une situation anormale mais gérée |
| `INFO` | Les événements métier importants |
| `DEBUG` | Le détail utile pour diagnostiquer, désactivé en production |

Utilisez les marqueurs `{}` plutôt que la concaténation : le message n'est construit que si le niveau est actif, ce qui évite un calcul inutile. Ne journalisez **jamais** un mot de passe, un jeton ou une donnée personnelle sensible.

## Actuator

Le starter `spring-boot-starter-actuator` expose des points de supervision :

```bash
curl http://localhost:8080/actuator/health
```

```json
{"status":"UP"}
```

`/actuator/health` vérifie que l'application et ses dépendances, comme la base de données, répondent. C'est ce point que consultent Docker ou Kubernetes pour savoir si un conteneur est sain, et le redémarrer sinon. Les autres points (`metrics`, `info`, `env`) doivent être exposés avec prudence : certains révèlent des informations sensibles.

## Exemple complet

Configuration d'une API qui fonctionne en local sans aucune variable, et en production avec des secrets injectés :

```yaml
# application.yml
spring:
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:dev}
  datasource:
    url: jdbc:mysql://${DB_HOST:localhost}:${DB_PORT:3306}/${DB_NAME:formations}
    username: ${DB_USERNAME:root}
    password: ${DB_PASSWORD:}

formations:
  inscription:
    places-maximum: ${INSCRIPTION_PLACES_MAXIMUM:20}
    delai-annulation: 48h
    seuil-reussite: 0.7

management:
  endpoints:
    web:
      exposure:
        include: health
```

```yaml
# application-prod.yml
logging:
  level:
    root: WARN
    fr.exemple.formations: INFO
springdoc:
  swagger-ui:
    enabled: false
```

```bash
# Production, par exemple dans un conteneur Docker
SPRING_PROFILES_ACTIVE=prod
DB_HOST=mysql
DB_PASSWORD=un-secret-fourni-par-la-plateforme
INSCRIPTION_PLACES_MAXIMUM=30
```

Le même fichier `formations.jar` tourne dans les trois environnements. Seules les variables changent.

## Les erreurs fréquentes

- **Un mot de passe en dur** dans `application.yml`, versionné dans Git.
- **Des `@Value` dispersés** au lieu d'un record de propriétés.
- **Une erreur d'indentation YAML**, et une propriété ignorée sans message.
- **De la logique métier dans un contrôleur**, ou des requêtes SQL dans un service.
- **Journaliser des données sensibles**, ou concaténer les messages de journal.
- **Exposer tous les points Actuator** sur Internet.

## Retour au besoin

Chaque classe a désormais sa place : les contrôleurs parlent HTTP, les services portent les règles, les repositories accèdent aux données. La configuration est externalisée : le même fichier `.jar` fonctionne sur le poste du développeur et en production, et les secrets ne quittent jamais l'environnement qui les fournit. Les propriétés typées font échouer le démarrage au moindre réglage invalide, bien avant qu'un utilisateur ne soit affecté.

## À retenir

- Contrôleur, service, repository : une responsabilité par couche, chacune ne connaît que celle du dessous.
- Les secrets viennent de variables d'environnement, avec `${VARIABLE:defaut}`.
- Un profil par environnement, qui complète la configuration commune.
- `@ConfigurationProperties` avec un record : une configuration typée, regroupée et validée au démarrage.
- Des journaux avec `{}`, sans donnée sensible, et `/actuator/health` pour la supervision.

## Pour aller plus loin

- La configuration externalisée dans la documentation officielle : [docs.spring.io/spring-boot/reference/features/external-config.html](https://docs.spring.io/spring-boot/reference/features/external-config.html)
