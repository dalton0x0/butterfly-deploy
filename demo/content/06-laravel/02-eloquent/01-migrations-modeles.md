## Objectifs

- Comprendre le rôle des migrations et pourquoi le schéma se versionne
- Écrire, appliquer et annuler des migrations
- Déclarer un modèle Eloquent et ses conversions de types
- Lire, créer, modifier et supprimer des données avec Eloquent
- Nommer une condition réutilisable avec un scope
- Se protéger de l'affectation de masse
- Remplir la base avec les factories et les seeders

## Le besoin

Le site de formations a besoin d'une base de données. Deux problèmes se posent.

**Le schéma.** Emma crée la table `formations` depuis un outil graphique sur son poste. Lucas, qui rejoint le projet, n'a pas cette table : il faut lui envoyer le script. Une semaine plus tard, Emma ajoute une colonne `niveau` sur son poste, et oublie de prévenir. Le code de Lucas plante. Puis vient la mise en production : quelles modifications ont été faites depuis la dernière fois ? Dans quel ordre ?

**L'accès aux données.** Avec PDO, chaque lecture demande d'écrire le SQL, de préparer la requête, de lire les colonnes, de convertir les types. Chaque table demande son repository écrit à la main.

Laravel répond au premier problème avec les **migrations**, qui versionnent le schéma avec le code, et au second avec **Eloquent**, son ORM.

## Définitions

> **Migration.** Un fichier PHP qui décrit une évolution du schéma de la base : créer une table, ajouter une colonne. Il est versionné avec le code et appliqué dans l'ordre.

> **Méthode up et down.** `up` applique l'évolution, `down` l'annule.

> **ORM (Object-Relational Mapping).** Un outil qui fait correspondre des classes à des tables et des objets à des lignes.

> **Modèle Eloquent.** Une classe qui représente une table. Chaque instance représente une ligne.

> **Active Record.** Le motif utilisé par Eloquent : le modèle sait lui-même se charger, s'enregistrer et se supprimer.

> **Affectation de masse (mass assignment).** Remplir plusieurs attributs d'un coup à partir d'un tableau, par exemple les données d'un formulaire.

> **Scope.** Une condition de requête nommée et réutilisable, définie sur le modèle.

## Les migrations

```bash
php artisan make:migration create_formations_table
```

La commande crée un fichier horodaté, comme `2026_09_30_101500_create_formations_table.php`. L'horodatage fixe l'**ordre** d'application.

```php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('formations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('categorie_id')->constrained('categories');
            $table->string('titre', 150)->unique();
            $table->string('slug', 160)->unique();
            $table->text('description')->nullable();
            $table->unsignedInteger('duree_heures');
            $table->decimal('prix', 8, 2);
            $table->boolean('publiee')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('formations');
    }
};
```

| Méthode | Colonne créée |
|---------|---------------|
| `id()` | Clé primaire `id`, entier auto-incrémenté |
| `foreignId('categorie_id')->constrained('categories')` | Clé étrangère avec sa contrainte vers `categories.id` |
| `string('titre', 150)` | `VARCHAR(150)` |
| `text('description')` | `TEXT` |
| `decimal('prix', 8, 2)` | `DECIMAL(8,2)` |
| `boolean('publiee')` | Booléen |
| `timestamps()` | `created_at` et `updated_at`, remplies automatiquement par Eloquent |
| `softDeletes()` | `deleted_at`, pour la suppression logique |

| Modificateur | Effet |
|--------------|-------|
| `->nullable()` | La colonne accepte `NULL` |
| `->default(valeur)` | Valeur par défaut |
| `->unique()` | Contrainte d'unicité |
| `->cascadeOnDelete()` | `ON DELETE CASCADE` sur une clé étrangère |

On retrouve exactement les notions du bloc SQL, exprimées en PHP.

### Appliquer et annuler

```bash
php artisan migrate              # appliquer les migrations en attente
php artisan migrate:status       # voir lesquelles sont appliquées
php artisan migrate:rollback     # annuler le dernier lot
php artisan migrate:fresh --seed # tout supprimer, tout recréer, puis remplir : en développement uniquement
```

Laravel enregistre dans une table `migrations` la liste de celles qui ont été appliquées. Sur chaque poste et chaque serveur, `php artisan migrate` applique **exactement** les migrations manquantes, dans le bon ordre.

### Faire évoluer une table

```bash
php artisan make:migration add_niveau_to_formations_table
```

```php
public function up(): void
{
    Schema::table('formations', function (Blueprint $table) {
        $table->string('niveau', 20)->default('debutant')->after('prix');
    });
}

public function down(): void
{
    Schema::table('formations', function (Blueprint $table) {
        $table->dropColumn('niveau');
    });
}
```

Une migration **déjà appliquée** sur un environnement partagé ne se modifie **jamais** : les autres postes ne la rejoueraient pas. Pour corriger, on écrit une **nouvelle** migration.

## Les modèles Eloquent

```bash
php artisan make:model Formation
```

```php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Formation extends Model
{
    protected $fillable = ['categorie_id', 'titre', 'slug', 'description', 'duree_heures', 'prix', 'publiee'];

    protected function casts(): array
    {
        return [
            'prix' => 'decimal:2',
            'publiee' => 'boolean',
            'niveau' => Niveau::class,
        ];
    }
}
```

Par **convention**, Laravel déduit le nom de la table du nom de la classe, mis au pluriel selon les règles de l'anglais : `Formation` correspond à `formations`. Avec des noms français, ce pluriel automatique peut se tromper. Précisez alors la table avec `protected $table = '...'`. La clé primaire est `id`, et les colonnes `created_at` et `updated_at` sont gérées automatiquement.

Les **casts** convertissent automatiquement les colonnes à la lecture et à l'écriture : `publiee` devient un vrai booléen PHP, et `niveau` une valeur de l'énumération `Niveau`.

## Lire des données

```php
$formation = Formation::find(12);            // null si introuvable
$formation = Formation::findOrFail(12);      // exception, donc 404, si introuvable

$formations = Formation::where('publiee', true)
    ->where('prix', '<=', 800)
    ->orderBy('titre')
    ->get();                                 // une collection de modèles

$premiere = Formation::where('titre', 'Java')->first();
$nombre = Formation::where('publiee', true)->count();
$moyenne = Formation::avg('prix');
$page = Formation::orderBy('titre')->paginate(15);

echo $formation->titre;                      // les colonnes deviennent des propriétés
```

Eloquent traduit ces appels en SQL, avec des **requêtes préparées** : aucune injection possible.

| Méthode | Résultat |
|---------|----------|
| `get()` | Une collection de modèles |
| `first()` | Le premier modèle, ou `null` |
| `find($id)`, `findOrFail($id)` | Par clé primaire |
| `count()`, `sum()`, `avg()`, `max()` | Une valeur agrégée |
| `paginate($n)` | Une page de résultats, avec les informations de pagination |
| `exists()` | Un booléen |

Les résultats multiples sont des **collections** Laravel, qui offrent des méthodes proches des streams Java : `filter`, `map`, `sortBy`, `groupBy`, `sum`.

## Les scopes

Un **scope** donne un nom métier à une condition réutilisée :

```php
use Illuminate\Database\Eloquent\Builder;

public function scopePubliees(Builder $query): void
{
    $query->where('publiee', true);
}

public function scopeMoinsDe(Builder $query, int $prixMax): void
{
    $query->where('prix', '<=', $prixMax);
}
```

```php
Formation::publiees()->moinsDe(500)->orderBy('titre')->get();
```

Le jour où la notion de formation « publiée » change (par exemple en ajoutant une date de publication), on ne modifie que le scope.

## Écrire des données

```php
// Créer
$formation = Formation::create([
    'categorie_id' => 1,
    'titre' => 'Laravel',
    'slug' => 'laravel',
    'duree_heures' => 40,
    'prix' => 900,
]);

// Modifier
$formation->update(['prix' => 950]);

$formation->prix = 990;
$formation->save();

// Supprimer
$formation->delete();
```

## L'affectation de masse

`create` et `update` acceptent un tableau de valeurs. Si l'on y passait directement toutes les données reçues d'un formulaire, un utilisateur malveillant pourrait ajouter un champ caché et modifier une colonne qu'il ne devrait pas toucher :

```php
// Formulaire de profil, avec un champ ajouté par l'attaquant : est_admin=1
User::find($id)->update($request->all());    // DANGER
```

Deux protections se combinent :

| Protection | Rôle |
|------------|------|
| `$fillable` sur le modèle | Liste les colonnes autorisées : les autres sont **ignorées** |
| `$request->validated()` | Ne renvoie que les champs soumis à des règles de validation |

```php
Formation::create($request->validated());    // uniquement les champs validés, parmi ceux autorisés
```

## Eloquent ou Query Builder ?

Laravel propose aussi le **Query Builder** (`DB::table('formations')->where(...)`) qui renvoie de simples objets, sans modèle. Eloquent reste le **choix par défaut** : relations, casts, scopes, événements et lisibilité. Le Query Builder se réserve aux cas où il apporte un vrai gain, par exemple un traitement massif où créer des milliers de modèles coûterait trop cher.

## Remplir la base : factories et seeders

Une **factory** fabrique des modèles avec des données réalistes, grâce à la bibliothèque Faker :

```php
class FormationFactory extends Factory
{
    public function definition(): array
    {
        $titre = fake()->unique()->words(3, true);

        return [
            'categorie_id' => Categorie::factory(),
            'titre' => ucfirst($titre),
            'slug' => Str::slug($titre),
            'duree_heures' => fake()->numberBetween(7, 120),
            'prix' => fake()->randomFloat(2, 100, 2000),
            'publiee' => true,
        ];
    }
}
```

Un **seeder** utilise les factories pour remplir la base :

```php
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        Categorie::factory()
            ->count(4)
            ->has(Formation::factory()->count(5))
            ->create();
    }
}
```

```bash
php artisan db:seed
```

Chaque développeur obtient en une commande une base remplie de données de test crédibles.

## Exemple complet

Du schéma à l'affichage d'un catalogue filtré :

```php
// Migration
Schema::create('categories', function (Blueprint $table) {
    $table->id();
    $table->string('nom', 50)->unique();
    $table->timestamps();
});
```

```php
// Contrôleur
public function index(Request $request): View
{
    $formations = Formation::publiees()
        ->when($request->integer('prix_max'), fn ($query, $prixMax) => $query->moinsDe($prixMax))
        ->orderBy('titre')
        ->paginate(12)
        ->withQueryString();

    return view('formations.index', compact('formations'));
}
```

`when` n'ajoute le filtre que si le paramètre est présent. `withQueryString` conserve les filtres dans les liens de pagination : la page 2 reste filtrée.

## Les erreurs fréquentes

- **Modifier une migration déjà appliquée** au lieu d'en écrire une nouvelle.
- **Créer une table à la main** dans un outil graphique, hors migration.
- **`$request->all()` passé à `create`.**
- **Un `$fillable` qui contient des colonnes sensibles**, comme un rôle.
- **`find` au lieu de `findOrFail`** quand l'absence doit produire une 404.
- **`migrate:fresh` sur une base contenant des données réelles.**

## Retour au besoin

Le schéma évolue désormais par des migrations versionnées avec le code : Lucas lance `php artisan migrate` et obtient exactement la base d'Emma, et la mise en production applique les évolutions manquantes dans le bon ordre. Eloquent remplace les requêtes PDO écrites à la main par des appels lisibles et sûrs. Et les factories remplissent la base de test en une commande. Il reste à relier les modèles entre eux : c'est l'objet du cours suivant.

## À retenir

- Le schéma évolue par migrations versionnées, jamais modifiées après partage.
- Un modèle par table, des casts pour les types, et des conventions qui évitent la configuration.
- `findOrFail` renvoie une 404 automatique, et les requêtes Eloquent sont préparées.
- Un scope donne un nom métier à une condition réutilisée.
- `$fillable` et `$request->validated()` contre l'affectation de masse.

## Pour aller plus loin

- Les migrations : [laravel.com/docs/migrations](https://laravel.com/docs/migrations)
- Eloquent : [laravel.com/docs/eloquent](https://laravel.com/docs/eloquent)
