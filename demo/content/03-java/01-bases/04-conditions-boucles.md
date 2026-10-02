## Objectifs

- Exécuter du code selon une condition avec `if`, `else if` et `else`
- Simplifier les conditions avec les clauses de garde et l'opérateur ternaire
- Choisir entre plusieurs cas avec le `switch` moderne
- Répéter un traitement avec `for`, for-each, `while` et `do-while`
- Contrôler une boucle avec `break` et `continue`, et éviter la boucle infinie

## Le besoin

Jusqu'ici, nos programmes exécutent leurs instructions dans l'ordre, une seule fois, de haut en bas. Or un vrai programme doit :

- **prendre des décisions** : afficher « Admis » si la moyenne atteint 10, « Ajourné » sinon ;
- **choisir entre plusieurs cas** : afficher un libellé différent selon le rôle d'un utilisateur ;
- **répéter** un traitement : calculer la moyenne de 30 notes sans écrire 30 additions ;
- **recommencer tant que** quelque chose n'est pas vrai : redemander une saisie tant qu'elle est invalide.

Sans structures de contrôle, il faudrait écrire un programme différent pour chaque situation. Les conditions et les boucles permettent à un même programme de **s'adapter aux données** qu'il reçoit.

## Définitions

> **Condition.** Une expression booléenne, qui vaut `true` ou `false`, utilisée pour décider si un bloc de code s'exécute.

> **Structure conditionnelle.** Une instruction qui exécute un bloc ou un autre selon une condition : `if`, `switch`.

> **Boucle.** Une instruction qui répète un bloc de code tant qu'une condition est vraie ou pour chaque élément d'un ensemble.

> **Itération.** Un passage dans le corps d'une boucle.

> **Bloc.** Un ensemble d'instructions entre accolades. Une variable déclarée dans un bloc n'existe que dans ce bloc : c'est sa **portée**.

## La condition if

```java
double moyenne = 13.2;

if (moyenne >= 14) {
    System.out.println("Mention bien");
} else if (moyenne >= 10) {
    System.out.println("Admis");
} else {
    System.out.println("Ajourné");
}
```

Les conditions sont évaluées **dans l'ordre**. Dès qu'une est vraie, son bloc s'exécute et toutes les suivantes sont ignorées. L'ordre compte donc : placez les cas les plus restrictifs en premier.

```java
// Faux : une moyenne de 16 affiche « Admis », la seconde condition n'est jamais testée
if (moyenne >= 10) {
    System.out.println("Admis");
} else if (moyenne >= 14) {
    System.out.println("Mention bien");
}
```

Gardez les accolades même pour une seule instruction. Leur absence est à l'origine de bugs célèbres, lorsqu'une deuxième ligne ajoutée plus tard se retrouve hors de la condition malgré son indentation :

```java
if (estAdmin)
    afficherMenuAdmin();
    supprimerCompte();    // toujours exécuté, quel que soit estAdmin !
```

### Combiner des conditions

```java
if (moyenne >= 10 && absences <= 3) { ... }        // les deux doivent être vraies
if (role.equals("ADMIN") || role.equals("TEACHER")) { ... }   // l'une suffit
if (!inscriptionsOuvertes) { ... }                 // négation
```

## Les clauses de garde

Plutôt que d'imbriquer les conditions, on **sort tôt** de la méthode quand un cas empêche de continuer. Le cas nominal reste au premier niveau d'indentation.

```java
// Imbriqué : difficile à suivre
static String evaluer(Double note) {
    if (note != null) {
        if (note >= 0 && note <= 20) {
            if (note >= 10) {
                return "Admis";
            } else {
                return "Ajourné";
            }
        } else {
            return "Note invalide";
        }
    } else {
        return "Note absente";
    }
}

// Avec des clauses de garde : chaque cas particulier est traité puis écarté
static String evaluer(Double note) {
    if (note == null) {
        return "Note absente";
    }
    if (note < 0 || note > 20) {
        return "Note invalide";
    }
    return note >= 10 ? "Admis" : "Ajourné";
}
```

## L'opérateur ternaire

La dernière ligne utilise l'**opérateur ternaire** : `condition ? valeurSiVrai : valeurSiFaux`. Il **renvoie une valeur**, ce qui le rend utile pour choisir entre deux valeurs simples.

```java
String statut = moyenne >= 10 ? "Admis" : "Ajourné";
String pluriel = nombre > 1 ? "apprenants" : "apprenant";
```

Il devient illisible dès qu'on l'imbrique. Au-delà de deux cas, utilisez un `if` ou un `switch`.

## Le switch moderne

Quand une même variable est comparée à plusieurs valeurs précises, une suite de `else if` devient lourde. `switch` est fait pour cela.

Depuis Java 14, `switch` peut être une **expression** qui renvoie une valeur, avec la syntaxe fléchée :

```java
String jour = "SAMEDI";

String type = switch (jour) {
    case "SAMEDI", "DIMANCHE" -> "Week-end";
    case "LUNDI", "MARDI", "MERCREDI", "JEUDI", "VENDREDI" -> "Semaine";
    default -> "Jour inconnu";
};
```

Ses avantages :

- un cas peut regrouper plusieurs valeurs, séparées par des virgules ;
- aucun risque d'oublier un `break` ;
- utilisé comme expression, il doit couvrir **tous** les cas, sinon le compilateur le refuse.

Un cas peut contenir plusieurs instructions dans un bloc, avec `yield` pour renvoyer la valeur :

```java
int points = switch (niveau) {
    case "DEBUTANT" -> 10;
    case "AVANCE" -> {
        System.out.println("Bonus niveau avancé");
        yield 30;
    }
    default -> 20;
};
```

### L'ancienne forme

Vous rencontrerez encore l'ancienne syntaxe dans du code existant :

```java
switch (jour) {
    case "SAMEDI":
    case "DIMANCHE":
        type = "Week-end";
        break;
    default:
        type = "Semaine";
}
```

Sans `break`, l'exécution **continue** dans le cas suivant (on parle de « fall-through »). C'est une source classique de bugs. Pour du nouveau code, préférez la forme fléchée.

## La boucle for

On l'utilise quand le **nombre d'itérations est connu** à l'avance.

```java
for (int i = 1; i <= 5; i++) {
    System.out.println("Tour " + i);
}
```

Elle comporte trois parties, séparées par des points-virgules :

| Partie | Exemple | Moment |
|--------|---------|--------|
| Initialisation | `int i = 1` | Une seule fois, au début |
| Condition | `i <= 5` | Avant chaque itération : la boucle s'arrête dès qu'elle est fausse |
| Mise à jour | `i++` | Après chaque itération |

```java
// Parcourir un tableau avec son indice
double[] notes = {12.5, 15, 9};
for (int i = 0; i < notes.length; i++) {
    System.out.println("Note " + (i + 1) + " : " + notes[i]);
}
```

Les indices d'un tableau vont de `0` à `length - 1`. Écrire `i <= notes.length` provoque une `ArrayIndexOutOfBoundsException` au dernier tour : c'est l'erreur de « décalage de un », extrêmement courante.

## La boucle for-each

Pour parcourir **tous les éléments** d'un tableau ou d'une collection, sans avoir besoin de l'indice, la boucle for-each est plus lisible et supprime le risque d'erreur d'indice :

```java
double somme = 0;
for (double note : notes) {
    somme += note;
}
```

Elle se lit « pour chaque note dans notes ».

## Les boucles while et do-while

`while` répète **tant qu'une condition est vraie**. Elle convient quand on ne sait pas combien de tours seront nécessaires.

```java
double capital = 1000;
int annees = 0;

while (capital < 2000) {
    capital *= 1.05;
    annees++;
}
System.out.println("Capital doublé en " + annees + " ans");   // 15 ans
```

La condition est testée **avant** chaque tour : si elle est fausse dès le départ, le corps ne s'exécute jamais.

`do-while` exécute le corps **au moins une fois**, puis teste la condition. Elle est typique d'une saisie que l'on redemande tant qu'elle est invalide :

```java
Scanner scanner = new Scanner(System.in);
int choix;

do {
    System.out.print("Votre choix (1 à 3) : ");
    choix = scanner.nextInt();
} while (choix < 1 || choix > 3);
```

## La boucle infinie

Une boucle dont la condition ne devient jamais fausse ne s'arrête jamais :

```java
int i = 0;
while (i < 10) {
    System.out.println(i);
    // oubli de i++ : la condition reste vraie pour toujours
}
```

Avant d'écrire une boucle `while`, demandez-vous : **qu'est-ce qui, dans le corps, finira par rendre la condition fausse ?**

## break et continue

- `break` sort immédiatement de la boucle.
- `continue` abandonne l'itération en cours et passe directement à la suivante.

```java
for (int i = 1; i <= 10; i++) {
    if (i % 2 == 0) {
        continue;   // ignore les nombres pairs
    }
    if (i > 7) {
        break;      // arrête la boucle
    }
    System.out.println(i);   // affiche 1, 3, 5, 7
}
```

Utilisés avec parcimonie, ils simplifient une boucle. En excès, ils la rendent difficile à suivre.

## Quelle structure choisir ?

| Situation | Structure |
|-----------|-----------|
| Deux branches | `if` / `else`, ou le ternaire pour une simple valeur |
| Plusieurs cas selon une même valeur | `switch` fléché |
| Parcourir tous les éléments | for-each |
| Nombre de tours connu, besoin de l'indice | `for` |
| Répéter jusqu'à ce qu'une condition change | `while` |
| Exécuter au moins une fois | `do-while` |

## Exemple complet

Analyser les notes d'une promotion : moyenne, nombre d'admis et première note éliminatoire.

```java
public class AnalysePromotion {

    static final double SEUIL_REUSSITE = 10.0;
    static final double NOTE_ELIMINATOIRE = 5.0;

    public static void main(String[] args) {
        double[] notes = {12.5, 15.0, 9.0, 4.5, 17.5, 11.0};

        double somme = 0;
        int admis = 0;
        for (double note : notes) {
            somme += note;
            if (note >= SEUIL_REUSSITE) {
                admis++;
            }
        }
        double moyenne = somme / notes.length;

        int indexEliminatoire = -1;
        for (int i = 0; i < notes.length; i++) {
            if (notes[i] < NOTE_ELIMINATOIRE) {
                indexEliminatoire = i;
                break;
            }
        }

        String appreciation = switch ((int) moyenne / 5) {
            case 0, 1 -> "Insuffisant";
            case 2 -> "Satisfaisant";
            default -> "Très bien";
        };

        System.out.printf("Moyenne : %.2f (%s)%n", moyenne, appreciation);
        System.out.printf("Admis : %d sur %d%n", admis, notes.length);
        if (indexEliminatoire >= 0) {
            System.out.println("Première note éliminatoire en position " + (indexEliminatoire + 1));
        }
    }
}
```

```text
Moyenne : 11,58 (Satisfaisant)
Admis : 4 sur 6
Première note éliminatoire en position 4
```

## Les erreurs fréquentes

- **L'ordre des `else if`** qui rend une condition inaccessible.
- **L'absence d'accolades**, et une instruction qui échappe à la condition.
- **`i <= tableau.length`** au lieu de `i < tableau.length`.
- **Une boucle `while` dont la condition ne change jamais.**
- **Oublier `break`** dans l'ancienne forme du `switch`.
- **Des conditions imbriquées sur quatre niveaux** au lieu de clauses de garde.

## Retour au besoin

Avec les conditions, un même programme affiche « Admis » ou « Ajourné » selon la moyenne qu'il calcule. Avec les boucles, il traite 6 ou 6 000 notes avec le même code. Et une saisie invalide est redemandée autant de fois que nécessaire. Ces deux outils suffisent à écrire la plupart des algorithmes. Le module suivant montrera comment organiser un programme plus grand en objets.

## À retenir

- Les `else if` sont évalués dans l'ordre : le premier vrai l'emporte.
- Les clauses de garde évitent les conditions imbriquées.
- Le `switch` fléché est une expression, sans `break`, qui doit couvrir tous les cas.
- for-each par défaut, `for` pour l'indice, `while` quand le nombre de tours est inconnu, `do-while` pour au moins un passage.
- Une boucle `while` doit contenir ce qui rendra sa condition fausse.

## Pour aller plus loin

- Le tutoriel officiel sur les structures de contrôle : [dev.java/learn/language-basics/controlling-flow](https://dev.java/learn/language-basics/controlling-flow/)
