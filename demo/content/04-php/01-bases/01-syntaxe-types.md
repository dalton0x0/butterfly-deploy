## Objectifs

- Comprendre le rôle de PHP dans une application web
- Exécuter un script PHP en ligne de commande et via un serveur web
- Déclarer des variables et connaître les types de PHP
- Comprendre les conversions implicites et activer le typage strict
- Comparer correctement avec `===`
- Écrire des conditions, l'expression `match` et des boucles

## Le besoin

Une page HTML classique est **statique** : chaque visiteur reçoit exactement le même fichier. Or un site d'organisme de formation doit :

- afficher le catalogue **à jour**, tel qu'il est stocké en base de données ;
- saluer l'apprenant connecté **par son prénom** ;
- traiter un formulaire d'inscription et **enregistrer** les données ;
- afficher un contenu différent selon que l'utilisateur est un apprenant ou un formateur.

Le navigateur ne sait pas faire cela : il ne fait qu'afficher du HTML. Il faut un programme, **côté serveur**, qui construit la page à la demande, en fonction de la requête et des données. PHP a été créé exactement pour cela.

## Définitions

> **Langage côté serveur.** Un langage dont le code s'exécute sur le serveur web. Le navigateur reçoit uniquement le résultat produit, jamais le code source.

> **Langage interprété.** Le code est lu et exécuté à la volée par un interpréteur, sans étape de compilation séparée. PHP met toutefois en cache une version précompilée des scripts pour gagner en rapidité.

> **Typage dynamique.** Le type d'une variable est déterminé par la valeur qu'elle contient au moment de l'exécution, et peut changer.

> **Conversion implicite (juggling).** Le fait que PHP convertisse automatiquement une valeur d'un type à un autre quand l'opération l'exige.

> **Typage strict.** Un mode dans lequel PHP refuse ces conversions silencieuses pour les appels de fonctions typées.

## Comment PHP produit une page

```text
Navigateur                    Serveur web                  PHP
    │   GET /catalogue.php        │                         │
    ├────────────────────────────►│   exécute le script     │
    │                             ├────────────────────────►│
    │                             │                         │  lit la base,
    │                             │      HTML produit       │  construit le HTML
    │   page HTML                 │◄────────────────────────┤
    │◄────────────────────────────┤                         │
```

Le visiteur qui affiche le code source de la page ne voit que du HTML. Le code PHP, les requêtes à la base et les mots de passe de connexion restent sur le serveur.

PHP fait tourner une large part du web, de WordPress aux applications construites avec **Laravel** ou **Symfony**. Le PHP d'aujourd'hui n'a plus grand-chose à voir avec celui des années 2000 : typage, classes modernes, énumérations et des performances en forte hausse depuis PHP 7. Ce parcours cible **PHP 8.3 ou plus récent**.

## Premier script

```php
<?php

declare(strict_types=1);

$prenom = 'Emma';
echo "Bonjour $prenom !" . PHP_EOL;
```

```bash
php bonjour.php                  # exécution en ligne de commande
php -S localhost:8000            # serveur web de développement dans le dossier courant
```

Avec le serveur lancé, `http://localhost:8000/bonjour.php` affiche le résultat dans le navigateur.

Règles de base :

- Un fichier PHP commence par `<?php`. Dans un fichier qui ne contient que du PHP, on **omet** la balise fermante `?>` : un espace ou un retour à la ligne après elle serait envoyé au navigateur et pourrait provoquer des erreurs.
- Les variables commencent par `$` et sont sensibles à la casse : `$prenom` et `$Prenom` sont différentes.
- Chaque instruction se termine par un point-virgule.
- `echo` affiche une valeur. `PHP_EOL` est un retour à la ligne adapté au système.
- L'opérateur `.` **concatène** des chaînes. Le `+` est réservé aux nombres.

## PHP dans du HTML

PHP peut aussi s'insérer dans une page HTML. La syntaxe courte `<?= ... ?>` affiche une valeur :

```php
<?php $titre = 'Catalogue des formations'; ?>
<!DOCTYPE html>
<html lang="fr">
<body>
    <h1><?= htmlspecialchars($titre) ?></h1>
    <p>Page générée le <?= date('d/m/Y à H:i') ?></p>
</body>
</html>
```

`htmlspecialchars` protège l'affichage contre l'injection de code, une notion détaillée dans le cours sur la sécurité. Pour de vraies applications, on sépare la logique et l'affichage avec un moteur de gabarits, comme Blade dans Laravel.

## Guillemets simples ou doubles

```php
$nom = 'Lucas';
echo 'Bonjour $nom';              // Bonjour $nom : aucune interprétation
echo "Bonjour $nom";              // Bonjour Lucas : la variable est interprétée
echo "Total : {$panier['total']} €";   // accolades pour une expression
echo 'Il a dit : "bonjour"';      // guillemets doubles dans des simples, sans échappement
```

Les guillemets simples sont légèrement plus prévisibles : ce qui est écrit est ce qui est affiché. Utilisez les doubles quand vous avez besoin d'interpoler une variable.

## Les types

| Type | Exemple | Description |
|------|---------|-------------|
| `int` | `42` | Entier |
| `float` | `3.14` | Nombre décimal |
| `string` | `'texte'` | Chaîne de caractères |
| `bool` | `true`, `false` | Booléen |
| `array` | `[1, 2, 3]` | Tableau, indexé ou associatif |
| `null` | `null` | Absence de valeur |
| objet | `new DateTime()` | Instance d'une classe |

```php
var_dump(42);          // int(42)
var_dump('42');        // string(2) "42"
var_dump(4.2);         // float(4.2)
var_dump(null);        // NULL
echo gettype(true);    // boolean
```

`var_dump` affiche le type **et** la valeur : c'est l'outil de débogage de base.

## Le typage dynamique et ses pièges

PHP est **dynamiquement typé** : une variable peut changer de type au cours de l'exécution.

```php
$valeur = 42;       // int
$valeur = 'texte';  // string : aucune erreur
```

Par défaut, PHP convertit aussi les valeurs **à la volée** quand une opération l'exige :

```php
echo '5' + 3;       // 8 : la chaîne '5' est convertie en entier
echo '5' . 3;       // 53 : l'entier 3 est converti en chaîne
echo '10 pommes' + 5;   // 15, avec un avertissement
```

C'est pratique pour un petit script, mais dangereux dans une application : une donnée du mauvais type passe inaperçue et produit un résultat faux au lieu d'une erreur.

## Le typage strict

On peut **typer** les paramètres et le retour d'une fonction. Par défaut, PHP convertit encore les arguments pour qu'ils correspondent. La déclaration `declare(strict_types=1);`, placée en **toute première instruction** du fichier, désactive ces conversions pour les appels faits depuis ce fichier. Un mauvais type provoque alors une `TypeError`.

```php
<?php

declare(strict_types=1);

function doubler(int $nombre): int
{
    return $nombre * 2;
}

echo doubler(5);      // 10
echo doubler('5');    // TypeError : doubler(): Argument #1 ($nombre) must be of type int, string given
```

Sans `strict_types`, `doubler('5')` renverrait silencieusement `10`, et `doubler('5 kilos')` aussi, avec un simple avertissement. Activez-le dans **tous** vos fichiers : c'est une habitude des projets modernes, et l'erreur apparaît là où elle se produit.

## Comparer : == ou === ?

| Opérateur | Compare | `0 == '0'` | `0 === '0'` |
|-----------|---------|------------|-------------|
| `==` | La valeur **après conversion** | `true` | |
| `===` | La valeur **et** le type | | `false` |

```php
var_dump(0 == '0');         // true
var_dump(0 === '0');        // false
var_dump(null == false);    // true
var_dump(null === false);   // false
var_dump('1' == '01');      // true : deux chaînes numériques comparées comme des nombres
var_dump('abc' == 0);       // false depuis PHP 8, true avant
```

Les règles de `==` sont complexes et ont changé entre les versions. Utilisez `===` et `!==` **par défaut**. Le même principe s'applique aux fonctions : `in_array($valeur, $tableau, true)` active la comparaison stricte.

## Les conditions

```php
if ($note >= 14) {
    $mention = 'Très bien';
} elseif ($note >= 10) {
    $mention = 'Admis';
} else {
    $mention = 'Ajourné';
}
```

Comme en Java, les conditions sont évaluées dans l'ordre, et les clauses de garde évitent les imbrications.

### L'expression match

`match`, arrivée avec PHP 8, choisit une valeur selon une autre. Elle compare de façon **stricte** et **renvoie** une valeur :

```php
$libelle = match ($role) {
    'ADMIN' => 'Administrateur',
    'TEACHER' => 'Formateur',
    'USER' => 'Apprenant',
};
```

Si aucun cas ne correspond et qu'il n'y a pas de `default`, `match` lève une `UnhandledMatchError`. Un rôle oublié devient une erreur visible au lieu d'une valeur vide silencieuse. Plusieurs valeurs peuvent partager un cas : `'ADMIN', 'SUPER_ADMIN' => 'Administrateur'`.

| | `switch` | `match` |
|---|----------|---------|
| Comparaison | Souple (`==`) | Stricte (`===`) |
| Renvoie une valeur | Non | Oui |
| Oubli de `break` | Passe au cas suivant | Sans objet |
| Aucun cas trouvé | Ne fait rien | Lève une erreur |

### Les opérateurs de repli

```php
$page = $_GET['page'] ?? 1;          // 1 si la clé est absente ou vaut null
$nom = $utilisateur?->getNom();      // null si $utilisateur vaut null, au lieu d'une erreur
$titre = $titre ?: 'Sans titre';     // 'Sans titre' si $titre est « vide » (chaîne vide, 0, null)
```

L'opérateur `??` est le plus utilisé : il évite l'avertissement « clé inexistante » en lisant un tableau.

## Les boucles

```php
for ($i = 1; $i <= 3; $i++) {
    echo "Tour $i" . PHP_EOL;
}

$notes = [12, 15, 9];
foreach ($notes as $note) {
    echo $note . PHP_EOL;
}

foreach ($notes as $index => $note) {
    echo "Note $index : $note" . PHP_EOL;
}

$capital = 1000;
while ($capital < 2000) {
    $capital *= 1.05;
}
```

`foreach` est la boucle la plus utilisée en PHP, car elle parcourt naturellement les tableaux. La forme `$cle => $valeur` donne accès à la clé de chaque élément.

## Exemple complet

Un script qui affiche une fiche de résultat à partir de données simples :

```php
<?php

declare(strict_types=1);

const SEUIL_REUSSITE = 10;

$apprenant = 'Emma';
$role = 'USER';
$notes = [15.5, 12.0, 8.5];

$moyenne = array_sum($notes) / count($notes);

$mention = match (true) {
    $moyenne >= 16 => 'Très bien',
    $moyenne >= 14 => 'Bien',
    $moyenne >= SEUIL_REUSSITE => 'Admis',
    default => 'Ajourné',
};

$libelleRole = match ($role) {
    'TEACHER' => 'Formateur',
    'USER' => 'Apprenant',
};

echo "$libelleRole : $apprenant" . PHP_EOL;
echo 'Moyenne : ' . number_format($moyenne, 2, ',', ' ') . PHP_EOL;
echo "Résultat : $mention" . PHP_EOL;
```

```text
Apprenant : Emma
Moyenne : 12,00
Résultat : Admis
```

`match (true)` est une astuce courante : chaque cas est une condition, et le premier qui vaut `true` l'emporte. `number_format` affiche le nombre au format français, avec une virgule et deux décimales.

## Les erreurs fréquentes

- **Oublier `declare(strict_types=1);`**, et des conversions silencieuses qui faussent les résultats.
- **`==` au lieu de `===`.**
- **`+` pour concaténer** des chaînes au lieu de `.`.
- **Lire une clé de tableau inexistante** sans `??`.
- **Une balise `?>` finale** suivie d'un retour à la ligne, qui envoie un espace parasite au navigateur.

## Retour au besoin

PHP construit la page côté serveur, à partir des données du moment : le catalogue à jour, le prénom de l'apprenant, un contenu adapté à son rôle. Le navigateur ne reçoit que le HTML final. Avec le typage strict et les comparaisons strictes, le PHP moderne signale les erreurs de type au lieu de les masquer. Il reste à apprendre à manipuler des ensembles de données avec les tableaux, et à organiser le code en fonctions.

## À retenir

- PHP s'exécute sur le serveur et envoie du HTML au navigateur.
- `declare(strict_types=1);` en tête de chaque fichier.
- `===` plutôt que `==`.
- `match` compare strictement, renvoie une valeur et ne tolère pas de cas oublié.
- `??` fournit une valeur par défaut, `foreach` parcourt les tableaux.

## Pour aller plus loin

- Le manuel officiel de PHP, en français : [php.net/manual/fr](https://www.php.net/manual/fr/)
- La référence des comparaisons et de leurs pièges : [php.net/manual/fr/types.comparisons.php](https://www.php.net/manual/fr/types.comparisons.php)
