## Objectifs

- Comprendre les problèmes de collision de noms et d'inclusion de fichiers
- Organiser ses classes avec les namespaces et les importer avec `use`
- Installer et mettre à jour des dépendances avec Composer
- Comprendre le rôle de `composer.json`, `composer.lock` et `vendor/`
- Charger automatiquement les classes grâce à l'autoload PSR-4
- Connaître les normes PSR de l'écosystème PHP

## Le besoin

Le projet de billetterie grandit : une vingtaine de classes, chacune dans son fichier. Trois problèmes apparaissent.

**Les inclusions.** Chaque fichier doit charger à la main toutes les classes qu'il utilise :

```php
require_once __DIR__ . '/src/Evenement.php';
require_once __DIR__ . '/src/Conference.php';
require_once __DIR__ . '/src/Atelier.php';
require_once __DIR__ . '/src/Billetterie.php';
// ... et vingt autres lignes, à tenir à jour à chaque nouvelle classe
```

Un oubli, et le script s'arrête sur « Class not found ». L'ordre compte aussi : une classe fille doit être chargée après son parent.

**Les collisions de noms.** Le projet a une classe `Evenement`. On veut utiliser une bibliothèque de calendrier qui a, elle aussi, une classe `Evenement`. PHP refuse deux classes du même nom.

**Les bibliothèques externes.** On veut envoyer des e-mails, générer des PDF, écrire des journaux. Réécrire tout cela est absurde, mais télécharger chaque bibliothèque à la main, avec ses propres dépendances et leurs versions compatibles, est ingérable.

Les **namespaces** règlent les collisions, **Composer** gère les dépendances et l'**autoload** supprime les `require`.

## Définitions

> **Namespace (espace de noms).** Un préfixe qui regroupe des classes, comme un dossier regroupe des fichiers. Le nom complet d'une classe inclut son namespace : `App\Billetterie\Evenement`.

> **Nom pleinement qualifié.** Le nom complet d'une classe, namespace compris, commençant par un antislash : `\App\Billetterie\Evenement`.

> **Composer.** Le gestionnaire de dépendances de PHP. Il télécharge les bibliothèques d'un projet, avec les versions compatibles, et génère un chargeur automatique.

> **Packagist.** Le dépôt public où sont publiés les paquets installables par Composer : [packagist.org](https://packagist.org).

> **Autoload.** Un mécanisme qui charge le fichier d'une classe automatiquement, au moment où elle est utilisée pour la première fois.

> **PSR (PHP Standards Recommendations).** Des normes communes à l'écosystème PHP, publiées par le groupe PHP-FIG.

## Les namespaces

```php
<?php

declare(strict_types=1);

namespace App\Billetterie;

use App\Paiement\Montant;
use DateTimeImmutable;
use InvalidArgumentException;

final class Billetterie
{
    public function vendre(Evenement $evenement, Montant $montant): void
    {
        if ($evenement->date < new DateTimeImmutable()) {
            throw new InvalidArgumentException('Événement déjà passé');
        }
        // ...
    }
}
```

| Instruction | Rôle |
|-------------|------|
| `namespace App\Billetterie;` | Déclare l'espace de noms de toutes les classes du fichier. Première instruction après `declare` |
| `use App\Paiement\Montant;` | Importe une classe d'un autre namespace pour l'utiliser par son nom court |
| `Evenement` (sans `use`) | Une classe du **même** namespace, accessible directement |
| `use DateTimeImmutable;` | Les classes natives de PHP sont dans l'espace **global** : on les importe, ou on les préfixe d'un antislash `\DateTimeImmutable` |

En cas de collision, un **alias** lève l'ambiguïté :

```php
use App\Billetterie\Evenement;
use Calendrier\Evenement as EvenementCalendrier;
```

Les deux classes s'appellent `Evenement`, mais leur nom complet diffère : `App\Billetterie\Evenement` et `Calendrier\Evenement`. Il n'y a plus de collision.

## Composer

Composer s'installe une fois sur le poste, depuis [getcomposer.org](https://getcomposer.org). Ensuite, dans un projet :

```bash
composer init                           # créer composer.json en répondant à quelques questions
composer require monolog/monolog        # ajouter une dépendance et l'installer
composer require --dev phpunit/phpunit  # dépendance utile au développement uniquement (tests)
composer install                        # installer exactement ce qui est décrit dans composer.lock
composer update                         # mettre à jour dans les limites fixées par composer.json
composer remove monolog/monolog         # retirer une dépendance
```

Un paquet se désigne par `vendeur/nom` : `monolog/monolog`, `laravel/framework`, `phpunit/phpunit`.

## Les trois éléments d'un projet Composer

| Élément | Rôle | Versionné ? |
|---------|------|-------------|
| `composer.json` | Les dépendances souhaitées et leurs **contraintes** de version, la configuration de l'autoload | Oui |
| `composer.lock` | Les versions **exactes** installées, pour chaque dépendance et sous-dépendance | Oui, pour une application |
| `vendor/` | Le code des dépendances téléchargées et le chargeur automatique | **Non**, dans le `.gitignore` |

```json
{
    "name": "association/billetterie",
    "require": {
        "php": "^8.3",
        "monolog/monolog": "^3.5"
    },
    "require-dev": {
        "phpunit/phpunit": "^11.0"
    },
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    }
}
```

Pourquoi `composer.lock` est-il si important ? `composer.json` dit « Monolog 3.5 **ou plus récent** dans la version 3 ». Sans le fichier `lock`, un développeur qui installe le projet en janvier obtient la 3.5, un autre en juin obtient la 3.8. Le fichier `lock` fige les versions exactes : toute l'équipe, l'intégration continue et le serveur de production utilisent **exactement** le même code.

| Commande | Lit | Écrit | Quand l'utiliser |
|----------|-----|-------|------------------|
| `composer install` | `composer.lock` | `vendor/` | Après un clone, en production, en intégration continue |
| `composer update` | `composer.json` | `composer.lock` et `vendor/` | Quand on décide de monter de version |

## Les contraintes de version

| Contrainte | Versions acceptées | Usage |
|------------|--------------------|-------|
| `^3.2` | 3.2 et plus, jusqu'à 4.0 exclue | Le choix courant |
| `~3.2` | 3.2 et plus, jusqu'à 4.0 exclue | |
| `~3.2.1` | 3.2.1 et plus, jusqu'à 3.3 exclue | Plus restrictif |
| `3.2.*` | Toutes les versions 3.2.x | |
| `3.2.4` | Exactement 3.2.4 | Rarement utile |

L'accent circonflexe `^` s'appuie sur le versionnage sémantique : il accepte les versions mineures et les correctifs, qui ne doivent pas casser la compatibilité, mais refuse la version majeure suivante.

## L'autoload PSR-4

La norme **PSR-4** établit une correspondance entre un **préfixe de namespace** et un **dossier**. Avec la configuration `"App\\": "src/"` :

| Classe | Fichier cherché |
|--------|-----------------|
| `App\Billetterie\Evenement` | `src/Billetterie/Evenement.php` |
| `App\Paiement\Montant` | `src/Paiement/Montant.php` |
| `App\Kernel` | `src/Kernel.php` |

Le nom du fichier, les dossiers et le namespace doivent correspondre **exactement**, majuscules comprises. Une différence de casse passe inaperçue sous Windows ou macOS, mais échoue sur un serveur Linux.

Le point d'entrée n'inclut plus qu'**un seul fichier** :

```php
<?php

declare(strict_types=1);

require __DIR__ . '/vendor/autoload.php';

use App\Billetterie\Billetterie;
use App\Billetterie\Conference;

$billetterie = new Billetterie();
$billetterie->ajouter(new Conference(/* ... */));
```

Quand PHP rencontre `Conference` pour la première fois, le chargeur de Composer calcule le chemin `src/Billetterie/Conference.php` et l'inclut. Toutes les dépendances installées dans `vendor/` sont chargées de la même façon.

Après une modification de la section `autoload` de `composer.json`, régénérez le chargeur :

```bash
composer dump-autoload
```

## Les scripts Composer

La section `scripts` de `composer.json` donne des raccourcis aux commandes du projet :

```json
{
    "scripts": {
        "test": "phpunit",
        "analyse": "phpstan analyse src"
    }
}
```

```bash
composer test
```

## Les normes PSR

Les normes PSR permettent à des bibliothèques de sources différentes de fonctionner ensemble. Les plus connues :

| Norme | Sujet |
|-------|-------|
| PSR-4 | Autoload des classes |
| PSR-12, puis PER Coding Style | Style d'écriture du code : indentation, accolades, espaces |
| PSR-3 | Interface commune de journalisation |
| PSR-7 | Représentation des requêtes et réponses HTTP |
| PSR-11 | Interface commune des conteneurs d'injection de dépendances |

Grâce à PSR-3, par exemple, une bibliothèque peut écrire des journaux sans savoir si l'application utilise Monolog ou un autre outil.

Des outils comme **PHP-CS-Fixer** ou **Laravel Pint** appliquent automatiquement le style de code, et **PHPStan** analyse le code pour détecter des erreurs sans l'exécuter.

## Exemple complet

Mise en place d'un projet de billetterie avec journalisation :

```bash
mkdir billetterie && cd billetterie
composer init --name=association/billetterie --no-interaction
composer require monolog/monolog
```

Ajout de l'autoload dans `composer.json`, puis `composer dump-autoload`. Structure obtenue :

```text
billetterie/
  composer.json
  composer.lock
  vendor/                   ignoré par Git
  src/
    Billetterie/
      Evenement.php         namespace App\Billetterie;
      Conference.php
      Billetterie.php
  index.php
  .gitignore                contient vendor/
```

```php
<?php
// index.php

declare(strict_types=1);

require __DIR__ . '/vendor/autoload.php';

use App\Billetterie\Billetterie;
use Monolog\Handler\StreamHandler;
use Monolog\Logger;

$journal = new Logger('billetterie');
$journal->pushHandler(new StreamHandler(__DIR__ . '/billetterie.log'));

$billetterie = new Billetterie();
$journal->info('Billetterie démarrée');
```

Un collègue qui clone le dépôt lance simplement `composer install` : il obtient exactement les mêmes versions de Monolog et de ses dépendances.

## Les erreurs fréquentes

- **Versionner `vendor/`**, et un dépôt de plusieurs centaines de mégaoctets.
- **Ne pas versionner `composer.lock`** dans une application, et des versions différentes selon les postes.
- **`composer update` en production** au lieu de `composer install`.
- **Une casse différente** entre le namespace et le nom du dossier, qui échoue seulement sur le serveur Linux.
- **Oublier `composer dump-autoload`** après avoir modifié la section `autoload`.
- **Oublier `use`** pour une classe native, et une erreur « Class App\Billetterie\DateTimeImmutable not found ».

## Retour au besoin

Les vingt lignes de `require` sont remplacées par une seule. Deux classes `Evenement` cohabitent grâce à leur namespace. Et une bibliothèque externe s'installe en une commande, avec des versions identiques pour toute l'équipe grâce au fichier `lock`. Ces trois outils sont la base de tout projet PHP moderne : Laravel et Symfony sont eux-mêmes installés par Composer et organisés en namespaces PSR-4.

## À retenir

- Un namespace par dossier, `use` pour importer, un alias en cas de collision.
- Composer installe les dépendances, `composer.lock` fige leurs versions exactes.
- `composer install` pour installer, `composer update` pour monter de version.
- `vendor/` ne se versionne jamais.
- PSR-4 relie un namespace à un dossier : un seul `require` de l'autoload suffit.

## Pour aller plus loin

- La documentation de Composer : [getcomposer.org/doc](https://getcomposer.org/doc/)
- La norme PSR-4 : [php-fig.org/psr/psr-4](https://www.php-fig.org/psr/psr-4/)
- Les namespaces dans le manuel officiel : [php.net/manual/fr/language.namespaces.php](https://www.php.net/manual/fr/language.namespaces.php)
