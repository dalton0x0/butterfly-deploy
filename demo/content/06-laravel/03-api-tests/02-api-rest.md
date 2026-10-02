## Objectifs

- Comprendre en quoi une API diffère d'un site rendu par le serveur
- Installer et déclarer des routes d'API
- Formater les réponses avec les API Resources
- Écrire un contrôleur d'API avec les bons codes de statut
- Paginer et filtrer une collection
- Authentifier les appels avec Sanctum et limiter le débit

## Le besoin

L'organisme de formation lance une **application mobile**, et un front en **Vue.js** pour son site. Ces clients n'ont que faire de pages HTML générées par Blade : ils veulent des **données**, en JSON, qu'ils afficheront eux-mêmes.

Ils ont aussi des contraintes différentes d'un navigateur classique :

- une application mobile ne gère pas les cookies de session comme un navigateur : elle a besoin d'un **jeton** à présenter à chaque appel ;
- les erreurs doivent arriver en **JSON**, avec un code de statut exploitable, et non sous forme de redirection vers une page ;
- renvoyer directement un modèle Eloquent exposerait **toutes** ses colonnes, y compris des informations internes ;
- le client mobile ne doit pas pouvoir **surcharger** le serveur en envoyant des milliers de requêtes.

Laravel fournit les outils pour construire une API REST propre : des routes dédiées, des API Resources pour maîtriser les réponses, et Sanctum pour l'authentification.

## Définitions

> **API REST.** Une interface qui expose des ressources par des URL et les manipule avec les verbes HTTP, en échangeant du JSON. Les principes sont les mêmes que dans le bloc Spring Boot.

> **API Resource.** Une classe qui transforme un modèle en tableau JSON, en choisissant précisément les champs exposés.

> **Sanctum.** Le système d'authentification léger de Laravel, pour les API : par jetons ou par cookie de session pour un front sur le même domaine.

> **Jeton d'API (token).** Une chaîne secrète remise au client à la connexion, qu'il présente à chaque requête dans l'en-tête `Authorization`.

> **Limitation de débit (rate limiting).** Le plafonnement du nombre de requêtes qu'un client peut envoyer sur une période.

## Les routes d'API

Les projets Laravel récents n'incluent pas les routes d'API par défaut. Une commande les installe avec Sanctum :

```bash
php artisan install:api
```

Elle crée le fichier `routes/api.php`, dont toutes les routes sont préfixées par `/api`. Ces routes ne passent pas par la session ni par la protection CSRF, qui n'ont pas de sens pour un client authentifié par jeton.

```php
use App\Http\Controllers\Api\FormationController;
use Illuminate\Support\Facades\Route;

Route::apiResource('formations', FormationController::class);
```

`apiResource` déclare les **cinq** routes utiles à une API, sans les pages de formulaire `create` et `edit` :

| Verbe | URL | Méthode | Statut en cas de succès |
|-------|-----|---------|-------------------------|
| GET | `/api/formations` | `index` | 200 |
| POST | `/api/formations` | `store` | 201 |
| GET | `/api/formations/{formation}` | `show` | 200 |
| PUT/PATCH | `/api/formations/{formation}` | `update` | 200 |
| DELETE | `/api/formations/{formation}` | `destroy` | 204 |

## Les API Resources

Comme les DTO en Spring, une **API Resource** définit ce que l'API renvoie. On n'expose jamais un modèle tel quel : ses colonnes internes et ses champs sensibles partiraient dans la réponse, et renommer une colonne casserait le contrat avec les clients.

```bash
php artisan make:resource FormationResource
```

```php
namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class FormationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'titre' => $this->titre,
            'slug' => $this->slug,
            'dureeHeures' => $this->duree_heures,
            'prix' => $this->prix,
            'niveau' => $this->niveau->value,
            'categorie' => new CategorieResource($this->whenLoaded('categorie')),
            'nombreInscrits' => $this->whenCounted('apprenants'),
            'creeLe' => $this->created_at->toIso8601String(),
        ];
    }
}
```

| Élément | Rôle |
|---------|------|
| `$this->titre` | Accède aux attributs du modèle enveloppé |
| Les clés du tableau | Le contrat de l'API, indépendant des noms de colonnes : `dureeHeures` pour `duree_heures` |
| `whenLoaded('categorie')` | N'inclut la relation que si elle a été chargée avec `with()` |
| `whenCounted('apprenants')` | N'inclut le compteur que si `withCount` a été utilisé |
| `toIso8601String()` | Une date dans un format standard, facile à lire pour tous les clients |

`whenLoaded` est essentiel : la Resource ne déclenche **jamais** de requête cachée. C'est le contrôleur qui décide explicitement ce qui est chargé, et donc ce qui apparaît dans la réponse.

Pour une collection :

```php
return FormationResource::collection($formations);
```

## Le contrôleur d'API

```php
namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreFormationRequest;
use App\Http\Resources\FormationResource;
use App\Models\Formation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Gate;

class FormationController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $formations = Formation::publiees()
            ->with('categorie')
            ->withCount('apprenants')
            ->when($request->query('niveau'), fn ($query, $niveau) => $query->where('niveau', $niveau))
            ->orderBy('titre')
            ->paginate(20);

        return FormationResource::collection($formations);
    }

    public function store(StoreFormationRequest $request): JsonResponse
    {
        $formation = Formation::create($request->validated());

        return (new FormationResource($formation->load('categorie')))
            ->response()
            ->setStatusCode(201);
    }

    public function show(Formation $formation): FormationResource
    {
        return new FormationResource($formation->load('categorie')->loadCount('apprenants'));
    }

    public function destroy(Formation $formation): Response
    {
        Gate::authorize('delete', $formation);
        $formation->delete();

        return response()->noContent();
    }
}
```

On retrouve tout ce qui a été vu jusqu'ici, dans un contexte d'API :

- la **liaison de modèle** renvoie 404 pour une formation inexistante ;
- la **Form Request** valide et autorise avant l'appel du contrôleur ;
- la **policy** protège la suppression ;
- `with` et `withCount` évitent le **N+1** ;
- les **codes de statut** suivent les conventions REST : 201 à la création, 204 à la suppression.

## La pagination

Une collection paginée ajoute automatiquement les blocs `links` et `meta` à la réponse :

```json
{
  "data": [
    {"id": 1, "titre": "Java", "dureeHeures": 70, "prix": "1200.00", "niveau": "debutant"}
  ],
  "links": {
    "first": "http://localhost/api/formations?page=1",
    "next": "http://localhost/api/formations?page=2"
  },
  "meta": {
    "current_page": 1,
    "per_page": 20,
    "total": 42
  }
}
```

Le client connaît ainsi le nombre total d'éléments et l'URL de la page suivante, sans rien calculer.

## Les erreurs en JSON

Pour une requête d'API, Laravel renvoie les erreurs en JSON avec le bon statut :

| Situation | Statut |
|-----------|--------|
| Validation échouée | 422, avec les erreurs par champ |
| Ressource introuvable (liaison de modèle, `findOrFail`) | 404 |
| Non authentifié | 401 |
| Action refusée par une policy | 403 |
| Trop de requêtes | 429 |

```json
{
  "message": "The titre field is required.",
  "errors": {
    "titre": ["The titre field is required."]
  }
}
```

Le client doit envoyer l'en-tête `Accept: application/json` pour que Laravel choisisse ce format plutôt qu'une redirection. Les routes de `routes/api.php` le font généralement pour vous, mais un client mal configuré peut recevoir une redirection inattendue : c'est la première chose à vérifier.

## Sanctum

Sanctum propose deux modes d'authentification :

| Mode | Usage | Fonctionnement |
|------|-------|----------------|
| Cookie de session | Un front (Vue, React) servi sur le même domaine que l'API | La session classique de Laravel, protégée contre le CSRF |
| Jetons d'API | Une application mobile, un script, un client externe | Un jeton présenté à chaque requête |

Pour une application mobile, le jeton est émis à la connexion :

```php
Route::post('/login', function (Request $request) {
    $identifiants = $request->validate([
        'email' => ['required', 'email'],
        'password' => ['required'],
        'appareil' => ['required', 'string', 'max:100'],
    ]);

    $user = User::where('email', $identifiants['email'])->first();

    if (! $user || ! Hash::check($identifiants['password'], $user->password)) {
        return response()->json(['message' => 'Identifiants incorrects.'], 401);
    }

    return ['token' => $user->createToken($identifiants['appareil'])->plainTextToken];
})->middleware('throttle:5,1');
```

Le client transmet ensuite le jeton dans l'en-tête `Authorization` :

```text
GET /api/me/formations
Authorization: Bearer 1|aB3dE5fG7hI9jK...
Accept: application/json
```

Et les routes sont protégées par le middleware `auth:sanctum` :

```php
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me/formations', MesFormationsController::class);
    Route::apiResource('formations', FormationController::class)->except(['index', 'show']);
});
```

Sanctum ne stocke en base qu'une **empreinte** du jeton, comme pour un mot de passe : un vol de la base ne livre aucun jeton utilisable. La valeur complète n'est visible qu'**une seule fois**, à sa création. Chaque appareil reçoit son propre jeton, et `$user->tokens()->delete()` déconnecte tous les appareils.

## Limiter le débit

Le middleware `throttle` limite le nombre de requêtes sur une période. Au-delà, Laravel répond **429 Too Many Requests**.

```php
Route::post('/login', LoginController::class)->middleware('throttle:5,1');   // 5 essais par minute
```

Il protège en particulier la connexion contre la **force brute** : un attaquant ne peut plus tester des milliers de mots de passe. Des limites plus fines, par utilisateur ou par adresse IP, se définissent avec la façade `RateLimiter`.

## Exemple complet

L'endpoint qui liste les formations de l'apprenant connecté, avec sa note :

```php
class InscriptionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'formation' => new FormationResource($this->resource),
            'inscritLe' => $this->pivot->created_at->toDateString(),
            'noteFinale' => $this->pivot->note_finale,
        ];
    }
}
```

```php
class MesFormationsController extends Controller
{
    public function __invoke(Request $request): AnonymousResourceCollection
    {
        $formations = $request->user()
            ->formations()
            ->with('categorie')
            ->orderByPivot('created_at', 'desc')
            ->paginate(20);

        return InscriptionResource::collection($formations);
    }
}
```

```text
GET /api/me/formations        Authorization: Bearer ...

200 OK
{"data": [{"formation": {"id": 3, "titre": "Spring Boot", ...}, "inscritLe": "2026-03-02", "noteFinale": null}], ...}
```

`$request->user()->formations()` limite naturellement la requête aux formations de l'utilisateur connecté : aucune faille IDOR possible. Un contrôleur avec une seule méthode `__invoke` est un **contrôleur invocable**, pratique pour un endpoint isolé.

## Les erreurs fréquentes

- **Renvoyer un modèle Eloquent** au lieu d'une API Resource.
- **Accéder à une relation non chargée dans une Resource** au lieu de `whenLoaded`, et un N+1 caché.
- **Oublier `Accept: application/json`** côté client, et une redirection au lieu d'une erreur 422.
- **Stocker le jeton en clair** côté serveur, ou le journaliser.
- **Une route de connexion sans limitation de débit.**
- **Un code 200 pour une création**, au lieu de 201.

## Retour au besoin

L'application mobile et le front Vue.js disposent d'une API qui renvoie du JSON maîtrisé, champ par champ, avec des codes de statut fiables et des erreurs exploitables. Ils s'authentifient par jeton, un par appareil, stocké de façon sûre. La connexion est protégée contre la force brute. Et toute la logique déjà écrite, validation, policies, relations, est réutilisée telle quelle.

## À retenir

- `php artisan install:api` installe les routes d'API et Sanctum, `apiResource` déclare les cinq routes utiles.
- Une API Resource définit la réponse, jamais le modèle brut, et `whenLoaded` évite les requêtes cachées.
- Des codes de statut conformes : 201, 204, 401, 403, 404, 422, 429.
- Sanctum pour authentifier par jeton, `auth:sanctum` pour protéger, `throttle` pour limiter le débit.

## Pour aller plus loin

- Les API Resources : [laravel.com/docs/eloquent-resources](https://laravel.com/docs/eloquent-resources)
- Sanctum : [laravel.com/docs/sanctum](https://laravel.com/docs/sanctum)
- La limitation de débit : [laravel.com/docs/rate-limiting](https://laravel.com/docs/rate-limiting)
