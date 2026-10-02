## Objectifs

- Manipuler des tableaux indexés et associatifs
- Représenter des enregistrements et des listes d'enregistrements
- Écrire des fonctions typées avec valeurs par défaut et arguments nommés
- Comprendre la portée des variables et le passage des paramètres
- Transformer des tableaux avec les fonctions de tableaux et les fonctions fléchées

## Le besoin

Une boutique de supports de cours doit calculer le montant d'un panier. Sans structure adaptée :

```php
$produit1 = 'Livre Java';   $prix1 = 39.90;   $quantite1 = 2;
$produit2 = 'Vidéo SQL';    $prix2 = 24.00;   $quantite2 = 1;

$total = $prix1 * $quantite1 + $prix2 * $quantite2;
```

Ce code ne tient pas la route :

- avec 50 produits, il faut 150 variables et une addition interminable ;
- le nombre de produits d'un panier **varie** : on ne peut pas prévoir les variables à l'avance ;
- le calcul du total est écrit en dur à un seul endroit : pour l'afficher sur la page du panier **et** dans l'e-mail de confirmation, il faudrait le recopier.

Il nous faut deux outils : une structure capable de contenir un nombre variable d'éléments, le **tableau**, et un moyen d'écrire un calcul une seule fois pour le réutiliser partout, la **fonction**.

## Définitions

> **Tableau (array).** En PHP, une structure ordonnée qui associe des clés à des valeurs. Il sert à la fois de liste, de dictionnaire et d'enregistrement.

> **Tableau indexé.** Un tableau dont les clés sont des entiers attribués automatiquement à partir de 0.

> **Tableau associatif.** Un tableau dont les clés sont des chaînes choisies : `'prenom'`, `'prix'`.

> **Fonction.** Un bloc de code nommé, qui reçoit des paramètres, effectue un traitement et peut renvoyer un résultat.

> **Portée.** La zone du code dans laquelle une variable existe et est accessible.

> **Fonction fléchée.** Une fonction anonyme courte, écrite `fn (paramètres) => expression`.

## Les tableaux indexés

```php
$langages = ['PHP', 'Java', 'SQL'];
$langages[] = 'JavaScript';          // ajout en fin de tableau

echo $langages[0];                   // PHP
echo count($langages);               // 4

unset($langages[1]);                 // supprime 'Java' : les clés 0, 2 et 3 restent
```

Attention : après un `unset`, les clés ne sont **pas** renumérotées. `array_values($langages)` recrée une liste indexée à partir de 0.

## Les tableaux associatifs

Un tableau associatif relie des **clés** à des **valeurs**. C'est la structure la plus utilisée en PHP, par exemple pour représenter une ligne venant d'une base de données ou un objet JSON.

```php
$apprenant = [
    'prenom' => 'Emma',
    'nom' => 'Petit',
    'xp' => 320,
];

echo $apprenant['prenom'];        // Emma
$apprenant['email'] = 'emma@exemple.fr';   // ajout d'une clé

foreach ($apprenant as $cle => $valeur) {
    echo "$cle : $valeur" . PHP_EOL;
}

if (array_key_exists('email', $apprenant)) {
    // ...
}
```

`isset($apprenant['email'])` teste aussi la présence d'une clé, mais renvoie `false` si la valeur est `null`. `array_key_exists` fait la distinction.

## Les listes d'enregistrements

Les tableaux s'imbriquent. Une liste de tableaux associatifs représente un ensemble d'enregistrements, comme le résultat d'une requête SQL :

```php
$apprenants = [
    ['prenom' => 'Emma', 'xp' => 320],
    ['prenom' => 'Lucas', 'xp' => 180],
    ['prenom' => 'Nina', 'xp' => 450],
];

echo $apprenants[2]['prenom'];   // Nina

foreach ($apprenants as $apprenant) {
    echo "{$apprenant['prenom']} : {$apprenant['xp']} XP" . PHP_EOL;
}
```

La **déstructuration** extrait plusieurs valeurs d'un coup :

```php
['prenom' => $prenom, 'xp' => $xp] = $apprenants[0];
[$premier, $deuxieme] = ['PHP', 'Java'];
```

## Les fonctions

Une fonction regroupe un traitement sous un nom. On l'écrit une fois, on l'appelle autant de fois que nécessaire.

```php
function calculerMoyenne(array $notes): float
{
    if (count($notes) === 0) {
        return 0.0;
    }
    return array_sum($notes) / count($notes);
}

echo calculerMoyenne([12, 15, 9]);   // 12
```

| Élément | Exemple | Rôle |
|---------|---------|------|
| Type de paramètre | `int $quantite` | Refuse un argument du mauvais type |
| Type nullable | `?string $commentaire` | Accepte le type ou `null` |
| Valeur par défaut | `int $page = 1` | Rend le paramètre facultatif |
| Type de retour | `: float` | Garantit le type renvoyé |
| Aucun retour | `: void` | La fonction ne renvoie rien |
| Union de types | `int\|float $montant` | Accepte l'un ou l'autre |

Une bonne fonction fait **une seule chose**, porte un nom qui la décrit (un verbe : `calculerMoyenne`, `formaterPrix`) et reste courte.

## Les arguments nommés

Depuis PHP 8, on peut passer les arguments par leur **nom**. C'est utile quand une fonction a plusieurs paramètres facultatifs :

```php
function creerCompte(string $email, bool $actif = true, string $role = 'USER'): array
{
    return ['email' => $email, 'actif' => $actif, 'role' => $role];
}

creerCompte('emma@exemple.fr', role: 'TEACHER');   // actif garde sa valeur par défaut
```

Sans arguments nommés, il aurait fallu écrire `creerCompte('emma@exemple.fr', true, 'TEACHER')`, et deviner à quoi correspond `true`.

## La portée des variables

Une fonction ne voit **pas** les variables extérieures. Tout ce dont elle a besoin passe par ses **paramètres**, et elle communique son résultat par `return`.

```php
$tauxTva = 0.2;

function prixTtc(float $prixHt): float
{
    return $prixHt * (1 + $tauxTva);   // erreur : $tauxTva n'existe pas ici
}
```

La version correcte reçoit tout ce dont elle a besoin en paramètre :

```php
function prixTtc(float $prixHt, float $tauxTva): float   // la dépendance est explicite
{
    return $prixHt * (1 + $tauxTva);
}
```

Évitez le mot-clé `global`, qui donne accès à une variable extérieure : il rend la fonction dépendante d'un état caché, imprévisible et difficile à tester.

## Le passage des paramètres

Par défaut, un tableau passé à une fonction est **copié** : la fonction travaille sur sa propre copie, et le tableau d'origine n'est pas modifié.

```php
function ajouterBonus(array $notes): array
{
    $notes[] = 20;
    return $notes;
}

$notes = [12, 15];
$avecBonus = ajouterBonus($notes);
echo count($notes);       // 2 : l'original est intact
echo count($avecBonus);   // 3
```

C'est un comportement sûr : une fonction ne modifie pas en douce les données de l'appelant. Le passage par référence (`&$notes`) existe mais rend le code plus difficile à suivre : préférez renvoyer un nouveau tableau.

Les **objets**, en revanche, sont manipulés par référence : une fonction qui modifie un objet reçu le modifie pour l'appelant aussi.

## Les fonctions de tableaux

PHP fournit des dizaines de fonctions pour transformer un tableau sans écrire de boucle :

```php
$notes = [12, 8, 15, 9, 17];

$reussites = array_filter($notes, fn (int $note) => $note >= 10);
// [0 => 12, 2 => 15, 4 => 17] : les clés d'origine sont conservées

$sur100 = array_map(fn (int $note) => $note * 5, $notes);
// [60, 40, 75, 45, 85]

$total = array_sum($notes);                                          // 61
$maximum = max($notes);                                              // 17
$somme = array_reduce($notes, fn (int $acc, int $n) => $acc + $n, 0); // 61
```

| Fonction | Rôle | Équivalent en Java |
|----------|------|--------------------|
| `array_filter` | Garder les éléments qui vérifient une condition | `filter` |
| `array_map` | Transformer chaque élément | `map` |
| `array_reduce` | Combiner les éléments en une seule valeur | `reduce` |
| `usort` | Trier selon une fonction de comparaison | `sort` |

Attention : `array_filter` **conserve les clés** d'origine. Pour obtenir une liste réindexée à partir de 0, entourez le résultat de `array_values()`. Sinon, un encodage en JSON produirait un objet au lieu d'une liste.

## Les fonctions fléchées

La syntaxe `fn (paramètres) => expression` crée une fonction anonyme courte. Elle **capture automatiquement** les variables extérieures qu'elle utilise :

```php
$seuil = 10;
$admis = array_filter($notes, fn (int $note) => $note >= $seuil);
```

Pour une fonction anonyme de plusieurs lignes, on utilise `function` avec le mot-clé `use`, qui liste les variables capturées :

```php
$admis = array_filter($notes, function (int $note) use ($seuil): bool {
    $estValide = $note >= 0 && $note <= 20;
    return $estValide && $note >= $seuil;
});
```

## Trier

```php
sort($notes);      // tri croissant en place : [8, 9, 12, 15, 17]
rsort($notes);     // décroissant
asort($prixParProduit);   // trie un tableau associatif par valeur, en gardant les clés
ksort($prixParProduit);   // trie par clé
```

Ces fonctions modifient le tableau **en place** et renvoient un booléen, pas le tableau trié.

Pour trier des enregistrements selon un champ, `usort` accepte une fonction de comparaison. L'opérateur `<=>` (vaisseau spatial) renvoie -1, 0 ou 1 selon que le premier opérande est inférieur, égal ou supérieur au second :

```php
usort($apprenants, fn (array $a, array $b) => $b['xp'] <=> $a['xp']);   // XP décroissante
```

## Quelques fonctions utiles

| Fonction | Rôle |
|----------|------|
| `in_array($valeur, $tableau, true)` | Présence d'une valeur, en comparaison stricte |
| `array_column($tableau, 'xp')` | Extrait une colonne d'une liste d'enregistrements |
| `array_keys($tableau)`, `array_values($tableau)` | Les clés, les valeurs |
| `array_merge($a, $b)` | Fusionne deux tableaux |
| `implode(', ', $tableau)` | Assemble en chaîne |
| `explode(',', $chaine)` | Découpe une chaîne en tableau |

## Exemple complet

Le même principe s'applique à n'importe quel ensemble de données. Voici un bulletin de notes calculé avec des fonctions réutilisables. L'exercice qui suit ce cours vous fera construire le calcul du panier du début.

```php
<?php

declare(strict_types=1);

const SEUIL_REUSSITE = 10.0;

function moyennePonderee(array $resultats): float
{
    $totalCoefficients = array_sum(array_column($resultats, 'coefficient'));
    if ($totalCoefficients === 0) {
        return 0.0;
    }
    $totalPoints = array_sum(array_map(
        fn (array $resultat) => $resultat['note'] * $resultat['coefficient'],
        $resultats
    ));
    return $totalPoints / $totalCoefficients;
}

function matieresEchouees(array $resultats): array
{
    $echecs = array_filter($resultats, fn (array $resultat) => $resultat['note'] < SEUIL_REUSSITE);
    return array_values(array_column($echecs, 'matiere'));
}

function formaterNote(float $note): string
{
    return number_format($note, 2, ',', ' ') . ' / 20';
}

$bulletin = [
    ['matiere' => 'Java', 'note' => 15.5, 'coefficient' => 3],
    ['matiere' => 'SQL', 'note' => 12.0, 'coefficient' => 2],
    ['matiere' => 'Anglais', 'note' => 8.5, 'coefficient' => 1],
];

usort($bulletin, fn (array $a, array $b) => $b['note'] <=> $a['note']);

foreach ($bulletin as $resultat) {
    echo "{$resultat['matiere']} (coef. {$resultat['coefficient']}) : " . formaterNote($resultat['note']) . PHP_EOL;
}
echo 'Moyenne : ' . formaterNote(moyennePonderee($bulletin)) . PHP_EOL;
echo 'À rattraper : ' . implode(', ', matieresEchouees($bulletin)) . PHP_EOL;
```

```text
Java (coef. 3) : 15,50 / 20
SQL (coef. 2) : 12,00 / 20
Anglais (coef. 1) : 8,50 / 20
Moyenne : 13,17 / 20
À rattraper : Anglais
```

Un bulletin de 3 ou de 30 matières utilise le même code. Chaque fonction a un rôle unique et un nom qui le dit, et `formaterNote` peut servir aussi bien pour une page web que pour un export.

## Les erreurs fréquentes

- **Oublier que `array_filter` conserve les clés**, et un JSON qui devient un objet.
- **Attendre un résultat de `sort`**, qui trie en place et renvoie un booléen.
- **Utiliser une variable extérieure dans une fonction** sans la passer en paramètre.
- **`in_array` sans le troisième paramètre `true`**, et une comparaison souple.
- **Des fonctions de 80 lignes** qui font dix choses.

## Retour au besoin

Un panier n'est plus une suite de variables numérotées mais un tableau qui contient autant de lignes que nécessaire, et son calcul peut se découper en petites fonctions typées, écrites une fois et réutilisées partout : c'est ce que vous ferez dans l'exercice. Les fonctions de tableaux remplacent la plupart des boucles par des transformations lisibles. Le module suivant montrera comment aller plus loin en regroupant données et traitements dans des objets.

## À retenir

- Le tableau associatif est la structure de base pour représenter un enregistrement, une liste de tableaux pour un ensemble.
- Typez les paramètres et le retour de chaque fonction, et passez-lui tout ce dont elle a besoin.
- Les tableaux sont copiés quand on les passe à une fonction, les objets non.
- `array_map`, `array_filter` et `usort` évitent beaucoup de boucles.
- `array_filter` conserve les clés : `array_values` pour réindexer.

## Pour aller plus loin

- La liste des fonctions de tableaux dans le manuel officiel : [php.net/manual/fr/ref.array.php](https://www.php.net/manual/fr/ref.array.php)
