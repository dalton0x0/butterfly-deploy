## Objectifs

- Comprendre ce qu'est une API REST et pourquoi on sépare le front du back
- Concevoir des URL et utiliser les verbes HTTP selon les conventions REST
- Renvoyer les bons codes de statut
- Écrire un contrôleur REST avec Spring et lire ses annotations
- Paginer et filtrer une liste
- Documenter l'API avec OpenAPI

## Le besoin

L'organisme de formation veut trois interfaces : un site web en Vue.js, une application mobile, et un export vers l'outil de facturation d'un partenaire. Toutes ont besoin des **mêmes données** : le catalogue, les inscriptions, les notes.

Si chaque interface accède directement à la base de données, les règles métier (« une formation complète refuse une inscription ») sont recopiées trois fois, en trois langages, et la base est exposée à trois applications. La solution consiste à placer entre elles et la base un **serveur unique** qui détient les règles et expose les données dans un format neutre. C'est une **API**.

Encore faut-il que cette API soit **prévisible** : si chaque développeur invente ses URL (`/getFormations`, `/formation/delete?id=3`, `/api/inscrire`), les clients doivent tout deviner. Les conventions REST apportent ce vocabulaire commun.

## Définitions

> **API (Application Programming Interface).** Un ensemble de points d'entrée qu'une application met à disposition d'autres programmes.

> **REST (Representational State Transfer).** Un style d'architecture pour les API web, qui s'appuie sur les mécanismes de HTTP : des ressources identifiées par des URL, manipulées par les verbes HTTP.

> **Ressource.** Une entité du domaine exposée par l'API : une formation, une inscription, un apprenant.

> **Représentation.** La forme sous laquelle une ressource est échangée, le plus souvent du JSON.

> **Endpoint (point d'entrée).** Une combinaison d'un verbe HTTP et d'une URL : `GET /api/formations`.

> **Sans état (stateless).** Chaque requête contient tout ce qu'il faut pour être traitée. Le serveur ne garde pas de session entre deux appels.

## Le JSON

Les API échangent le plus souvent du **JSON** (JavaScript Object Notation), un format texte lisible par l'humain et par tous les langages :

```json
{
  "id": 1,
  "titre": "Java",
  "dureeHeures": 70,
  "prix": 1200.00,
  "publiee": true,
  "modules": ["Bases", "POO", "Collections"]
}
```

Spring Boot convertit automatiquement les objets Java en JSON et inversement, grâce à la bibliothèque **Jackson** incluse dans le starter web.

## Concevoir les URL et les verbes

Une API REST expose des **ressources** identifiées par des URL. Le **verbe HTTP** indique l'action à réaliser sur la ressource.

| Verbe | URL | Action | Statut en cas de succès |
|-------|-----|--------|-------------------------|
| `GET` | `/api/formations` | Lister | 200 OK |
| `GET` | `/api/formations/42` | Lire une formation | 200 OK |
| `POST` | `/api/formations` | Créer | 201 Created |
| `PUT` | `/api/formations/42` | Remplacer entièrement | 200 OK |
| `PATCH` | `/api/formations/42` | Modifier partiellement | 200 OK |
| `DELETE` | `/api/formations/42` | Supprimer | 204 No Content |

Bonnes pratiques de nommage :

| Règle | À éviter | À préférer |
|-------|----------|------------|
| Des **noms** au pluriel, pas de verbe | `/api/getFormations` | `GET /api/formations` |
| Le verbe HTTP porte l'action | `POST /api/formations/delete/42` | `DELETE /api/formations/42` |
| Des sous-ressources pour une appartenance | `/api/inscriptions?formation=42` | `/api/formations/42/inscriptions` |
| Des paramètres pour filtrer, trier, paginer | `/api/formationsDebutant` | `/api/formations?niveau=DEBUTANT&page=0` |

Deux propriétés importantes des verbes :

| Verbe | Sûr (ne modifie rien) | Idempotent (le répéter donne le même résultat) |
|-------|-----------------------|------------------------------------------------|
| `GET` | Oui | Oui |
| `PUT` | Non | Oui : remplacer deux fois par la même valeur donne le même état |
| `DELETE` | Non | Oui : supprimer deux fois laisse la ressource supprimée |
| `POST` | Non | **Non** : deux envois créent deux ressources |

C'est pourquoi un client peut rejouer sans crainte un `GET` ou un `PUT` après une coupure réseau, mais pas un `POST`.

## Les codes de statut

Le code de statut est la **première information** que lit le client. Il doit refléter exactement ce qui s'est passé.

| Code | Signification | Exemple |
|------|---------------|---------|
| 200 | Succès | Lecture d'une formation |
| 201 | Ressource créée | Création d'une formation, avec l'en-tête `Location` |
| 204 | Succès sans contenu | Suppression |
| 400 | Requête invalide | Titre vide, prix négatif |
| 401 | Non authentifié | Jeton absent ou expiré |
| 403 | Authentifié mais pas autorisé | Un apprenant tente de supprimer une formation |
| 404 | Ressource introuvable | Formation 999 inexistante |
| 409 | Conflit avec l'état actuel | Titre déjà utilisé, formation complète |
| 500 | Erreur interne du serveur | Exception imprévue |

Renvoyer 200 avec un corps `{"erreur": true}` prive le client d'une information essentielle. Avec un code juste, le front peut réagir sans analyser le corps : rediriger vers la connexion sur 401, afficher les erreurs du formulaire sur 400.

## Un contrôleur REST

```java
@RestController
@RequestMapping("/api/formations")
@RequiredArgsConstructor
public class FormationController {

    private final FormationService formationService;

    @GetMapping
    public Page<FormationResponse> lister(
            @RequestParam(required = false) Niveau niveau,
            @PageableDefault(size = 20, sort = "titre") Pageable pageable) {
        return formationService.lister(niveau, pageable);
    }

    @GetMapping("/{id}")
    public FormationResponse lire(@PathVariable Long id) {
        return formationService.lire(id);
    }

    @PostMapping
    public ResponseEntity<FormationResponse> creer(@Valid @RequestBody FormationRequest request) {
        FormationResponse creee = formationService.creer(request);
        URI emplacement = URI.create("/api/formations/" + creee.id());
        return ResponseEntity.created(emplacement).body(creee);
    }

    @PutMapping("/{id}")
    public FormationResponse modifier(@PathVariable Long id, @Valid @RequestBody FormationRequest request) {
        return formationService.modifier(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void supprimer(@PathVariable Long id) {
        formationService.supprimer(id);
    }
}
```

| Annotation | Rôle |
|------------|------|
| `@RestController` | La classe est un contrôleur, et les valeurs renvoyées sont converties en JSON |
| `@RequestMapping("/api/formations")` | Préfixe commun à toutes les URL du contrôleur |
| `@GetMapping`, `@PostMapping`... | Associe une méthode à un verbe et, éventuellement, à un complément d'URL |
| `@PathVariable` | Lit un segment de l'URL : `/api/formations/42` donne `id = 42` |
| `@RequestParam` | Lit un paramètre de requête : `?niveau=DEBUTANT` |
| `@RequestBody` | Convertit le corps JSON de la requête en objet Java |
| `@Valid` | Déclenche la validation de l'objet reçu (voir le cours suivant) |
| `ResponseEntity` | Contrôle le statut, les en-têtes et le corps de la réponse |
| `@ResponseStatus` | Fixe le statut quand la méthode ne renvoie rien |

Spring **convertit automatiquement** les paramètres : `id` devient un `Long`, `niveau` une valeur de l'énumération. Une valeur non convertible, comme `/api/formations/abc`, produit une erreur 400.

## Ce qui se passe lors d'une requête

```text
POST /api/formations   {"titre": "Docker", ...}
  │
  ├─ 1. Spring trouve la méthode creer() grâce à @PostMapping
  ├─ 2. Jackson convertit le JSON en FormationRequest
  ├─ 3. @Valid vérifie les contraintes : erreur 400 si invalide
  ├─ 4. creer() appelle le service, qui applique les règles métier
  ├─ 5. Jackson convertit FormationResponse en JSON
  └─ 6. Réponse 201 Created, en-tête Location: /api/formations/8
```

Le contrôleur reste **mince** : il reçoit, délègue au service et renvoie. Il ne contient aucune règle métier et n'accède jamais directement au repository. Toute la logique testable vit dans le service.

## La pagination

Une liste ne doit **jamais** renvoyer une table entière : avec 100 000 formations, la réponse ferait plusieurs mégaoctets et saturerait le serveur. Spring convertit automatiquement les paramètres `page`, `size` et `sort` en objet `Pageable` :

```text
GET /api/formations?page=1&size=10&sort=prix,desc
```

- `page` commence à **0** ;
- `size` fixe le nombre d'éléments par page ;
- `sort=prix,desc` trie par prix décroissant, et peut être répété pour plusieurs critères.

Plafonnez la taille de page acceptée avec la propriété `spring.data.web.pageable.max-page-size` : sans elle, un client peut demander des milliers d'éléments en une seule requête.

Renvoyer directement l'objet `Page` de Spring expose une structure JSON verbeuse et qui n'est pas garantie stable d'une version à l'autre. Beaucoup d'API l'enveloppent dans un DTO de pagination qui ne garde que l'essentiel :

```java
public record PageResponse<T>(List<T> content, long totalElements, int totalPages,
                              int number, int size, boolean first, boolean last) {

    public static <T> PageResponse<T> fromPage(Page<T> page) {
        return new PageResponse<>(page.getContent(), page.getTotalElements(), page.getTotalPages(),
                page.getNumber(), page.getSize(), page.isFirst(), page.isLast());
    }
}
```

## Documenter l'API

Un client de l'API doit savoir quels endpoints existent, ce qu'ils attendent et ce qu'ils renvoient. La bibliothèque **springdoc-openapi** génère automatiquement une documentation au format **OpenAPI** à partir des contrôleurs, et une interface **Swagger UI** où l'on peut tester chaque endpoint depuis le navigateur.

```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>...</version>
</dependency>
```

L'interface est alors disponible sur `/swagger-ui.html`. On la désactive généralement en production, ou on la protège.

## Exemple complet

Un endpoint de sous-ressource, qui liste les inscriptions d'une formation et en crée une :

```java
@RestController
@RequestMapping("/api/formations/{formationId}/inscriptions")
@RequiredArgsConstructor
public class InscriptionController {

    private final InscriptionService inscriptionService;

    @GetMapping
    public PageResponse<InscriptionResponse> lister(
            @PathVariable Long formationId,
            @PageableDefault(size = 20, sort = "inscritLe") Pageable pageable) {
        return PageResponse.fromPage(inscriptionService.listerParFormation(formationId, pageable));
    }

    @PostMapping
    public ResponseEntity<InscriptionResponse> inscrire(
            @PathVariable Long formationId,
            @Valid @RequestBody InscriptionRequest request) {
        InscriptionResponse inscription = inscriptionService.inscrire(formationId, request.apprenantId());
        URI emplacement = URI.create("/api/formations/" + formationId + "/inscriptions/" + inscription.id());
        return ResponseEntity.created(emplacement).body(inscription);
    }
}
```

```bash
curl -X POST http://localhost:8080/api/formations/3/inscriptions \
     -H "Content-Type: application/json" \
     -d '{"apprenantId": 12}'
```

```text
HTTP/1.1 201 Created
Location: /api/formations/3/inscriptions/57
Content-Type: application/json

{"id":57,"apprenant":"Emma Petit","formation":"Spring Boot","inscritLe":"2026-09-30"}
```

## Les erreurs fréquentes

- **Des verbes dans les URL** : `/api/createFormation`.
- **Modifier des données avec `GET`.**
- **Un code 200 pour tout**, y compris les erreurs.
- **De la logique métier dans le contrôleur**, ou un repository injecté directement.
- **Une liste non paginée**, ou une taille de page sans plafond.
- **Oublier `@RequestBody`**, et un objet reçu entièrement vide.

## Retour au besoin

Le site web, l'application mobile et l'outil du partenaire consomment désormais la même API. Les règles métier ne sont écrites qu'une fois, côté serveur. Et grâce aux conventions REST, un développeur qui découvre l'API devine immédiatement que `DELETE /api/formations/42` supprime la formation 42, et qu'une réponse 409 signale un conflit. La documentation OpenAPI complète ce contrat. Il reste à définir précisément ce que l'API reçoit et renvoie, et à valider les données : c'est l'objet du cours suivant.

## À retenir

- Des noms de ressources au pluriel, le verbe HTTP pour l'action.
- Un code de statut juste pour chaque situation : 201 à la création, 204 à la suppression, 4xx pour les erreurs du client.
- Un contrôleur mince qui reçoit, délègue au service et renvoie.
- Toute liste est paginée, avec une taille maximale.
- OpenAPI et Swagger UI documentent l'API à partir du code.

## Pour aller plus loin

- Le guide officiel « Building a RESTful Web Service » : [spring.io/guides/gs/rest-service](https://spring.io/guides/gs/rest-service)
- Les codes de statut HTTP sur MDN : [developer.mozilla.org/fr/docs/Web/HTTP/Status](https://developer.mozilla.org/fr/docs/Web/HTTP/Status)
