## Objectifs

- Comprendre ce que Laravel automatise dans la validation
- Valider les données d'une requête avec `validate()`
- Connaître les règles de validation courantes
- Déplacer la validation dans une Form Request
- Gérer l'unicité à la création et à la modification
- Afficher les erreurs et les anciennes valeurs dans un formulaire

## Le besoin

Dans le bloc PHP, valider le formulaire de contact demandait d'écrire soi-même, pour chaque champ :

- la lecture de la valeur avec `?? ''` et `trim` ;
- chaque vérification, avec son message d'erreur ;
- le stockage des erreurs dans un tableau ;
- le réaffichage du formulaire avec les valeurs saisies ;
- la redirection après un envoi réussi.

Pour un formulaire de création de formation, avec un titre unique, une catégorie qui doit exister, une durée et un prix bornés, cela représente des dizaines de lignes, à répéter pour chaque formulaire. Et chaque oubli laisse passer une donnée invalide.

Laravel propose une validation **déclarative** : on décrit les règles, et le framework s'occupe de vérifier, de rediriger, de conserver les valeurs saisies et d'afficher les erreurs.

## Définitions

> **Règle de validation.** Une contrainte que doit respecter un champ : `required`, `max:150`, `email`.

> **Validation déclarative.** On décrit ce qui est attendu, et le framework se charge de la vérification.

> **Form Request.** Une classe dédiée à la validation et à l'autorisation d'une requête, injectée dans le contrôleur.

> **Données validées.** Le tableau des seuls champs soumis à des règles et qui les ont respectées.

> **Ancienne valeur (old input).** La valeur saisie par l'utilisateur, conservée en session après un échec de validation pour la réafficher.

## Valider dans le contrôleur

```php
public function store(Request $request): RedirectResponse
{
    $donnees = $request->validate([
        'titre' => ['required', 'string', 'max:150', 'unique:formations,titre'],
        'categorie_id' => ['required', 'exists:categories,id'],
        'duree_heures' => ['required', 'integer', 'between:1,500'],
        'prix' => ['required', 'numeric', 'min:0'],
        'description' => ['nullable', 'string', 'max:5000'],
    ]);

    $formation = Formation::create($donnees);

    return redirect()
        ->route('formations.show', $formation)
        ->with('succes', 'Formation créée.');
}
```

Ce qui se passe selon le résultat :

| Situation | Comportement de Laravel |
|-----------|-------------------------|
| Toutes les règles passent | `validate()` renvoie les données validées, la méthode continue |
| Une règle échoue, requête d'une page web | **Redirection** vers la page précédente, avec les erreurs et les valeurs saisies en session |
| Une règle échoue, requête d'API (`Accept: application/json`) | Réponse **422** en JSON, avec les erreurs par champ |

Dans les deux cas d'échec, le code qui suit `validate()` n'est **jamais exécuté**.

`validate()` ne renvoie **que** les champs validés. C'est ce tableau que l'on passe à `create`, jamais `$request->all()` : un champ ajouté par un utilisateur malveillant est ignoré.

## Les règles courantes

| Règle | Vérifie que... |
|-------|----------------|
| `required` | le champ est présent et non vide |
| `nullable` | le champ peut être vide ou absent |
| `sometimes` | les règles ne s'appliquent que si le champ est présent |
| `string`, `integer`, `numeric`, `boolean`, `array` | le type est respecté |
| `min:3`, `max:150`, `between:1,500` | la longueur d'une chaîne, ou la valeur d'un nombre, est dans les bornes |
| `size:5` | la longueur ou la valeur est exactement celle-ci |
| `email` | l'adresse a un format valide |
| `url`, `date`, `after:today` | le format d'URL, la date, une date future |
| `in:debutant,avance` | la valeur fait partie d'une liste |
| `unique:formations,titre` | la valeur n'existe pas encore dans la colonne |
| `exists:categories,id` | la valeur existe dans la colonne |
| `confirmed` | le champ `mot_de_passe_confirmation` a la même valeur que `mot_de_passe` |
| `image`, `mimes:pdf,zip`, `max:2048` | un fichier est une image, a une extension autorisée, pèse 2 Mo au plus |

`max` et `min` s'adaptent au type : le nombre de caractères pour une chaîne, la valeur pour un nombre (avec `integer` ou `numeric`), la taille en kilo-octets pour un fichier.

Certaines règles s'écrivent avec la classe `Rule`, plus expressive :

```php
use Illuminate\Validation\Rule;

'niveau' => ['required', Rule::enum(Niveau::class)],
'statut' => ['required', Rule::in(['brouillon', 'publiee'])],
'mot_de_passe' => ['required', 'confirmed', Password::min(10)->mixedCase()->numbers()->symbols()],
```

## Les Form Requests

Dès que la validation grossit, on la sort du contrôleur dans une **Form Request** :

```bash
php artisan make:request StoreFormationRequest
```

```php
namespace App\Http\Requests;

use App\Enums\Niveau;
use App\Models\Formation;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreFormationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', Formation::class);
    }

    public function rules(): array
    {
        return [
            'titre' => ['required', 'string', 'max:150', 'unique:formations,titre'],
            'categorie_id' => ['required', 'exists:categories,id'],
            'niveau' => ['required', Rule::enum(Niveau::class)],
            'duree_heures' => ['required', 'integer', 'between:1,500'],
            'prix' => ['required', 'numeric', 'min:0'],
        ];
    }

    public function messages(): array
    {
        return [
            'titre.unique' => 'Une formation porte déjà ce titre.',
            'categorie_id.exists' => 'La catégorie choisie n\'existe pas.',
        ];
    }

    public function attributes(): array
    {
        return ['duree_heures' => 'durée'];
    }
}
```

```php
public function store(StoreFormationRequest $request): RedirectResponse
{
    $formation = Formation::create($request->validated());

    return redirect()->route('formations.show', $formation);
}
```

| Méthode | Rôle |
|---------|------|
| `authorize()` | Vérifie que l'utilisateur a le droit de faire cette action. `false` produit une erreur 403 |
| `rules()` | Les règles de validation |
| `messages()` | Des messages personnalisés, par champ et par règle |
| `attributes()` | Des noms lisibles pour les champs dans les messages par défaut |

Laravel résout la Form Request et la valide **avant** d'appeler la méthode du contrôleur. Le contrôleur ne contient plus que l'essentiel : si la méthode s'exécute, les données sont valides et l'utilisateur est autorisé.

## La règle unique à la modification

À la modification, la formation possède **déjà** son titre. Une règle `unique:formations,titre` simple la refuserait à chaque enregistrement. Il faut exclure la formation elle-même :

```php
class UpdateFormationRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'titre' => [
                'required',
                'string',
                'max:150',
                Rule::unique('formations', 'titre')->ignore($this->route('formation')),
            ],
            // ...
        ];
    }
}
```

`$this->route('formation')` récupère le modèle lié par la route. La règle vérifie alors l'unicité parmi **toutes les autres** formations.

Comme dans le bloc Spring, une contrainte `UNIQUE` en base reste indispensable en complément : deux requêtes simultanées pourraient passer la validation en même temps.

## Afficher les erreurs

Après un échec, Laravel redirige vers le formulaire et met à disposition deux choses : les **erreurs** et les **anciennes valeurs**.

```php
<form method="POST" action="{{ route('formations.store') }}">
    @csrf

    <label for="titre">Titre</label>
    <input id="titre" name="titre" value="{{ old('titre', $formation->titre ?? '') }}"
           @class(['invalide' => $errors->has('titre')])>
    @error('titre')
        <p class="erreur">{{ $message }}</p>
    @enderror

    <label for="categorie_id">Catégorie</label>
    <select id="categorie_id" name="categorie_id">
        @foreach ($categories as $categorie)
            <option value="{{ $categorie->id }}" @selected(old('categorie_id') == $categorie->id)>
                {{ $categorie->nom }}
            </option>
        @endforeach
    </select>
    @error('categorie_id')
        <p class="erreur">{{ $message }}</p>
    @enderror

    <button type="submit">Enregistrer</button>
</form>
```

| Élément | Rôle |
|---------|------|
| `old('titre', $defaut)` | La valeur saisie avant l'erreur, ou la valeur par défaut au premier affichage |
| `@error('titre') ... @enderror` | Affiche le bloc si le champ a une erreur, avec `$message` |
| `$errors->has('titre')` | Teste la présence d'une erreur, par exemple pour ajouter une classe CSS |
| `$errors->all()` | La liste de toutes les erreurs |
| `@selected(...)` | Ajoute l'attribut `selected` si la condition est vraie |

Les messages d'erreur par défaut sont en anglais. Le paquet communautaire `laravel-lang/lang` fournit leur traduction française, et l'on règle la langue avec `APP_LOCALE=fr` dans le `.env`.

## Exemple complet

La modification d'une formation, avec autorisation, validation, unicité et message de confirmation :

```php
// routes/web.php
Route::middleware('auth')->group(function () {
    Route::get('/formations/{formation}/edit', [FormationController::class, 'edit'])->name('formations.edit');
    Route::put('/formations/{formation}', [FormationController::class, 'update'])->name('formations.update');
});
```

```php
// FormationController
public function update(UpdateFormationRequest $request, Formation $formation): RedirectResponse
{
    $formation->update($request->validated());

    return redirect()
        ->route('formations.show', $formation)
        ->with('succes', 'Formation mise à jour.');
}
```

```php
{{-- Dans la mise en page, pour afficher le message flash --}}
@if (session('succes'))
    <p class="succes">{{ session('succes') }}</p>
@endif
```

Tout le parcours vu à la main dans le bloc PHP est là : validation côté serveur, redirection avec les erreurs et les valeurs saisies, Post-Redirect-Get et message flash. Il tient en quelques lignes.

## Les erreurs fréquentes

- **Passer `$request->all()` à `create`** au lieu de `validated()`.
- **Oublier `nullable`** sur un champ facultatif, et une erreur de type sur une valeur vide.
- **Une règle `unique` sans `ignore`** à la modification.
- **Oublier `old()`**, et un formulaire vidé à chaque erreur.
- **Valider uniquement côté navigateur.**
- **Une `authorize()` qui renvoie `true`** sans réflexion, alors que l'action doit être réservée.

## Retour au besoin

Les dizaines de lignes de validation écrites à la main se réduisent à une liste de règles lisibles. Laravel vérifie, redirige, conserve les valeurs saisies et affiche les erreurs, sans qu'aucun contrôle ne puisse être oublié. La Form Request regroupe validation et autorisation hors du contrôleur, qui ne contient plus que le cas nominal. Et seules les données validées atteignent la base.

## À retenir

- `validate()` ou une Form Request, et toujours `validated()` pour écrire en base.
- Un échec redirige avec les erreurs pour une page web, et renvoie 422 en JSON pour une API.
- `unique` et `exists` vérifient la base directement, et `Rule::unique(...)->ignore(...)` à la modification.
- La Form Request regroupe `authorize()` et `rules()`, et s'exécute avant le contrôleur.
- `old()` et `@error` pour un formulaire agréable après une erreur.

## Pour aller plus loin

- La validation : [laravel.com/docs/validation](https://laravel.com/docs/validation)
