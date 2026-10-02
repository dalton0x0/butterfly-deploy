## Objectifs

- Comprendre les problèmes de duplication et de couplage entre classes
- Spécialiser une classe par héritage et utiliser les classes abstraites et `final`
- Définir un contrat avec une interface et en dépendre
- Exploiter le polymorphisme
- Partager du code avec un trait, et en connaître les limites
- Choisir entre héritage, interface, trait et composition

## Le besoin

La plateforme propose trois types de contenus : des cours écrits, des vidéos et des quiz. Chacun a un titre et un niveau, et chacun estime sa durée différemment. Première version :

```php
class CoursEcrit {
    public function __construct(private string $titre, private int $nombreMots) {}
    public function duree(): int { return (int) ceil($this->nombreMots / 200); }
    public function resume(): string { return $this->titre . ' (' . $this->duree() . ' min)'; }
}

class Video {
    public function __construct(private string $titre, private int $secondes) {}
    public function duree(): int { return (int) ceil($this->secondes / 60); }
    public function resume(): string { return $this->titre . ' (' . $this->duree() . ' min)'; }   // copié-collé
}
```

Trois problèmes apparaissent :

- **la duplication** : `resume()` est recopiée dans chaque classe, et une modification devra être faite partout ;
- **le traitement commun** : pour calculer la durée totale d'un parcours, il faut savoir à quelle classe appartient chaque contenu ;
- **le couplage** : un service qui envoie des notifications par e-mail, écrit en dur, ne pourra jamais envoyer de SMS sans être modifié.

PHP propose plusieurs outils complémentaires pour y répondre : l'héritage, les interfaces, les traits et la composition. L'enjeu est de savoir lequel choisir.

## Définitions

> **Héritage.** Une classe fille reprend les propriétés et méthodes d'une classe parente avec `extends`, et peut les spécialiser.

> **Classe abstraite.** Une classe qui ne peut pas être instanciée et peut déclarer des méthodes abstraites que ses filles doivent implémenter.

> **Interface.** Un contrat qui liste des méthodes publiques sans les implémenter. Une classe s'y engage avec `implements`.

> **Polymorphisme.** Manipuler des objets de classes différentes à travers un type commun, chacun réagissant selon sa classe réelle.

> **Trait.** Un bloc de propriétés et de méthodes que l'on insère dans plusieurs classes avec `use`, sans relation d'héritage.

> **Composition.** Un objet en contient un autre et lui délègue une partie du travail.

## L'héritage

```php
abstract class Contenu
{
    public function __construct(protected string $titre)
    {
    }

    abstract public function dureeMinutes(): int;

    public function resume(): string
    {
        return sprintf('%s (%d min)', $this->titre, $this->dureeMinutes());
    }
}

final class CoursEcrit extends Contenu
{
    public function __construct(string $titre, private int $nombreMots)
    {
        parent::__construct($titre);
    }

    public function dureeMinutes(): int
    {
        return (int) ceil($this->nombreMots / 200);
    }
}

final class Video extends Contenu
{
    public function __construct(string $titre, private int $secondes)
    {
        parent::__construct($titre);
    }

    public function dureeMinutes(): int
    {
        return (int) ceil($this->secondes / 60);
    }
}
```

| Élément | Rôle |
|---------|------|
| `extends Contenu` | Crée la relation d'héritage, limitée à **un seul parent** |
| `parent::__construct($titre)` | Appelle le constructeur du parent |
| `protected string $titre` | Accessible au parent et aux filles, caché au reste du code |
| `abstract class` | Ne peut pas être instanciée : `new Contenu(...)` provoque une erreur |
| `abstract public function` | Méthode sans corps que chaque fille doit implémenter |
| `final class` | Ne peut pas être étendue |

`resume()` n'est plus écrite qu'une fois, dans le parent. Elle s'appuie sur `dureeMinutes()`, propre à chaque fille.

Beaucoup de projets rendent leurs classes `final` par défaut et n'ouvrent l'héritage que lorsqu'il est voulu : une classe conçue pour être étendue doit être pensée pour cela.

Depuis PHP 8.3, l'attribut `#[\Override]` joue le même rôle que l'annotation `@Override` de Java : il fait échouer le script si la méthode ne redéfinit rien, par exemple à cause d'une faute de frappe.

```php
#[\Override]
public function dureeMinutes(): int { ... }
```

## Le polymorphisme

```php
/** @param Contenu[] $contenus */
function dureeTotale(array $contenus): int
{
    return array_sum(array_map(fn (Contenu $contenu) => $contenu->dureeMinutes(), $contenus));
}

$parcours = [
    new CoursEcrit('Les tableaux', 1500),
    new Video('Démonstration', 420),
];

echo dureeTotale($parcours);   // 8 + 7 = 15
```

La fonction ignore le type exact de chaque contenu : chacun calcule sa propre durée. Ajouter un type `Quiz` demain ne demande **aucune** modification de `dureeTotale`.

Le commentaire `/** @param Contenu[] $contenus */` est un **PhpDoc** : PHP ne sait pas typer le contenu d'un tableau, mais les éditeurs et les outils d'analyse lisent cette indication.

## Les interfaces

Revenons au service de notification. Il ne devrait dépendre que de la **capacité** à notifier, pas d'une façon précise de le faire.

```php
interface Notification
{
    public function envoyer(string $destinataire, string $message): void;
}

final class NotificationEmail implements Notification
{
    public function envoyer(string $destinataire, string $message): void
    {
        // envoi d'un e-mail
    }
}

final class NotificationSms implements Notification
{
    public function envoyer(string $destinataire, string $message): void
    {
        // envoi d'un SMS
    }
}

final class ServiceInscription
{
    public function __construct(private Notification $notification)
    {
    }

    public function inscrire(string $email): void
    {
        // ... enregistrement
        $this->notification->envoyer($email, 'Bienvenue !');
    }
}
```

```php
$service = new ServiceInscription(new NotificationSms());
```

`ServiceInscription` dépend de l'interface et reçoit l'implémentation de l'extérieur. Changer de canal, ou utiliser une implémentation factice dans un test, ne demande aucune modification du service.

Laravel exploite ce principe avec son **conteneur de services** : il fournit automatiquement au constructeur l'implémentation configurée pour chaque interface.

Une classe peut implémenter plusieurs interfaces : `class Video extends Contenu implements Notable, Telechargeable`. Une interface peut aussi déclarer des constantes, mais jamais de propriétés.

## Les traits

L'héritage ne permet qu'un seul parent. Or certaines capacités sont **transversales** : horodater la création, journaliser, gérer des avis. Elles concernent des classes qui n'ont rien d'autre en commun.

Un **trait** est un bloc de code que PHP **copie** dans chaque classe qui l'utilise :

```php
trait AvecAvis
{
    /** @var int[] */
    private array $notes = [];

    public function ajouterAvis(int $note): void
    {
        if ($note < 1 || $note > 5) {
            throw new InvalidArgumentException('Une note va de 1 à 5');
        }
        $this->notes[] = $note;
    }

    public function noteMoyenne(): ?float
    {
        return $this->notes === [] ? null : array_sum($this->notes) / count($this->notes);
    }
}

final class Video extends Contenu
{
    use AvecAvis;
    // ...
}

final class Formateur
{
    use AvecAvis;
}
```

Laravel utilise beaucoup les traits : `HasFactory`, `Notifiable` ou `SoftDeletes` ajoutent des capacités aux modèles en une ligne.

Mais un trait reste une forme de **copier-coller organisé** :

- il ne définit pas de **type** : on ne peut pas écrire `function afficher(AvecAvis $x)` ;
- il peut dépendre de propriétés de la classe qui l'utilise, sans que rien ne le signale ;
- utilisé à l'excès, il disperse le code et rend une classe difficile à comprendre.

Associer un trait à une interface donne le meilleur des deux : l'interface `Notable` définit le type, le trait `AvecAvis` fournit une implémentation réutilisable.

## La composition

Quand la relation est « a un » plutôt que « est un », on **compose** : l'objet reçoit un autre objet et lui délègue le travail. `ServiceInscription` qui reçoit une `Notification` en est un exemple.

```php
final class Parcours
{
    /** @var Contenu[] */
    private array $contenus = [];

    public function ajouter(Contenu $contenu): void
    {
        $this->contenus[] = $contenu;
    }

    public function dureeTotale(): int
    {
        return array_sum(array_map(fn (Contenu $c) => $c->dureeMinutes(), $this->contenus));
    }
}
```

Un parcours **contient** des contenus, il n'**est** pas un contenu : pas d'héritage ici.

## Quel outil choisir ?

| Besoin | Outil | Exemple |
|--------|-------|---------|
| Un contrat que plusieurs classes respectent | Interface | `Notification` |
| Une base commune avec du code et un état, relation « est un » | Classe abstraite | `Contenu` |
| Une capacité transversale, réutilisée par des classes sans lien | Trait, avec mesure | `AvecAvis` |
| Un objet qui s'appuie sur un autre, relation « a un » | Composition | `Parcours` contient des `Contenu` |

En cas de doute, la composition et les interfaces sont souvent les choix les plus souples.

## Exemple complet

Les outils combinés : une interface pour le type, un trait pour l'implémentation, une classe abstraite pour la base commune.

```php
<?php

declare(strict_types=1);

interface Notable
{
    public function noteMoyenne(): ?float;
}

final class Video extends Contenu implements Notable
{
    use AvecAvis;

    public function __construct(string $titre, private int $secondes)
    {
        parent::__construct($titre);
    }

    public function dureeMinutes(): int
    {
        return (int) ceil($this->secondes / 60);
    }
}

/** @param Contenu[] $contenus */
function mieuxNotes(array $contenus): array
{
    $notables = array_filter(
        $contenus,
        fn (Contenu $c) => $c instanceof Notable && $c->noteMoyenne() !== null
    );
    usort($notables, fn (Notable $a, Notable $b) => $b->noteMoyenne() <=> $a->noteMoyenne());

    return $notables;
}

$video = new Video('Démonstration', 420);
$video->ajouterAvis(5);
$video->ajouterAvis(4);
$cours = new CoursEcrit('Les tableaux', 1500);

foreach (mieuxNotes([$video, $cours]) as $contenu) {
    echo $contenu->resume() . ' : ' . $contenu->noteMoyenne() . '/5' . PHP_EOL;
}
// Démonstration (7 min) : 4.5/5
```

Ici, `instanceof Notable` est légitime : on filtre sur une **capacité** définie par une interface, pas sur une classe concrète.

## Les erreurs fréquentes

- **Hériter pour réutiliser du code** alors que la relation n'est pas « est un ».
- **Dépendre d'une classe concrète** (`new NotificationEmail()` dans le service) au lieu d'une interface reçue par le constructeur.
- **Des traits partout** pour éviter de réfléchir à la conception.
- **Oublier `parent::__construct()`**, et des propriétés du parent jamais initialisées.
- **Une interface par classe** créée « au cas où », sans besoin de variation.

## Retour au besoin

`resume()` est écrite une seule fois dans la classe abstraite, et chaque type de contenu ne définit que ce qui lui est propre. Une seule fonction calcule la durée d'un parcours, quels que soient les types qui le composent. Le service d'inscription ne dépend plus que d'une interface, et le canal de notification se change sans le toucher. Chaque outil a son rôle : l'interface pour le contrat, la classe abstraite pour la base commune, le trait pour une capacité transversale, la composition pour les relations « a un ».

## À retenir

- Un seul parent par classe, autant d'interfaces que nécessaire.
- Une classe abstraite factorise du code, une classe `final` ferme l'héritage.
- Dépendre d'une interface reçue par le constructeur facilite le remplacement et les tests.
- Un trait partage des méthodes entre classes sans lien, à utiliser avec parcimonie.
- En cas de doute, préférez la composition à l'héritage.

## Pour aller plus loin

- Les interfaces dans le manuel officiel : [php.net/manual/fr/language.oop5.interfaces.php](https://www.php.net/manual/fr/language.oop5.interfaces.php)
- Les traits : [php.net/manual/fr/language.oop5.traits.php](https://www.php.net/manual/fr/language.oop5.traits.php)
