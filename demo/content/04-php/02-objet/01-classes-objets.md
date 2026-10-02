## Objectifs

- Comprendre les limites des tableaux associatifs pour représenter des données métier
- Déclarer une classe avec des propriétés typées et des méthodes
- Utiliser la promotion de propriétés dans le constructeur
- Protéger l'état d'un objet avec l'encapsulation
- Rendre un objet immuable avec `readonly`
- Utiliser les constantes, les membres statiques et les énumérations

## Le besoin

Dans le module précédent, un apprenant était un tableau associatif :

```php
$apprenant = ['prenom' => 'Emma', 'email' => 'emma@exemple.fr', 'xp' => 120];
```

C'est simple, mais fragile dès que l'application grandit :

- **rien ne garantit la structure** : une faute de frappe (`$apprenant['emial']`) ne provoque qu'un avertissement, et l'on travaille avec `null` ;
- **rien ne protège les données** : n'importe quel code peut écrire `$apprenant['xp'] = -500` ;
- **les règles sont dispersées** : la fonction qui ajoute de l'expérience vit dans un fichier, celle qui calcule le niveau dans un autre, et chacune doit vérifier elle-même que le tableau est valide ;
- **l'éditeur ne peut pas aider** : il ne sait pas quelles clés existent, et ne propose aucune complétion.

La programmation orientée objet regroupe les données **et** les règles qui les concernent dans une même unité, la classe, dont la structure est garantie et les données protégées.

## Définitions

> **Classe.** Un modèle qui décrit un type d'objet : ses propriétés (les données) et ses méthodes (les comportements).

> **Objet (instance).** Un exemplaire concret d'une classe, créé avec `new`.

> **Propriété.** Une variable qui appartient à un objet. En PHP moderne, elle est typée.

> **Méthode.** Une fonction définie dans une classe, qui agit sur l'objet.

> **Constructeur.** La méthode spéciale `__construct`, appelée à la création de l'objet pour l'initialiser.

> **Encapsulation.** Cacher l'état interne d'un objet et n'autoriser sa modification qu'à travers des méthodes qui font respecter les règles.

> **Objet immuable.** Un objet dont l'état ne peut plus changer après sa création.

## Une première classe

```php
<?php

declare(strict_types=1);

class Apprenant
{
    private int $xp = 0;

    public function __construct(
        private string $prenom,
        private string $email,
    ) {
    }

    public function gagnerXp(int $points): void
    {
        if ($points <= 0) {
            throw new InvalidArgumentException('Le gain d\'XP doit être positif');
        }
        $this->xp += $points;
    }

    public function getXp(): int
    {
        return $this->xp;
    }

    public function getPrenom(): string
    {
        return $this->prenom;
    }
}

$emma = new Apprenant('Emma', 'emma@exemple.fr');
$emma->gagnerXp(50);
echo $emma->getXp();   // 50
```

| Syntaxe | Rôle |
|---------|------|
| `new Apprenant(...)` | Crée un objet et appelle le constructeur |
| `$this` | Désigne l'objet courant, à l'intérieur de la classe |
| `->` | Accède à une propriété ou appelle une méthode d'un objet |
| `private int $xp = 0;` | Une propriété typée, privée, avec une valeur initiale |

Les propriétés sont **typées** : avec `strict_types`, affecter une chaîne à `$xp` provoque une `TypeError`. Une propriété typée sans valeur initiale doit être initialisée avant d'être lue, sinon PHP lève une erreur.

Comme en Java, un objet est manipulé par **référence** : si l'on passe `$emma` à une fonction qui appelle `gagnerXp`, c'est bien l'objet d'Emma qui est modifié. Pour obtenir une copie indépendante, on utilise `clone $emma`.

## La promotion de propriétés

Le constructeur ci-dessus déclare **et** affecte `$prenom` et `$email` en une seule fois, grâce à la **promotion de propriétés** introduite par PHP 8.0. Sans elle, il faudrait écrire :

```php
private string $prenom;
private string $email;

public function __construct(string $prenom, string $email)
{
    $this->prenom = $prenom;
    $this->email = $email;
}
```

La promotion supprime ce code répétitif sans rien changer au comportement : un paramètre de constructeur précédé d'un modificateur de visibilité devient automatiquement une propriété.

Le corps du constructeur peut toujours contenir des vérifications :

```php
public function __construct(
    private string $prenom,
    private string $email,
) {
    if (filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
        throw new InvalidArgumentException("Adresse e-mail invalide : $email");
    }
}
```

## L'encapsulation

```php
$emma->xp = -500;         // Error : Cannot access private property Apprenant::$xp
$emma->gagnerXp(-500);    // InvalidArgumentException : Le gain d'XP doit être positif
```

| Modificateur | Accessible depuis |
|--------------|-------------------|
| `private` | La classe elle-même |
| `protected` | La classe et ses sous-classes |
| `public` | Partout |

Règle simple : commencez par `private` et n'ouvrez que ce qui est nécessaire. Préférez des méthodes qui expriment une **intention** (`gagnerXp`, `retirer`, `valider`) à des setters génériques qui permettraient de tout écrire.

## Les propriétés readonly

Une propriété `readonly` (PHP 8.1) ne peut être affectée **qu'une seule fois**, depuis l'intérieur de la classe. On obtient ainsi des objets **immuables**, idéaux pour représenter des **valeurs** : un montant, une adresse, une période.

```php
final class Montant
{
    public function __construct(
        public readonly int $centimes,
        public readonly string $devise = 'EUR',
    ) {
        if ($centimes < 0) {
            throw new InvalidArgumentException('Un montant ne peut pas être négatif');
        }
    }

    public function ajouter(Montant $autre): self
    {
        if ($autre->devise !== $this->devise) {
            throw new InvalidArgumentException('Impossible d\'additionner deux devises différentes');
        }
        return new self($this->centimes + $autre->centimes, $this->devise);
    }

    public function formater(): string
    {
        return number_format($this->centimes / 100, 2, ',', ' ') . ' ' . $this->devise;
    }
}

$prix = new Montant(1990);
$total = $prix->ajouter(new Montant(500));
echo $total->formater();   // 24,90 EUR

$prix->centimes = 0;       // Error : Cannot modify readonly property Montant::$centimes
```

- Les propriétés sont `public` : on peut les **lire** directement, mais pas les modifier.
- `ajouter` ne modifie pas l'objet : elle en renvoie un **nouveau**. C'est le principe d'un objet immuable.
- Stocker un montant en **centimes entiers** évite les erreurs d'arrondi des nombres à virgule.

Depuis PHP 8.2, `readonly class Montant` rend toutes les propriétés en lecture seule d'un coup.

Un objet immuable a un grand avantage : on peut le transmettre partout sans craindre qu'une autre partie du code le modifie dans notre dos.

## Constantes et membres statiques

```php
class Formation
{
    public const DUREE_MAXIMALE = 120;

    private static int $nombreCrees = 0;

    public function __construct(private string $titre, private int $dureeHeures)
    {
        if ($dureeHeures > self::DUREE_MAXIMALE) {
            throw new InvalidArgumentException('Durée trop longue');
        }
        self::$nombreCrees++;
    }

    public static function nombreCrees(): int
    {
        return self::$nombreCrees;
    }
}

echo Formation::DUREE_MAXIMALE;      // 120
echo Formation::nombreCrees();
```

On accède aux constantes et aux membres statiques avec `::`. Depuis l'intérieur de la classe, on utilise `self::`. Un membre statique appartient à la **classe** et non à chaque objet.

## Les énumérations

Beaucoup de données n'acceptent qu'un **ensemble fini** de valeurs : un rôle, un niveau, un statut. Représentées par de simples chaînes, elles sont exposées aux fautes de frappe :

```php
if ($utilisateur['role'] === 'TEACHR') { ... }   // faute de frappe : la condition n'est jamais vraie, sans erreur
```

Une **énumération** (PHP 8.1) déclare la liste exhaustive des valeurs possibles, que le moteur vérifie :

```php
enum Role: string
{
    case Admin = 'ADMIN';
    case Formateur = 'TEACHER';
    case Apprenant = 'USER';

    public function libelle(): string
    {
        return match ($this) {
            Role::Admin => 'Administrateur',
            Role::Formateur => 'Formateur',
            Role::Apprenant => 'Apprenant',
        };
    }

    public function peutCorriger(): bool
    {
        return $this === Role::Admin || $this === Role::Formateur;
    }
}
```

```php
$role = Role::from('TEACHER');   // Role::Formateur
echo $role->libelle();           // Formateur
echo $role->value;               // TEACHER
var_dump($role->peutCorriger()); // bool(true)

Role::from('TEACHR');            // ValueError : valeur inconnue
Role::tryFrom('TEACHR');         // null
Role::cases();                   // la liste de tous les cas
```

| Élément | Rôle |
|---------|------|
| `enum Role: string` | Une énumération **adossée** : chaque cas porte une valeur `string` ou `int`, utile pour la base de données ou le JSON |
| `Role::Formateur` | Un cas, utilisable comme une valeur |
| `->value` | La valeur associée |
| `from()` / `tryFrom()` | Retrouver un cas à partir de sa valeur, avec erreur ou avec `null` |

Une fonction qui attend un `Role` en paramètre ne peut plus recevoir une chaîne mal orthographiée. Et une énumération peut porter des **méthodes** : la règle « qui peut corriger » vit à côté des rôles.

## Exemple complet

Un apprenant avec un rôle, une expérience protégée et un niveau calculé :

```php
<?php

declare(strict_types=1);

enum Niveau: string
{
    case Debutant = 'debutant';
    case Confirme = 'confirme';
    case Expert = 'expert';

    public static function depuisXp(int $xp): self
    {
        return match (true) {
            $xp >= 1000 => self::Expert,
            $xp >= 300 => self::Confirme,
            default => self::Debutant,
        };
    }
}

final class Apprenant
{
    private int $xp = 0;

    public function __construct(
        public readonly string $prenom,
        public readonly string $email,
    ) {
        if (filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
            throw new InvalidArgumentException("Adresse e-mail invalide : $email");
        }
    }

    public function gagnerXp(int $points): void
    {
        if ($points <= 0) {
            throw new InvalidArgumentException('Le gain d\'XP doit être positif');
        }
        $this->xp += $points;
    }

    public function niveau(): Niveau
    {
        return Niveau::depuisXp($this->xp);
    }

    public function resume(): string
    {
        return sprintf('%s : %d XP, niveau %s', $this->prenom, $this->xp, $this->niveau()->value);
    }
}

$emma = new Apprenant('Emma', 'emma@exemple.fr');
$emma->gagnerXp(250);
$emma->gagnerXp(120);
echo $emma->resume();   // Emma : 370 XP, niveau confirme
```

Le prénom et l'e-mail sont lisibles mais non modifiables. L'expérience n'évolue que par `gagnerXp`. Le niveau n'est pas stocké : il est **calculé**, et ne peut donc jamais être incohérent avec l'expérience.

## Les erreurs fréquentes

- **Des propriétés `public` modifiables**, qui annulent l'encapsulation.
- **Oublier `$this->`** à l'intérieur d'une méthode : `$xp` désigne alors une variable locale inexistante.
- **Lire une propriété typée non initialisée**, et une erreur « must not be accessed before initialization ».
- **Des chaînes magiques** pour les rôles ou les statuts au lieu d'une énumération.
- **Stocker des montants en `float`** au lieu de centimes entiers.

## Retour au besoin

L'apprenant n'est plus un tableau dont la structure n'est garantie par rien, mais un objet dont les propriétés sont typées et protégées. Une faute de frappe dans un nom de propriété devient une erreur, une expérience négative est refusée, et les règles vivent dans la classe. Les énumérations ferment la porte aux chaînes mal orthographiées. Et l'éditeur, qui connaît désormais la structure, propose la complétion.

## À retenir

- Propriétés typées et `private` par défaut, méthodes qui expriment une intention.
- La promotion de propriétés supprime le code répétitif des constructeurs.
- `readonly` crée des objets immuables, idéaux pour représenter des valeurs.
- Une énumération remplace les chaînes magiques pour un ensemble fini de valeurs.
- Un objet est manipulé par référence : `clone` pour obtenir une copie.

## Pour aller plus loin

- Les classes et objets dans le manuel officiel : [php.net/manual/fr/language.oop5.php](https://www.php.net/manual/fr/language.oop5.php)
- Les énumérations : [php.net/manual/fr/language.enumerations.php](https://www.php.net/manual/fr/language.enumerations.php)
