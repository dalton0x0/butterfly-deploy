## Objectifs

- Comprendre ce qu'est une variable et pourquoi Java impose un type
- Distinguer les huit types primitifs et les types références
- Déclarer des variables, des constantes et utiliser `var`
- Manipuler les chaînes de caractères et les comparer correctement
- Convertir d'un type à l'autre et utiliser les opérateurs

## Le besoin

Un programme manipule des données : le prénom d'un apprenant, ses notes, sa moyenne, le fait qu'il soit admis ou non. Pour les conserver pendant l'exécution et les réutiliser, il faut les **ranger en mémoire** et pouvoir les retrouver par un **nom**.

Il faut aussi savoir **de quel genre** de donnée il s'agit. Additionner deux notes a du sens, additionner deux prénoms beaucoup moins. Dans certains langages, on ne découvre ce genre d'erreur qu'à l'exécution, parfois devant l'utilisateur :

```text
note = "15"          // du texte, par erreur
total = note + 5     // "155" ? 20 ? une erreur ? Cela dépend du langage...
```

Java fait un choix clair : chaque donnée a un **type connu à la compilation**. Le compilateur refuse ce qui n'a pas de sens avant même que le programme ne démarre.

## Définitions

> **Variable.** Un emplacement mémoire désigné par un nom, qui contient une valeur d'un type donné. Sa valeur peut changer au cours de l'exécution.

> **Type.** La nature d'une donnée : un entier, un décimal, un texte, un booléen. Il détermine les valeurs possibles et les opérations autorisées.

> **Typage statique.** Le type de chaque variable est fixé à la compilation et ne change jamais.

> **Type primitif.** Un type de base qui contient directement sa valeur : `int`, `double`, `boolean`...

> **Type référence.** Un type dont la variable contient l'adresse d'un objet en mémoire : `String`, les tableaux, les collections, vos propres classes.

> **Constante.** Une variable déclarée `final`, dont la valeur ne peut plus être modifiée après son initialisation.

## Déclarer une variable

Une déclaration associe un **type**, un **nom** et, souvent, une **valeur initiale** :

```java
int age = 30;
double moyenne = 14.5;
boolean admis = true;
char initiale = 'E';
String prenom = "Emma";
```

```java
int nombreInscrits;        // déclaration seule
nombreInscrits = 12;       // affectation plus tard
nombreInscrits = 13;       // la valeur peut changer
nombreInscrits = "treize"; // erreur de compilation : incompatible types
```

Conventions de nommage : une variable commence par une minuscule et suit le style **camelCase** (`nombreInscrits`, `noteFinale`). Choisissez des noms qui décrivent le **contenu** : `moyenneGenerale` plutôt que `m` ou `data`.

Une variable locale doit recevoir une valeur **avant** d'être lue. Le compilateur le vérifie :

```java
int total;
System.out.println(total);   // erreur : variable total might not have been initialized
```

## L'inférence de type avec var

Depuis Java 10, le mot-clé `var` laisse le compilateur **déduire** le type à partir de la valeur d'initialisation. Le typage reste statique : `var` n'est qu'un raccourci d'écriture.

```java
var ville = "Paris";              // le type déduit est String
var notes = new ArrayList<Double>();   // ArrayList<Double>

ville = 42;                       // erreur de compilation : ville reste une String
```

Utilisez `var` quand le type est évident à la lecture de la ligne. Évitez-le quand il masque une information utile, par exemple `var resultat = calculer();` où l'on ne sait plus ce que contient `resultat`.

## Les constantes

Une variable `final` ne peut être affectée qu'une seule fois. Pour une valeur fixe partagée par toute une classe, on déclare une constante `static final`, écrite en majuscules avec des tirets bas :

```java
public class Bareme {

    static final int NOTE_MAXIMALE = 20;
    static final double SEUIL_REUSSITE = 10.0;
}
```

Une constante nommée évite les **nombres magiques** : `if (note >= SEUIL_REUSSITE)` se comprend immédiatement, `if (note >= 10)` oblige à deviner ce que représente 10, et à le modifier partout le jour où il change.

## Les huit types primitifs

| Type | Taille | Valeurs | Exemple | Usage courant |
|------|--------|---------|---------|---------------|
| `byte` | 8 bits | -128 à 127 | `byte b = 100;` | Données binaires |
| `short` | 16 bits | -32 768 à 32 767 | `short s = 2000;` | Rarement utilisé |
| `int` | 32 bits | environ ±2,1 milliards | `int n = 42;` | Entiers courants |
| `long` | 64 bits | environ ±9,2 × 10¹⁸ | `long l = 3_000_000_000L;` | Grands entiers, horodatages |
| `float` | 32 bits | environ 7 chiffres significatifs | `float f = 1.5f;` | Rarement utilisé |
| `double` | 64 bits | environ 15 chiffres significatifs | `double d = 3.14;` | Nombres décimaux |
| `char` | 16 bits | un caractère Unicode | `char c = 'A';` | Un caractère |
| `boolean` | - | `true` ou `false` | `boolean ok = false;` | Condition |

Quelques détails de syntaxe :

- un `long` littéral se termine par `L`, un `float` par `f` ;
- le caractère `_` sépare les chiffres pour la lisibilité : `1_000_000` vaut `1000000` ;
- un `char` s'écrit entre apostrophes `'A'`, un `String` entre guillemets `"A"`.

### Le dépassement de capacité

Un type a des bornes. Les dépasser ne provoque **aucune erreur** : la valeur « fait le tour ».

```java
int max = Integer.MAX_VALUE;   // 2147483647
System.out.println(max + 1);   // -2147483648
```

Pour des identifiants ou des compteurs qui peuvent devenir très grands, préférez `long`.

### La précision des décimaux

`double` stocke les nombres en binaire, ce qui ne représente pas exactement toutes les valeurs décimales :

```java
System.out.println(0.1 + 0.2);   // 0.30000000000000004
```

Pour des calculs de notes ou de moyennes, c'est sans importance. Pour de l'**argent**, utilisez la classe `BigDecimal`, qui calcule en décimal exact.

## Les types références

Tout ce qui n'est pas primitif est un **objet**, manipulé par une **référence**. La variable ne contient pas l'objet, mais l'adresse où il se trouve en mémoire.

```text
int note = 15;                       String prenom = "Emma";

 note                                 prenom
┌──────┐                             ┌────────┐       ┌────────────┐
│  15  │  la valeur elle-même        │ adresse├──────►│ objet "Emma"│
└──────┘                             └────────┘       └────────────┘
```

Conséquence importante : une référence peut ne désigner **aucun objet**. Elle vaut alors `null`. Un primitif, lui, a toujours une valeur.

```java
String nom = null;        // autorisé
int quantite = null;      // erreur de compilation
nom.length();             // NullPointerException à l'exécution
```

### Les classes enveloppes

Chaque primitif possède une classe correspondante : `Integer`, `Double`, `Boolean`, `Character`, `Long`... Java convertit automatiquement de l'un à l'autre, c'est l'**autoboxing**. C'est nécessaire pour les collections, qui ne stockent que des objets.

```java
Integer boite = 42;      // autoboxing : int vers Integer
int valeur = boite;      // unboxing : Integer vers int

Integer vide = null;
int crash = vide;        // NullPointerException : impossible de déballer null
```

## Les chaînes de caractères

`String` est un type référence un peu particulier : il est **immuable**. Une méthode qui semble modifier une chaîne en renvoie en réalité une **nouvelle**.

```java
String titre = "  Java pour débutants  ";

titre.trim();                     // "Java pour débutants" (titre, lui, n'a pas changé)
String propre = titre.trim();     // il faut récupérer le résultat

propre.length();                  // 19
propre.toUpperCase();             // "JAVA POUR DÉBUTANTS"
propre.contains("Java");          // true
propre.startsWith("Java");        // true
propre.replace("débutants", "tous");  // "Java pour tous"
propre.isBlank();                 // false
```

Depuis Java 15, les **blocs de texte** simplifient les chaînes sur plusieurs lignes :

```java
String json = """
        {
          "prenom": "Emma",
          "formation": "Java"
        }
        """;
```

## Comparer des chaînes : le piège de ==

`==` compare les **références**, c'est-à-dire les adresses, et non le contenu. Deux objets différents qui contiennent le même texte ne sont pas `==`.

```java
String a = new String("java");
String b = new String("java");

System.out.println(a == b);              // false : deux objets distincts
System.out.println(a.equals(b));         // true : même contenu
System.out.println(a.equalsIgnoreCase("JAVA"));  // true
```

Le piège est sournois, car `==` fonctionne **parfois** avec des chaînes littérales que Java réutilise en interne. Le code semble marcher en test, puis échoue avec des chaînes lues depuis un fichier ou une base. Règle simple : pour comparer le contenu de deux objets, **toujours** `equals`.

Pour éviter une `NullPointerException` quand la variable peut être `null`, placez la constante à gauche : `"ADMIN".equals(role)` ou utilisez `Objects.equals(a, b)`.

## Les conversions

Une conversion vers un type **plus large** est automatique et sans perte. Vers un type **plus étroit**, il faut un **cast** explicite, avec un risque de perte que le développeur assume.

```java
int entier = 7;
long grand = entier;           // automatique
double decimal = entier;       // automatique : 7.0

double prix = 9.99;
int tronque = (int) prix;      // cast explicite : 9, la partie décimale est perdue
long arrondi = Math.round(prix);   // 10

int valeur = Integer.parseInt("123");      // String vers int
double note = Double.parseDouble("14.5");  // String vers double
String texte = String.valueOf(456);        // int vers String
```

`Integer.parseInt("douze")` lève une `NumberFormatException` : toute conversion depuis une saisie utilisateur doit prévoir ce cas.

## Les opérateurs

### Arithmétiques

```java
int a = 17, b = 5;

a + b    // 22
a - b    // 12
a * b    // 85
a / b    // 3 : division entière entre deux int
a % b    // 2 : reste de la division (modulo)
a / 2.0  // 8.5 : un opérande décimal donne un résultat décimal
```

La **division entière** est une source d'erreurs fréquente. Pour obtenir une moyenne décimale à partir d'entiers, convertissez au moins un opérande **avant** la division :

```java
int somme = 67, nombre = 5;
double faux = somme / nombre;             // 13.0 : la division entière a déjà eu lieu
double juste = (double) somme / nombre;   // 13.4
```

Le modulo `%` sert souvent à tester la parité (`n % 2 == 0`) ou à faire des cycles.

### Comparaison, logique et affectation

| Catégorie | Opérateurs | Exemple |
|-----------|------------|---------|
| Comparaison | `==` `!=` `<` `<=` `>` `>=` | `note >= 10` |
| Logiques | `&&` (et) `\|\|` (ou) `!` (non) | `admis && !redoublant` |
| Affectation composée | `+=` `-=` `*=` `/=` `%=` | `total += note` |
| Incrément | `++` `--` | `compteur++` |

Les opérateurs `&&` et `||` sont dits **court-circuit** : si le résultat est connu après le premier opérande, le second n'est pas évalué. On s'en sert pour protéger un appel :

```java
if (nom != null && nom.isBlank()) { ... }   // nom.isBlank() n'est jamais appelé si nom vaut null
```

## Exemple complet

Calculer la moyenne pondérée d'un apprenant et déterminer s'il est admis :

```java
public class MoyennePonderee {

    static final double SEUIL_REUSSITE = 10.0;

    public static void main(String[] args) {
        String prenom = "Emma";
        double noteJava = 15.5;
        double noteSql = 12.0;
        int coefficientJava = 3;
        int coefficientSql = 2;

        double moyenne = (noteJava * coefficientJava + noteSql * coefficientSql)
                / (coefficientJava + coefficientSql);
        boolean admis = moyenne >= SEUIL_REUSSITE;

        System.out.printf("%s : moyenne %.2f, admis : %b%n", prenom, moyenne, admis);
    }
}
```

```text
Emma : moyenne 14,10, admis : true
```

Ici, les notes sont des `double`, donc la division est décimale. Si elles avaient été des `int`, il aurait fallu un cast.

## Les erreurs fréquentes

- **Comparer des chaînes avec `==`.**
- **La division entière** dans un calcul de moyenne.
- **Oublier de récupérer le résultat** d'une méthode de `String`, qui est immuable.
- **Déballer un `Integer` qui vaut `null`.**
- **Des nombres magiques** au lieu de constantes nommées.
- **`double` pour des montants financiers.**

## Retour au besoin

Chaque donnée du programme a désormais un nom qui dit ce qu'elle contient et un type qui dit ce qu'elle est. Le compilateur refuse d'additionner un prénom et une note, et signale une variable utilisée sans valeur. Les pièges qui restent, comme `==` sur des chaînes ou la division entière, sont connus et évitables. Il manque encore la capacité de **décider** et de **répéter** : c'est l'objet du cours sur les conditions et les boucles.

## À retenir

- Le type d'une variable est fixé à la compilation, même avec `var`.
- Les primitifs contiennent leur valeur, les objets sont manipulés par référence et peuvent valoir `null`.
- `String` est immuable, et on compare des chaînes avec `equals`, jamais avec `==`.
- Une division entre deux `int` donne un `int` : convertissez avant de diviser.
- Des constantes nommées plutôt que des nombres magiques.

## Pour aller plus loin

- Le tutoriel officiel sur les bases du langage : [dev.java/learn/language-basics](https://dev.java/learn/language-basics/)
