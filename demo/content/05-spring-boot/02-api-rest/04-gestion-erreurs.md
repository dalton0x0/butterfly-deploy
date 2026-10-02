## Objectifs

- Comprendre pourquoi une gestion des erreurs dispersée pose problème
- Créer des exceptions métier explicites, indépendantes de HTTP
- Centraliser leur traduction en réponses HTTP avec `@RestControllerAdvice`
- Renvoyer des erreurs de validation exploitables par le front
- Ne jamais exposer de détail technique au client
- Connaître le format standard `ProblemDetail`

## Le besoin

Sans organisation, chaque contrôleur gère ses erreurs à sa manière :

```java
@GetMapping("/{id}")
public ResponseEntity<?> lire(@PathVariable Long id) {
    try {
        return ResponseEntity.ok(formationService.lire(id));
    } catch (NoSuchElementException e) {
        return ResponseEntity.status(404).body("Formation introuvable");
    } catch (Exception e) {
        return ResponseEntity.status(500).body(e.getMessage());
    }
}
```

Recopié dans cinquante méthodes, ce code produit :

- des **formats différents** selon l'endpoint : parfois un texte, parfois un objet, parfois rien. Le front doit gérer chaque cas ;
- des **fuites d'informations** : le message d'une exception technique peut contenir une requête SQL ou un nom de table ;
- du **code répétitif** qui noie la logique utile ;
- des **oublis** : un endpoint sans `try-catch` renvoie la page d'erreur par défaut.

Il faut un endroit **unique** qui traduit chaque situation d'erreur en réponse HTTP, toujours au même format, et un vocabulaire d'exceptions qui décrit les problèmes métier.

## Définitions

> **Exception métier.** Une exception qui décrit un problème du domaine : ressource introuvable, doublon, règle violée. Elle ne connaît rien de HTTP.

> **Gestionnaire global d'exceptions.** Une classe qui intercepte les exceptions levées par tous les contrôleurs et les transforme en réponses HTTP.

> **Format d'erreur.** La structure JSON commune à toutes les réponses d'erreur de l'API.

> **ProblemDetail.** Un format standard de réponse d'erreur HTTP, décrit par la RFC 9457, supporté nativement par Spring.

## Des exceptions métier

Le service signale un problème en levant une exception **qui décrit le problème**, sans rien savoir de HTTP :

```java
public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String ressource, Long id) {
        super(ressource + " introuvable avec l'identifiant " + id);
    }
}

public class DuplicateResourceException extends RuntimeException {

    public DuplicateResourceException(String message) {
        super(message);
    }
}

public class BusinessRuleException extends RuntimeException {

    public BusinessRuleException(String message) {
        super(message);
    }
}
```

```java
@Transactional(readOnly = true)
public FormationResponse lire(Long id) {
    return formationRepository.findById(id)
            .map(FormationResponse::fromEntity)
            .orElseThrow(() -> new ResourceNotFoundException("Formation", id));
}
```

Ces exceptions héritent de `RuntimeException` : non vérifiées, elles traversent les couches sans obliger chaque méthode à les déclarer, et elles déclenchent l'annulation de la transaction en cours.

Le service reste indépendant de HTTP : on pourrait l'appeler depuis un traitement par lots ou un message, et l'exception garderait tout son sens.

## Le gestionnaire global

Une classe annotée `@RestControllerAdvice` intercepte les exceptions levées par **tous** les contrôleurs. Chaque méthode `@ExceptionHandler` traite un type d'exception.

```java
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleNotFound(ResourceNotFoundException ex, HttpServletRequest request) {
        return build(HttpStatus.NOT_FOUND, ex.getMessage(), request, null);
    }

    @ExceptionHandler(DuplicateResourceException.class)
    public ResponseEntity<ErrorResponse> handleDuplicate(DuplicateResourceException ex, HttpServletRequest request) {
        return build(HttpStatus.CONFLICT, ex.getMessage(), request, null);
    }

    @ExceptionHandler(BusinessRuleException.class)
    public ResponseEntity<ErrorResponse> handleBusinessRule(BusinessRuleException ex, HttpServletRequest request) {
        return build(HttpStatus.CONFLICT, ex.getMessage(), request, null);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        Map<String, String> erreurs = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors()
                .forEach(erreur -> erreurs.putIfAbsent(erreur.getField(), erreur.getDefaultMessage()));
        return build(HttpStatus.BAD_REQUEST, "Données invalides", request, erreurs);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleUnexpected(Exception ex, HttpServletRequest request) {
        log.error("Erreur inattendue sur {}", request.getRequestURI(), ex);
        return build(HttpStatus.INTERNAL_SERVER_ERROR, "Une erreur interne est survenue", request, null);
    }

    private ResponseEntity<ErrorResponse> build(HttpStatus status, String message,
                                                HttpServletRequest request, Map<String, String> erreurs) {
        ErrorResponse body = new ErrorResponse(status.value(), status.getReasonPhrase(), message,
                request.getRequestURI(), LocalDateTime.now(), erreurs);
        return ResponseEntity.status(status).body(body);
    }
}
```

```java
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ErrorResponse(int status, String error, String message, String path,
                            LocalDateTime timestamp, Map<String, String> validationErrors) {
}
```

| Exception | Statut | Situation |
|-----------|--------|-----------|
| `MethodArgumentNotValidException` | 400 | Un DTO ne respecte pas ses contraintes |
| `ResourceNotFoundException` | 404 | La ressource demandée n'existe pas |
| `DuplicateResourceException` | 409 | Un doublon sur une donnée unique |
| `BusinessRuleException` | 409 | Une règle métier empêche l'opération |
| `Exception` | 500 | Tout le reste : le filet de sécurité |

Spring choisit le gestionnaire le **plus précis** : une `ResourceNotFoundException` est traitée par son gestionnaire dédié, pas par celui de `Exception`.

`@JsonInclude(NON_NULL)` omet les champs `null` du JSON : `validationErrors` n'apparaît que pour les erreurs de validation.

## Les réponses obtenues

Une validation échouée :

```json
{
  "status": 400,
  "error": "Bad Request",
  "message": "Données invalides",
  "path": "/api/formations",
  "timestamp": "2026-09-30T14:32:10",
  "validationErrors": {
    "titre": "Le titre est obligatoire",
    "prix": "Le prix ne peut pas être négatif"
  }
}
```

Une ressource introuvable :

```json
{
  "status": 404,
  "error": "Not Found",
  "message": "Formation introuvable avec l'identifiant 999",
  "path": "/api/formations/999",
  "timestamp": "2026-09-30T14:33:02"
}
```

Toutes les erreurs de l'API ont la **même structure**. Le front écrit un seul intercepteur : il lit `status`, affiche `message`, et place chaque entrée de `validationErrors` sous le champ du formulaire correspondant.

## Ne rien laisser fuiter

Le gestionnaire de `Exception` sert de **filet de sécurité**. Il fait deux choses distinctes :

- il **journalise** l'erreur complète côté serveur, trace de pile comprise, pour que l'équipe puisse diagnostiquer ;
- il renvoie au client un **message générique**.

Une trace de pile ou un message SQL renvoyé au client révélerait la structure interne de l'application : noms de classes, de tables, versions des bibliothèques. Autant d'indices pour un attaquant.

## Les contrôleurs redeviennent simples

```java
@GetMapping("/{id}")
public FormationResponse lire(@PathVariable Long id) {
    return formationService.lire(id);
}
```

Plus aucun `try-catch` : si le service lève une exception, le gestionnaire global s'en charge. Le contrôleur ne décrit plus que le **cas nominal**.

## ProblemDetail

Spring fournit aussi la classe `ProblemDetail`, qui suit le format standard des erreurs HTTP décrit par la **RFC 9457** :

```java
@ExceptionHandler(ResourceNotFoundException.class)
public ProblemDetail handleNotFound(ResourceNotFoundException ex) {
    ProblemDetail probleme = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
    probleme.setTitle("Ressource introuvable");
    return probleme;
}
```

```json
{
  "type": "about:blank",
  "title": "Ressource introuvable",
  "status": 404,
  "detail": "Formation introuvable avec l'identifiant 999",
  "instance": "/api/formations/999"
}
```

C'est une alternative intéressante à un format maison, surtout pour une API publique consommée par des clients variés qui connaissent ce standard. L'important est de choisir **un** format et de s'y tenir partout.

## Une exception par situation métier

Une exception générique qui porte un code HTTP semble pratique :

```java
throw new ApiException(HttpStatus.CONFLICT, "Formation complète");   // à éviter
```

Mais elle mélange les responsabilités : le **service** choisit un code HTTP, alors qu'il ne devrait rien savoir du web. Préférez des exceptions nommées d'après le **problème métier**, et laissez le gestionnaire global décider du statut. Si un jour une règle doit renvoyer 422 au lieu de 409, on ne modifie qu'une ligne du gestionnaire.

## Exemple complet

Une inscription refusée parce que la formation est complète, du service à la réponse :

```java
public class FormationCompleteException extends RuntimeException {

    public FormationCompleteException(String titre, int capacite) {
        super("La formation " + titre + " est complète (" + capacite + " places)");
    }
}
```

```java
@Transactional
public InscriptionResponse inscrire(Long formationId, Long apprenantId) {
    Formation formation = formationRepository.findById(formationId)
            .orElseThrow(() -> new ResourceNotFoundException("Formation", formationId));

    if (inscriptionRepository.countByFormationId(formationId) >= formation.getCapacite()) {
        throw new FormationCompleteException(formation.getTitre(), formation.getCapacite());
    }
    // ...
}
```

```java
@ExceptionHandler(FormationCompleteException.class)
public ResponseEntity<ErrorResponse> handleComplete(FormationCompleteException ex, HttpServletRequest request) {
    return build(HttpStatus.CONFLICT, ex.getMessage(), request, null);
}
```

```json
{
  "status": 409,
  "error": "Conflict",
  "message": "La formation Spring Boot est complète (20 places)",
  "path": "/api/formations/3/inscriptions",
  "timestamp": "2026-09-30T15:01:44"
}
```

Le front affiche directement le message à l'apprenant. Le service n'a jamais manipulé de code HTTP.

## Les erreurs fréquentes

- **Des `try-catch` dans chaque contrôleur** au lieu d'un gestionnaire global.
- **Renvoyer `ex.getMessage()` d'une exception inattendue** au client.
- **Oublier de journaliser** dans le gestionnaire de `Exception`, et des erreurs 500 impossibles à diagnostiquer.
- **Un statut HTTP choisi dans le service.**
- **Des formats d'erreur différents** selon les endpoints.

## Retour au besoin

Toutes les erreurs de l'API ont désormais la même forme, et le front les traite avec un seul intercepteur. Les exceptions inattendues sont journalisées en détail côté serveur et masquées au client. Les contrôleurs ne contiennent plus que le cas nominal, et les services décrivent les problèmes en termes métier. L'API est à la fois plus simple à écrire, plus agréable à consommer et plus sûre.

## À retenir

- Le service lève des exceptions métier nommées, sans rien savoir de HTTP.
- `@RestControllerAdvice` traduit chaque exception en réponse, au même format partout.
- Les erreurs de validation sont renvoyées champ par champ.
- Une erreur inattendue est journalisée en détail et masquée au client.
- Un format d'erreur unique, maison ou `ProblemDetail`, appliqué à toute l'API.

## Pour aller plus loin

- La gestion des erreurs dans la documentation de Spring : [docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-rest-exceptions.html](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-rest-exceptions.html)
