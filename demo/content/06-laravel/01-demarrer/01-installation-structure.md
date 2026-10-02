## Objectifs

- Comprendre ce qu'apporte un framework par rapport à du PHP écrit à la main
- Comprendre l'architecture MVC et le cycle d'une requête dans Laravel
- Créer un projet, le configurer et le lancer
- Se repérer dans l'arborescence d'un projet Laravel
- Utiliser Artisan, la ligne de commande de Laravel

## Le besoin

Le bloc PHP a montré tout ce qu'une application web sûre doit gérer : le routage des URL, la validation de chaque champ, les requêtes préparées, le jeton CSRF de chaque formulaire, l'échappement de chaque affichage, les sessions, le hachage des mots de passe, la redirection après un envoi. Sur une application réelle de cinquante pages :

- ce code d'**infrastructure** est réécrit, projet après projet, avec ses propres bugs ;
- il suffit d'**un seul oubli**, un formulaire sans jeton CSRF, un affichage sans `htmlspecialchars`, pour ouvrir une faille ;
- chaque développeur **organise** le projet à sa façon, et un nouveau venu met des jours à s'y retrouver ;
- il ne reste que peu de temps pour ce qui compte vraiment : le **métier**.

Un **framework** fournit ces briques, testées et sécurisées **par défaut**, et une structure commune à tous les projets. Laravel est le framework PHP le plus populaire.

## Définitions

> **Framework.** Un cadre de développement qui fournit une infrastructure prête à l'emploi et impose une organisation. C'est le framework qui appelle votre code au bon moment.

> **MVC (Modèle, Vue, Contrôleur).** Une architecture qui sépare les données et leurs règles (le modèle), la présentation (la vue) et la coordination entre les deux (le contrôleur).

> **Artisan.** La ligne de commande de Laravel : elle génère du code, applique les migrations et exécute des tâches.

> **Middleware.** Un traitement placé sur le trajet de la requête, avant ou après le contrôleur : vérifier l'authentification, le jeton CSRF, démarrer la session.

> **Convention plutôt que configuration.** Le principe selon lequel, en respectant des conventions de nommage, on n'a presque rien à configurer.

## L'architecture MVC

| Couche | Rôle | Dans Laravel | Exemple |
|--------|------|--------------|---------|
| Modèle | Les données et leurs règles | Modèles Eloquent, dans `app/Models` | `Formation`, avec ses relations |
| Vue | La présentation | Gabarits Blade, dans `resources/views` | La page du catalogue |
| Contrôleur | Reçoit la requête, orchestre, renvoie la réponse | Classes de `app/Http/Controllers` | `FormationController` |

Chaque élément a sa place : on sait où chercher le code d'une page, et chacun peut être modifié sans toucher aux autres.

## Ce que Laravel apporte

| Besoin vu en PHP | Ce que fait Laravel |
|------------------|---------------------|
| Routage à la main | Un fichier de routes lisible, avec paramètres et noms |
| Requêtes PDO et repositories | L'ORM **Eloquent** et les migrations |
| Validation champ par champ | Des règles déclaratives et le réaffichage automatique des erreurs |
| `htmlspecialchars` partout | Échappement automatique dans Blade |
| Jeton CSRF à la main | Généré et vérifié automatiquement |
| `password_hash` | Hachage automatique et authentification prête à l'emploi |
| Sessions et messages flash | Intégrés |
| Envoi d'e-mails, files d'attente, tâches planifiées | Intégrés |

## Créer un projet

Laravel récent demande **PHP 8.2 ou plus récent** et Composer.

```bash
composer create-project laravel/laravel formations
cd formations
php artisan serve          # http://localhost:8000
```

L'installateur officiel, `laravel new formations`, propose en plus de choisir un kit de démarrage (authentification prête à l'emploi), un framework de test et une base de données.

## La configuration

Les réglages propres à chaque environnement vivent dans le fichier `.env`, à la racine du projet. Il n'est **jamais versionné**. Le fichier `.env.example`, lui, est versionné et documente les variables attendues.

```text
APP_NAME=Formations
APP_ENV=local
APP_KEY=base64:...
APP_DEBUG=true
APP_URL=http://localhost:8000

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=formations
DB_USERNAME=root
DB_PASSWORD=
```

| Variable | Rôle |
|----------|------|
| `APP_KEY` | Clé de chiffrement des sessions et cookies, générée par `php artisan key:generate`. Elle ne doit jamais être partagée |
| `APP_DEBUG` | Affichage détaillé des erreurs |
| `APP_ENV` | Nom de l'environnement : `local`, `production` |
| `DB_*` | Connexion à la base de données |

En production, `APP_DEBUG` doit valoir **`false`** : sinon, une erreur affiche au visiteur la trace complète, des extraits de code et des variables de configuration.

Les fichiers du dossier `config` lisent ces variables avec `env()`. Le reste du code lit la configuration avec `config('app.name')`, jamais avec `env()` directement : en production, Laravel met la configuration en cache et `env()` ne renvoie alors plus rien en dehors du dossier `config`.

## L'arborescence

| Dossier | Contenu |
|---------|---------|
| `app/Http/Controllers` | Contrôleurs |
| `app/Http/Requests` | Form Requests de validation |
| `app/Models` | Modèles Eloquent |
| `app/Policies` | Règles d'autorisation |
| `app/Providers` | Fournisseurs de services : configuration au démarrage |
| `bootstrap/app.php` | Configuration du démarrage : routes, middleware, gestion des exceptions |
| `config` | Fichiers de configuration |
| `database/migrations` | Évolutions du schéma de la base |
| `database/factories`, `database/seeders` | Données de test et d'amorçage |
| `public` | **Seul dossier exposé** par le serveur web, avec `index.php` et les fichiers statiques |
| `resources/views` | Vues Blade |
| `routes/web.php` | Routes des pages web |
| `storage` | Journaux, cache, fichiers téléversés |
| `tests` | Tests automatisés |
| `vendor` | Dépendances installées par Composer, jamais versionné |

Seul le dossier `public` doit être accessible depuis le web. Le serveur web pointe sur lui : le code, le fichier `.env` et les journaux restent hors de portée des visiteurs.

## Artisan

**Artisan** est la ligne de commande de Laravel :

```bash
php artisan list                           # toutes les commandes disponibles
php artisan make:controller FormationController
php artisan make:model Formation -mfs      # modèle, migration, factory et seeder
php artisan make:request StoreFormationRequest
php artisan migrate                        # appliquer les migrations
php artisan route:list                     # lister toutes les routes
php artisan tinker                         # console interactive
php artisan test                           # lancer les tests
```

Les commandes `make:` génèrent des fichiers au bon endroit, avec le bon namespace et le bon squelette. Elles garantissent que tous les projets suivent la même organisation.

`tinker` est une console où l'on exécute du code PHP dans le contexte de l'application. C'est très pratique pour essayer une requête Eloquent sans écrire de page :

```text
> App\Models\Formation::where('prix', '<', 500)->count()
= 3
```

## Le cycle d'une requête

```text
Navigateur : GET /formations/12
      │
      ▼
public/index.php              point d'entrée unique
      │
      ▼
Démarrage de Laravel          configuration, fournisseurs de services
      │
      ▼
Middleware                    session, CSRF, authentification...
      │
      ▼
Routeur                       routes/web.php : GET /formations/{formation}
      │
      ▼
Contrôleur                    FormationController@show
      │  utilise le modèle Formation (Eloquent → MySQL)
      ▼
Vue Blade                     resources/views/formations/show.blade.php
      │
      ▼
Réponse HTML                  repasse par les middleware, puis vers le navigateur
```

Toutes les requêtes passent par `public/index.php`. C'est ce **point d'entrée unique** qui permet d'appliquer partout les mêmes protections, sans en oublier aucune.

## Exemple complet

Création d'un projet et d'une première page qui compte les formations, en quelques commandes :

```bash
composer create-project laravel/laravel formations
cd formations
# configurer DB_* dans .env, puis :
php artisan make:model Formation -m
php artisan migrate
```

```php
// routes/web.php
use App\Models\Formation;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('accueil', ['nombre' => Formation::count()]);
});
```

```php
{{-- resources/views/accueil.blade.php --}}
<h1>{{ config('app.name') }}</h1>
<p>{{ $nombre }} formations disponibles.</p>
```

En quelques lignes, on a une page qui interroge la base, avec un affichage échappé automatiquement et une protection CSRF déjà active pour les futurs formulaires. Les cours suivants détaillent chaque étape.

## Les erreurs fréquentes

- **Versionner le fichier `.env`**, et publier la clé de l'application et les mots de passe.
- **`APP_DEBUG=true` en production.**
- **Pointer le serveur web sur la racine du projet** au lieu du dossier `public`.
- **Appeler `env()` en dehors des fichiers de configuration.**
- **Créer les fichiers à la main** au lieu d'utiliser `php artisan make:`.

## Retour au besoin

Le routage, la validation, la protection CSRF, l'échappement, les sessions et l'accès aux données sont fournis, testés et actifs par défaut. Une faille par oubli devient beaucoup plus difficile. Tous les projets Laravel suivent la même organisation : un développeur qui en connaît un s'y retrouve dans tous les autres. Et le temps gagné sur l'infrastructure revient au métier.

## À retenir

- Laravel fournit les briques d'une application web sécurisée et une structure commune, selon l'architecture MVC.
- `.env` pour la configuration locale, jamais versionné, `APP_DEBUG=false` en production.
- Seul `public` est exposé au web, et toutes les requêtes passent par `public/index.php`.
- Artisan génère le code et pilote le projet.

## Pour aller plus loin

- La documentation officielle de Laravel : [laravel.com/docs](https://laravel.com/docs)
- Le cycle de vie d'une requête : [laravel.com/docs/lifecycle](https://laravel.com/docs/lifecycle)
