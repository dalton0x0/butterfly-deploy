## Objectifs

- Distinguer authentification et autorisation
- Mettre en place l'authentification avec un kit de démarrage et comprendre ce qu'il fait
- Protéger des routes avec les middleware `auth` et `verified`
- Définir des règles simples avec les gates
- Regrouper les droits d'un modèle dans une policy et l'appliquer partout
- Reconnaître et empêcher la faille IDOR

## Le besoin

La plateforme de formations accueille trois types d'utilisateurs, avec des droits différents :

| Action | Visiteur | Apprenant | Formateur | Administrateur |
|--------|----------|-----------|-----------|----------------|
| Consulter le catalogue | Oui | Oui | Oui | Oui |
| S'inscrire à une formation | Non | Oui | Non | Non |
| Modifier une formation | Non | Non | Les siennes | Toutes |
| Supprimer une formation | Non | Non | Les siennes, sans inscrit | Toutes |
| Consulter les notes d'un apprenant | Non | Les siennes | Ses apprenants | Toutes |

Deux questions se posent à chaque requête :

- **Qui** fait la demande ? Il faut vérifier l'identité, avec un mot de passe haché, une session sécurisée, une réinitialisation par e-mail.
- **A-t-il le droit** de faire cela, sur **cette** ressource précise ? Un formateur peut modifier ses formations, mais pas celles d'un collègue.

Si ces vérifications sont écrites à la main dans chaque contrôleur, une seule omission suffit : un formateur qui modifie l'identifiant dans l'URL accède à la formation d'un autre. Laravel fournit des outils dédiés à chacune de ces deux questions.

## Définitions

> **Authentification.** Vérifier l'identité de l'utilisateur : qui êtes-vous ?

> **Autorisation.** Vérifier qu'un utilisateur identifié a le droit de réaliser une action : avez-vous le droit ?

> **Garde (guard).** Le mécanisme qui authentifie les requêtes : par session pour les pages web, par jeton pour une API.

> **Gate.** Une règle d'autorisation simple, identifiée par un nom, qui ne concerne pas un modèle précis.

> **Policy.** Une classe qui regroupe les règles d'autorisation d'un modèle : peut-on voir, créer, modifier, supprimer ?

> **IDOR (Insecure Direct Object Reference).** Une faille où une ressource est chargée par son identifiant sans vérifier que l'utilisateur a le droit d'y accéder.

## Authentification et autorisation

| Notion | Question | Échec |
|--------|----------|-------|
| **Authentification** | Qui êtes-vous ? | 401 Non authentifié, ou redirection vers la page de connexion |
| **Autorisation** | Avez-vous le droit de faire cela ? | 403 Interdit |

Un utilisateur authentifié n'a pas pour autant tous les droits. Les deux vérifications sont **indépendantes** et toujours nécessaires.

## L'authentification

Laravel propose des **kits de démarrage** qui génèrent tout le parcours d'authentification : inscription, connexion, déconnexion, mot de passe oublié, vérification de l'adresse e-mail et page de profil. On les choisit à la création du projet avec l'installateur `laravel new`, qui propose plusieurs variantes selon la technologie du front.

Derrière ces kits, tout repose sur quelques fonctions simples de la façade `Auth` :

```php
use Illuminate\Support\Facades\Auth;

public function login(Request $request): RedirectResponse
{
    $identifiants = $request->validate([
        'email' => ['required', 'email'],
        'password' => ['required'],
    ]);

    if (! Auth::attempt($identifiants, $request->boolean('remember'))) {
        return back()
            ->withErrors(['email' => 'Identifiants incorrects.'])
            ->onlyInput('email');
    }

    $request->session()->regenerate();

    return redirect()->intended(route('tableau-de-bord'));
}
```

| Fonction | Rôle |
|----------|------|
| `Auth::attempt($identifiants)` | Cherche l'utilisateur par e-mail, vérifie le mot de passe haché, ouvre la session |
| `$request->session()->regenerate()` | Change l'identifiant de session après la connexion, contre la fixation de session |
| `redirect()->intended(...)` | Renvoie vers la page que l'utilisateur voulait voir avant d'être redirigé vers la connexion |
| `Auth::user()`, `$request->user()` | L'utilisateur connecté, ou `null` |
| `Auth::check()` | `true` si quelqu'un est connecté |
| `Auth::logout()` | Déconnexion, suivie de l'invalidation de la session |

On retrouve exactement les principes du bloc PHP : `password_verify`, `session_regenerate_id`, un message unique qui ne révèle pas quelles adresses existent. Les mots de passe sont hachés automatiquement grâce au cast `'password' => 'hashed'` du modèle `User`.

## Protéger des routes

Le middleware `auth` refuse l'accès aux visiteurs non connectés et les redirige vers la page de connexion :

```php
Route::middleware('auth')->group(function () {
    Route::get('/tableau-de-bord', DashboardController::class)->name('tableau-de-bord');
    Route::post('/formations/{formation}/inscriptions', [InscriptionController::class, 'store'])
        ->name('inscriptions.store');
});
```

Le middleware `verified` exige en plus une adresse e-mail confirmée :

```php
Route::middleware(['auth', 'verified'])->group(function () { ... });
```

Le middleware répond à la question « qui ? ». Il ne dit rien des **droits** sur une ressource précise : c'est le rôle des gates et des policies.

## Les gates

Une **gate** est une règle d'autorisation simple, identifiée par un nom. On les déclare dans la méthode `boot` de `AppServiceProvider` :

```php
use Illuminate\Support\Facades\Gate;

public function boot(): void
{
    Gate::define('acceder-administration', fn (User $user) => $user->role === Role::Admin);
}
```

```php
if (Gate::denies('acceder-administration')) {
    abort(403);
}

Route::get('/admin', AdminController::class)->middleware('can:acceder-administration');
```

Les gates conviennent aux règles **globales**, qui ne portent pas sur un modèle précis.

## Les policies

Une **policy** regroupe les règles d'autorisation d'un modèle. C'est la solution à privilégier dès que les droits dépendent d'une **ressource** : cette formation, cette inscription.

```bash
php artisan make:policy FormationPolicy --model=Formation
```

```php
namespace App\Policies;

use App\Enums\Role;
use App\Models\Formation;
use App\Models\User;

class FormationPolicy
{
    public function before(User $user): ?bool
    {
        return $user->role === Role::Admin ? true : null;   // l'administrateur peut tout
    }

    public function create(User $user): bool
    {
        return $user->role === Role::Formateur;
    }

    public function update(User $user, Formation $formation): bool
    {
        return $formation->formateur_id === $user->id;
    }

    public function delete(User $user, Formation $formation): bool
    {
        return $formation->formateur_id === $user->id
            && $formation->apprenants()->doesntExist();
    }
}
```

| Élément | Rôle |
|---------|------|
| Une méthode par action | `viewAny`, `view`, `create`, `update`, `delete`... |
| Le premier paramètre | L'utilisateur connecté, fourni automatiquement |
| Le second paramètre | La ressource concernée, absente pour `create` |
| `before()` | Exécutée avant toutes les autres. `true` autorise tout, `false` refuse tout, `null` laisse décider la méthode de l'action |

`before` renvoie `null` pour les non-administrateurs, et non `false` : renvoyer `false` leur refuserait **toutes** les actions sans même consulter les autres méthodes.

Laravel associe automatiquement `FormationPolicy` au modèle `Formation` grâce à la convention de nommage.

## Appliquer une policy

Une policy ne protège rien tant qu'elle n'est pas **appelée**. Plusieurs endroits le permettent :

```php
// Dans un contrôleur
public function update(UpdateFormationRequest $request, Formation $formation): RedirectResponse
{
    Gate::authorize('update', $formation);     // 403 si refusé
    // ...
}

// Dans une Form Request
public function authorize(): bool
{
    return $this->user()->can('update', $this->route('formation'));
}

// Sur une route
Route::put('/formations/{formation}', [FormationController::class, 'update'])
    ->middleware('can:update,formation');
```

```php
{{-- Dans une vue : masquer un bouton inutile --}}
@can('update', $formation)
    <a href="{{ route('formations.edit', $formation) }}">Modifier</a>
@endcan
```

Masquer un bouton améliore l'interface, mais **ne protège rien** : n'importe qui peut envoyer la requête directement, avec un outil comme curl ou les outils de développement du navigateur. La vérification côté serveur, dans le contrôleur, la Form Request ou le middleware, est la **seule** qui compte.

## Le piège IDOR

La faille la plus fréquente en matière d'autorisation consiste à charger une ressource **par son identifiant** sans vérifier qu'elle appartient à l'utilisateur :

```php
// Vulnérable
public function show(int $id): View
{
    $inscription = Inscription::findOrFail($id);
    return view('inscriptions.show', compact('inscription'));
}
```

Un apprenant consulte `/inscriptions/41`, la sienne. Il essaie `/inscriptions/42` : il voit l'inscription, et la note, d'un autre apprenant. On parle d'**IDOR** (Insecure Direct Object Reference). C'est l'une des failles les plus répandues dans les API, parce qu'elle ne se voit pas en utilisant normalement l'interface.

Deux parades :

```php
// 1. Une policy appliquée systématiquement
public function show(Inscription $inscription): View
{
    Gate::authorize('view', $inscription);
    return view('inscriptions.show', compact('inscription'));
}

// 2. Une requête limitée aux ressources de l'utilisateur
public function show(Request $request, int $id): View
{
    $inscription = $request->user()->inscriptions()->findOrFail($id);   // 404 si elle n'est pas à lui
    return view('inscriptions.show', compact('inscription'));
}
```

## Exemple complet

La gestion des notes : un formateur ne note que les apprenants de ses propres formations.

```php
class InscriptionPolicy
{
    public function before(User $user): ?bool
    {
        return $user->role === Role::Admin ? true : null;
    }

    public function view(User $user, Inscription $inscription): bool
    {
        return $inscription->user_id === $user->id
            || $inscription->formation->formateur_id === $user->id;
    }

    public function noter(User $user, Inscription $inscription): bool
    {
        return $user->role === Role::Formateur
            && $inscription->formation->formateur_id === $user->id;
    }
}
```

```php
Route::patch('/inscriptions/{inscription}/note', [NoteController::class, 'update'])
    ->middleware(['auth', 'can:noter,inscription'])
    ->name('inscriptions.note');
```

```php
public function update(Request $request, Inscription $inscription): RedirectResponse
{
    $donnees = $request->validate(['note_finale' => ['required', 'numeric', 'between:0,20']]);
    $inscription->update($donnees);

    return back()->with('succes', 'Note enregistrée.');
}
```

L'authentification (`auth`), l'autorisation (`can:noter`) et la validation sont appliquées **avant** d'entrer dans le contrôleur. Un formateur qui tente de noter l'apprenant d'un collègue reçoit une erreur 403, quel que soit le moyen utilisé pour envoyer la requête.

## Les erreurs fréquentes

- **Confondre authentification et autorisation** : `auth` seul ne suffit pas.
- **`before()` qui renvoie `false`** au lieu de `null`.
- **Masquer un bouton sans vérifier côté serveur.**
- **Charger une ressource par identifiant sans contrôle**, et une faille IDOR.
- **Des vérifications de droits dispersées** dans les contrôleurs au lieu d'une policy.
- **Oublier `session()->regenerate()`** dans une connexion écrite à la main.

## Retour au besoin

Le tableau des droits du début est traduit en policies, une par modèle, lisibles et testables. L'authentification est prise en charge par un kit éprouvé, qui applique les bonnes pratiques de sécurité. Les middleware `auth` et `can` protègent les routes avant même que le contrôleur ne s'exécute, et les ressources ne sont jamais servies sans vérification. Un formateur qui modifie l'identifiant dans l'URL se heurte à une 403.

## À retenir

- Authentification : qui ; autorisation : quel droit. Les deux sont toujours nécessaires.
- Les kits de démarrage génèrent un parcours d'authentification complet et sûr.
- Une gate pour une règle globale, une policy par modèle pour les droits liés à une ressource.
- Une policy s'applique dans le contrôleur, la Form Request ou la route : masquer un bouton ne protège pas.
- Jamais de ressource chargée par identifiant sans contrôle de propriété.

## Pour aller plus loin

- L'authentification : [laravel.com/docs/authentication](https://laravel.com/docs/authentication)
- L'autorisation, gates et policies : [laravel.com/docs/authorization](https://laravel.com/docs/authorization)
- La faille « Broken Access Control » dans l'OWASP Top 10 : [owasp.org/www-project-top-ten](https://owasp.org/www-project-top-ten/)
