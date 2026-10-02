## Objectifs

- Déclarer des routes, leurs paramètres et leurs noms
- Déclarer un CRUD complet avec une route ressource
- Écrire un contrôleur et utiliser l'injection de dépendances de Laravel
- Utiliser la liaison de modèle pour charger une ressource à partir de l'URL
- Afficher des données avec Blade et ses directives
- Construire une mise en page commune avec les composants

## Le besoin

En PHP pur, chaque page du site est un fichier : `catalogue.php`, `formation.php?id=12`, `contact.php`. Chacun mélange la lecture de la base, la logique et le HTML. Sur un vrai projet :

- les **URL** sont dictées par les noms de fichiers, et changer une adresse oblige à renommer un fichier et à corriger tous les liens qui y mènent ;
- chaque page **répète** l'en-tête, le menu et le pied de page ;
- chaque page qui reçoit un identifiant doit **vérifier** qu'il existe et afficher une page 404 sinon ;
- la logique et le HTML sont **entremêlés**, et un intégrateur ne peut pas modifier l'affichage sans risquer de casser le code.

Laravel sépare ces responsabilités : les **routes** décident quelle URL appelle quel code, les **contrôleurs** orchestrent le traitement, et les **vues Blade** s'occupent uniquement de l'affichage.

## Définitions

> **Route.** L'association entre une méthode HTTP, un motif d'URL et le code à exécuter.

> **Paramètre de route.** Une partie variable de l'URL, écrite entre accolades : `/formations/{formation}`.

> **Route nommée.** Une route à laquelle on donne un nom, utilisé pour générer son URL sans l'écrire à la main.

> **Contrôleur.** Une classe qui regroupe les actions liées à une ressource.

> **Liaison de modèle (route model binding).** Le mécanisme qui transforme automatiquement un paramètre de route en modèle Eloquent chargé depuis la base.

> **Blade.** Le moteur de gabarits de Laravel, qui compile les vues en PHP et échappe automatiquement les affichages.

> **Composant Blade.** Un morceau de vue réutilisable, appelé comme une balise HTML : `<x-layout>`.

## Les routes

Les routes des pages web se déclarent dans `routes/web.php` :

```php
use App\Http\Controllers\FormationController;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => view('accueil'))->name('accueil');

Route::get('/formations', [FormationController::class, 'index'])->name('formations.index');
Route::get('/formations/{formation}', [FormationController::class, 'show'])->name('formations.show');
Route::post('/contact', [ContactController::class, 'store'])->name('contact.store');
```

| Élément | Rôle |
|---------|------|
| `Route::get`, `Route::post`, `Route::put`, `Route::delete` | La méthode HTTP |
| `'/formations/{formation}'` | Le motif d'URL, avec un paramètre |
| `[FormationController::class, 'index']` | Le contrôleur et la méthode à appeler |
| `->name('formations.index')` | Le nom de la route |

### Des routes nommées

On génère ensuite les URL à partir du **nom**, jamais en écrivant l'adresse à la main :

```php
route('formations.index')                  // /formations
route('formations.show', $formation)       // /formations/12
route('formations.index', ['page' => 2])   // /formations?page=2
```

Si l'URL change demain de `/formations` en `/catalogue`, il suffit de modifier la route : tous les liens générés avec `route()` suivent automatiquement.

### Grouper des routes

```php
Route::prefix('admin')->name('admin.')->middleware('auth')->group(function () {
    Route::get('/formations', [AdminFormationController::class, 'index'])->name('formations.index');
    // URL : /admin/formations, nom : admin.formations.index, réservée aux utilisateurs connectés
});
```

`php artisan route:list` affiche toutes les routes déclarées, avec leur méthode, leur URL, leur nom et leur contrôleur.

## Les routes ressources

Pour un ensemble CRUD complet, une seule ligne déclare les **sept routes conventionnelles** :

```php
Route::resource('formations', FormationController::class);
```

| Verbe | URL | Méthode | Nom | Rôle |
|-------|-----|---------|-----|------|
| GET | `/formations` | `index` | `formations.index` | Lister |
| GET | `/formations/create` | `create` | `formations.create` | Formulaire de création |
| POST | `/formations` | `store` | `formations.store` | Enregistrer |
| GET | `/formations/{formation}` | `show` | `formations.show` | Afficher |
| GET | `/formations/{formation}/edit` | `edit` | `formations.edit` | Formulaire de modification |
| PUT/PATCH | `/formations/{formation}` | `update` | `formations.update` | Mettre à jour |
| DELETE | `/formations/{formation}` | `destroy` | `formations.destroy` | Supprimer |

On peut n'en garder qu'une partie : `->only(['index', 'show'])` ou `->except(['destroy'])`.

## Les contrôleurs

```bash
php artisan make:controller FormationController --resource
```

```php
namespace App\Http\Controllers;

use App\Models\Formation;
use Illuminate\Http\Request;
use Illuminate\View\View;

class FormationController extends Controller
{
    public function index(Request $request): View
    {
        $formations = Formation::query()
            ->when($request->query('niveau'), fn ($query, $niveau) => $query->where('niveau', $niveau))
            ->orderBy('titre')
            ->paginate(12);

        return view('formations.index', compact('formations'));
    }

    public function show(Formation $formation): View
    {
        return view('formations.show', compact('formation'));
    }
}
```

- `Request $request` : Laravel **injecte** automatiquement l'objet qui représente la requête. `$request->query('niveau')` lit le paramètre `?niveau=`.
- `view('formations.index', ...)` affiche la vue `resources/views/formations/index.blade.php`. Le point remplace le séparateur de dossier.
- `compact('formations')` crée le tableau `['formations' => $formations]` : la variable devient disponible dans la vue.

### L'injection de dépendances

Comme Spring, Laravel dispose d'un **conteneur de services**. Un contrôleur peut recevoir des objets dans son constructeur ou dans ses méthodes, et Laravel les crée automatiquement :

```php
class InscriptionController extends Controller
{
    public function __construct(private InscriptionService $inscriptionService)
    {
    }

    public function store(Request $request, Formation $formation): RedirectResponse
    {
        $this->inscriptionService->inscrire($request->user(), $formation);

        return redirect()->route('formations.show', $formation)->with('succes', 'Inscription confirmée.');
    }
}
```

Comme en Spring, le contrôleur reste **mince** : il reçoit, délègue et renvoie. Une logique métier complexe vit dans une classe dédiée, un service ou une action, injectée par le conteneur.

## La liaison de modèle

Dans `show(Formation $formation)`, le paramètre `{formation}` de la route est automatiquement converti en **modèle chargé depuis la base**. Laravel exécute l'équivalent de `Formation::findOrFail(12)`.

```text
GET /formations/12   →   Formation n° 12 chargée   →   show($formation)
GET /formations/999  →   aucune formation 999      →   page 404 automatique
```

Plus besoin de vérifier l'existence de la ressource dans chaque méthode. Pour utiliser une autre colonne que l'identifiant, par exemple un slug lisible dans l'URL :

```php
Route::get('/formations/{formation:slug}', [FormationController::class, 'show']);
// /formations/initiation-java
```

## Blade

Blade est le moteur de gabarits de Laravel. Les vues sont des fichiers `.blade.php` dans `resources/views`.

```php
<h1>{{ $formation->titre }}</h1>
<p>{{ $formation->description }}</p>
<p>Prix : {{ number_format($formation->prix, 2, ',', ' ') }} €</p>

@if ($formation->places_restantes === 0)
    <p class="badge">Complet</p>
@elseif ($formation->places_restantes < 5)
    <p class="badge">Plus que {{ $formation->places_restantes }} places</p>
@endif

<ul>
    @forelse ($formation->modules as $module)
        <li>{{ $loop->iteration }}. {{ $module->titre }}</li>
    @empty
        <li>Aucun module pour le moment.</li>
    @endforelse
</ul>

<a href="{{ route('formations.index') }}">Retour au catalogue</a>
```

| Directive | Rôle |
|-----------|------|
| `{{ $variable }}` | Affiche une valeur, **échappée** |
| `{!! $variable !!}` | Affiche une valeur **sans** échappement |
| `@if`, `@elseif`, `@else`, `@endif` | Condition |
| `@foreach`, `@forelse ... @empty` | Boucle, avec un cas pour la liste vide |
| `$loop->iteration`, `$loop->first`, `$loop->last` | Informations sur le tour de boucle en cours |
| `@auth`, `@guest` | Contenu réservé aux utilisateurs connectés, ou aux visiteurs |
| `{{-- commentaire --}}` | Commentaire Blade, absent du HTML produit |

La syntaxe `{{ $variable }}` passe la valeur par `htmlspecialchars` : la protection contre le **XSS** est active par défaut. La syntaxe `{!! $variable !!}` n'échappe pas. Ne l'utilisez **jamais** avec une donnée saisie par un utilisateur.

Blade compile chaque vue en PHP pur et la met en cache : il n'y a aucun coût de performance.

## La mise en page commune

Un **composant** de mise en page évite de répéter l'en-tête, le menu et le pied de page dans chaque vue.

```php
{{-- resources/views/components/layout.blade.php --}}
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <title>{{ $title ?? 'Formations' }}</title>
</head>
<body>
    <nav>
        <a href="{{ route('accueil') }}" @class(['actif' => request()->routeIs('accueil')])>Accueil</a>
        <a href="{{ route('formations.index') }}" @class(['actif' => request()->routeIs('formations.*')])>Catalogue</a>
    </nav>
    <main>{{ $slot }}</main>
    <footer>{{ config('app.name') }}</footer>
</body>
</html>
```

```php
{{-- resources/views/formations/index.blade.php --}}
<x-layout title="Catalogue">
    @foreach ($formations as $formation)
        <article>
            <h2><a href="{{ route('formations.show', $formation) }}">{{ $formation->titre }}</a></h2>
        </article>
    @endforeach

    {{ $formations->links() }}
</x-layout>
```

- `<x-layout>` appelle le composant `resources/views/components/layout.blade.php`.
- `$slot` reçoit le contenu placé entre les balises du composant.
- L'attribut `title="Catalogue"` devient la variable `$title` du composant.
- `@class` ajoute une classe CSS selon une condition : ici, le lien de la page courante est mis en évidence.
- `$formations->links()` affiche les liens de pagination.

## Les formulaires

Tout formulaire qui envoie un `POST`, `PUT`, `PATCH` ou `DELETE` contient la directive `@csrf`. Laravel vérifie le jeton automatiquement et refuse la requête s'il manque, avec une erreur 419.

```php
<form method="POST" action="{{ route('formations.destroy', $formation) }}">
    @csrf
    @method('DELETE')
    <button type="submit">Supprimer</button>
</form>
```

Un formulaire HTML ne connaît que `GET` et `POST` : `@method('DELETE')` ajoute un champ caché que Laravel interprète pour appeler la bonne route.

## Exemple complet

Une page de détail de formation, de la route à la vue :

```php
// routes/web.php
Route::get('/formations/{formation:slug}', [FormationController::class, 'show'])->name('formations.show');
```

```php
// app/Http/Controllers/FormationController.php
public function show(Formation $formation): View
{
    $formation->load('categorie', 'modules');

    return view('formations.show', compact('formation'));
}
```

```php
{{-- resources/views/formations/show.blade.php --}}
<x-layout :title="$formation->titre">
    <p class="categorie">{{ $formation->categorie->nom }}</p>
    <h1>{{ $formation->titre }}</h1>

    <h2>Programme</h2>
    <ol>
        @foreach ($formation->modules as $module)
            <li>{{ $module->titre }}</li>
        @endforeach
    </ol>

    @auth
        <form method="POST" action="{{ route('inscriptions.store', $formation) }}">
            @csrf
            <button type="submit">M'inscrire</button>
        </form>
    @else
        <a href="{{ route('login') }}">Connectez-vous pour vous inscrire</a>
    @endauth
</x-layout>
```

`:title="..."` (avec deux-points) passe une **expression PHP** au composant, et non une chaîne littérale. `load()` charge les relations nécessaires en une fois, une notion détaillée dans le module suivant.

## Les erreurs fréquentes

- **Des URL écrites à la main** dans les vues au lieu de `route()`.
- **`{!! !!}` avec une donnée utilisateur.**
- **Oublier `@csrf`**, et une erreur 419 à l'envoi du formulaire.
- **Vérifier à la main l'existence d'une ressource** au lieu d'utiliser la liaison de modèle.
- **De la logique métier dans une vue ou un contrôleur.**
- **Répéter l'en-tête dans chaque vue** au lieu d'un composant de mise en page.

## Retour au besoin

Les URL sont décidées dans un seul fichier de routes et générées par leur nom : les changer ne casse aucun lien. La liaison de modèle charge la ressource et produit la page 404 toute seule. Les contrôleurs orchestrent sans rien afficher, les vues Blade affichent sans rien calculer, et le composant de mise en page supprime toute répétition. Chaque affichage est échappé et chaque formulaire protégé, par défaut.

## À retenir

- Des routes nommées et `route()` pour générer les URL.
- `Route::resource` déclare un CRUD complet de sept routes.
- Le contrôleur reste mince, et reçoit ses dépendances par injection.
- La liaison de modèle charge l'objet et renvoie 404 s'il n'existe pas.
- `{{ }}` échappe, `{!! !!}` n'échappe pas : prudence.
- `@csrf` dans chaque formulaire qui modifie des données.

## Pour aller plus loin

- Le routage : [laravel.com/docs/routing](https://laravel.com/docs/routing)
- Les contrôleurs : [laravel.com/docs/controllers](https://laravel.com/docs/controllers)
- Blade : [laravel.com/docs/blade](https://laravel.com/docs/blade)
