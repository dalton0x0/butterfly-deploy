## Objectifs

- Déclarer les relations entre modèles Eloquent
- Distinguer l'accès à une relation comme propriété et comme requête
- Gérer une relation plusieurs à plusieurs avec une table pivot
- Charger les relations à l'avance et éviter le problème N+1
- Filtrer et compter selon une relation

## Le besoin

La base contient des catégories, des formations, des modules, des apprenants et des inscriptions, reliés par des clés étrangères. Sans relations déclarées, afficher une formation avec sa catégorie et ses modules demande plusieurs requêtes écrites à la main :

```php
$formation = Formation::findOrFail($id);
$categorie = Categorie::find($formation->categorie_id);
$modules = Module::where('formation_id', $formation->id)->orderBy('position')->get();
$inscrits = DB::table('inscriptions')
    ->join('users', 'users.id', '=', 'inscriptions.user_id')
    ->where('formation_id', $formation->id)
    ->get();
```

Ce code répète partout les noms des clés étrangères, et chaque développeur réinvente la façon de relier les tables. Pire : afficher le catalogue avec la catégorie de chaque formation, dans une boucle, déclenche une requête **par formation**.

Eloquent permet de **déclarer une fois** comment les modèles sont reliés, puis de naviguer entre eux comme entre des objets : `$formation->categorie->nom`, `$formation->modules`, `$user->formations`.

## Définitions

> **Relation Eloquent.** Une méthode d'un modèle qui décrit son lien avec un autre modèle, en s'appuyant sur une clé étrangère.

> **Table pivot.** La table d'association d'une relation plusieurs à plusieurs, qui porte les deux clés étrangères.

> **Chargement paresseux (lazy loading).** La relation est chargée par une requête au moment où l'on y accède pour la première fois.

> **Chargement anticipé (eager loading).** Les relations sont chargées à l'avance, en une requête par relation, pour tous les modèles d'une liste.

> **Problème N+1.** Une requête pour la liste, puis une requête supplémentaire par élément pour charger une relation.

## Un à plusieurs : hasMany et belongsTo

Une catégorie a plusieurs formations, une formation appartient à une catégorie. On déclare la relation **des deux côtés** :

```php
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Categorie extends Model
{
    public function formations(): HasMany
    {
        return $this->hasMany(Formation::class);
    }
}

class Formation extends Model
{
    public function categorie(): BelongsTo
    {
        return $this->belongsTo(Categorie::class);
    }

    public function modules(): HasMany
    {
        return $this->hasMany(Module::class)->orderBy('position');
    }
}
```

| Côté | Méthode | Porte la clé étrangère ? |
|------|---------|--------------------------|
| Le « un » (Categorie) | `hasMany` | Non |
| Le « plusieurs » (Formation) | `belongsTo` | Oui : `categorie_id` |

Laravel **devine** la clé étrangère à partir des noms : `belongsTo(Categorie::class)` dans la méthode `categorie()` utilise la colonne `categorie_id`, et `hasMany(Formation::class)` dans `Categorie` cherche `categorie_id` dans la table `formations`. Si vos colonnes suivent une autre convention, on la précise en deuxième paramètre : `belongsTo(Categorie::class, 'category_id')`.

## Propriété ou méthode ?

Une relation s'utilise de deux façons, avec des résultats différents :

```php
$formation->categorie->nom;                    // propriété : les DONNÉES chargées

$categorie->formations()                       // méthode : une REQUÊTE à compléter
    ->where('publiee', true)
    ->orderBy('prix')
    ->get();
```

| Écriture | Renvoie | Usage |
|----------|---------|-------|
| `$formation->modules` | Une collection, chargée une fois puis mise en cache sur le modèle | Afficher les données |
| `$formation->modules()` | Un constructeur de requête | Filtrer, compter, trier, créer |

```php
$formation->modules()->count();                            // COUNT en SQL, sans charger les modules
$formation->modules()->create(['titre' => 'Introduction', 'position' => 1]);   // formation_id rempli automatiquement
```

## Plusieurs à plusieurs : belongsToMany

Un apprenant suit plusieurs formations et une formation accueille plusieurs apprenants. La relation passe par une **table pivot**, comme la table d'association du bloc SQL.

```php
Schema::create('inscriptions', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->cascadeOnDelete();
    $table->foreignId('formation_id')->constrained()->cascadeOnDelete();
    $table->decimal('note_finale', 4, 2)->nullable();
    $table->timestamps();
    $table->unique(['user_id', 'formation_id']);
});
```

```php
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class User extends Authenticatable
{
    public function formations(): BelongsToMany
    {
        return $this->belongsToMany(Formation::class, 'inscriptions')
            ->withPivot('note_finale')
            ->withTimestamps();
    }
}

class Formation extends Model
{
    public function apprenants(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'inscriptions')
            ->withPivot('note_finale')
            ->withTimestamps();
    }
}
```

| Élément | Rôle |
|---------|------|
| `belongsToMany(Formation::class, 'inscriptions')` | La relation passe par la table `inscriptions`, dont le nom ne suit pas la convention par défaut |
| `withPivot('note_finale')` | Rend la colonne de la table pivot accessible |
| `withTimestamps()` | Remplit `created_at` et `updated_at` de la table pivot |

```php
$user->formations()->attach($formationId);                       // inscrire
$user->formations()->attach($formationId, ['note_finale' => null]);
$user->formations()->detach($formationId);                       // désinscrire
$user->formations()->syncWithoutDetaching([1, 3]);               // ajouter sans doublon
$user->formations()->updateExistingPivot($formationId, ['note_finale' => 15.5]);

foreach ($user->formations as $formation) {
    echo $formation->titre . ' : ' . ($formation->pivot->note_finale ?? 'non notée');
}
```

Chaque formation obtenue par la relation porte un objet `pivot` qui contient les colonnes de la table d'association.

Quand la relation porte beaucoup de données ou de logique (statut, date de validation, historique), créez plutôt un vrai modèle `Inscription` avec ses deux relations `belongsTo` : il se manipule plus simplement qu'un pivot, et peut avoir ses propres méthodes, scopes et policies.

## Les autres relations

| Relation | Exemple | Clé étrangère |
|----------|---------|---------------|
| `hasOne` / `belongsTo` | Un utilisateur a un profil | `profils.user_id` |
| `hasMany` / `belongsTo` | Une catégorie a des formations | `formations.categorie_id` |
| `belongsToMany` | Des apprenants et des formations | Table pivot |
| `hasManyThrough` | Une catégorie a des modules, à travers ses formations | Deux niveaux |

## Le problème N+1

```php
$formations = Formation::all();              // 1 requête

foreach ($formations as $formation) {
    echo $formation->categorie->nom;         // 1 requête PAR formation
}
```

```text
select * from formations
select * from categories where id = 1
select * from categories where id = 2
select * from categories where id = 1
... une requête par formation
```

Avec 50 formations, 51 requêtes. Invisible en développement avec quelques lignes, ce problème fait s'effondrer les performances en production.

La solution est le **chargement anticipé** avec `with` :

```php
$formations = Formation::with('categorie')->get();
```

```text
select * from formations
select * from categories where id in (1, 2, 3)
```

**Deux** requêtes au total, quel que soit le nombre de formations. Eloquent associe ensuite chaque catégorie aux bonnes formations, en mémoire.

```php
Formation::with(['categorie', 'modules'])->get();               // plusieurs relations
Formation::with('modules.ressources')->get();                   // relations imbriquées
Formation::with(['apprenants' => fn ($q) => $q->orderBy('name')])->get();   // relation contrainte

$formation->load('categorie', 'modules');                       // sur un modèle déjà chargé
```

## Compter sans charger

Pour afficher le **nombre** d'inscrits de chaque formation, charger tous les apprenants serait un gaspillage :

```php
$formations = Formation::withCount('apprenants')->get();

foreach ($formations as $formation) {
    echo "{$formation->titre} : {$formation->apprenants_count} inscrits";
}
```

`withCount` ajoute une colonne calculée `apprenants_count` par une sous-requête SQL. De même, `withSum`, `withAvg` ou `withMax` calculent des agrégats.

## Détecter les oublis

Laravel peut **interdire** le chargement paresseux en développement, pour repérer chaque N+1 oublié. Dans `app/Providers/AppServiceProvider.php` :

```php
use Illuminate\Database\Eloquent\Model;

public function boot(): void
{
    Model::preventLazyLoading(! app()->isProduction());
}
```

Un accès à une relation non chargée lève alors une exception en local, avec le nom du modèle et de la relation concernés. En production, le comportement reste normal pour ne pas bloquer les utilisateurs.

## Filtrer selon une relation

```php
// Formations qui ont au moins un inscrit
Formation::has('apprenants')->get();

// Formations sans aucun inscrit
Formation::doesntHave('apprenants')->get();

// Formations de la catégorie Développement
Formation::whereHas('categorie', fn ($query) => $query->where('nom', 'Développement'))->get();

// Formations ayant plus de 10 inscrits
Formation::has('apprenants', '>', 10)->get();
```

`whereHas` traduit la condition en sous-requête SQL `EXISTS` : on retrouve exactement les notions du bloc SQL.

## Exemple complet

Le tableau de bord d'un apprenant : ses formations, avec leur catégorie, leur nombre de modules et sa note.

```php
public function tableauDeBord(Request $request): View
{
    $formations = $request->user()
        ->formations()
        ->with('categorie')
        ->withCount('modules')
        ->orderByPivot('created_at', 'desc')
        ->get();

    $moyenne = $formations->pluck('pivot.note_finale')->filter()->avg();

    return view('tableau-de-bord', compact('formations', 'moyenne'));
}
```

```php
@foreach ($formations as $formation)
    <article>
        <p>{{ $formation->categorie->nom }}</p>
        <h2>{{ $formation->titre }}</h2>
        <p>{{ $formation->modules_count }} modules</p>
        <p>Note : {{ $formation->pivot->note_finale ?? 'en cours' }}</p>
    </article>
@endforeach
<p>Moyenne : {{ $moyenne !== null ? number_format($moyenne, 2, ',', ' ') : 'aucune note' }}</p>
```

Trois requêtes au total : les formations de l'apprenant avec le nombre de modules, puis les catégories. La moyenne est calculée sur la collection, sans nouvelle requête : `pluck` extrait les notes, `filter` retire les `null`, `avg` fait la moyenne.

## Les erreurs fréquentes

- **Oublier `with()`** dans une liste, et un N+1 à chaque affichage.
- **Confondre `$formation->modules` et `$formation->modules()`.**
- **Charger une relation entière pour la compter** au lieu de `withCount`.
- **Oublier `withPivot`**, et une colonne de la table pivot inaccessible.
- **Déclarer la relation d'un seul côté** quand on a besoin de naviguer dans les deux sens.

## Retour au besoin

Les relations sont déclarées une fois, dans les modèles. On navigue ensuite de la formation à sa catégorie, de l'apprenant à ses formations, comme entre des objets, sans jamais réécrire une jointure. Le chargement anticipé ramène le nombre de requêtes à une par relation, et `preventLazyLoading` signale chaque oubli pendant le développement. On combine ainsi la simplicité des objets et les performances du SQL.

## À retenir

- `hasMany` et `belongsTo` pour un à plusieurs, `belongsToMany` avec une table pivot pour plusieurs à plusieurs.
- Sans parenthèses les données, avec parenthèses une requête.
- `with()` charge les relations à l'avance et supprime le N+1, `withCount` compte sans charger.
- `preventLazyLoading` en développement pour repérer les oublis.
- `has` et `whereHas` filtrent selon une relation.

## Pour aller plus loin

- Les relations Eloquent : [laravel.com/docs/eloquent-relationships](https://laravel.com/docs/eloquent-relationships)
