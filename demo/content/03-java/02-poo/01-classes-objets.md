## Objectifs

- Comprendre pourquoi la programmation orientée objet existe
- Définir une classe avec ses attributs et ses méthodes
- Créer des objets et comprendre ce qu'est une référence
- Garantir un objet valide dès sa création avec un constructeur
- Protéger l'état d'un objet grâce à l'encapsulation
- Utiliser les membres statiques, `toString`, `equals` et les records

## Le besoin

Avec ce que nous savons déjà, voici comment on pourrait gérer trois apprenants :

```java
String prenom1 = "Emma";   int xp1 = 120;   String email1 = "emma@exemple.fr";
String prenom2 = "Lucas";  int xp2 = 80;    String email2 = "lucas@exemple.fr";
String prenom3 = "Nina";   int xp3 = 450;   String email3 = "nina@exemple.fr";

xp2 = -500;   // rien ne l'interdit
```

Plusieurs problèmes apparaissent vite :

- les données d'un même apprenant sont **éparpillées** dans des variables sans lien entre elles ;
- avec 300 apprenants, ce code devient ingérable ;
- **n'importe quelle ligne** du programme peut mettre une valeur absurde, comme une expérience négative ;
- les règles (« on ne gagne que des points positifs ») sont **dupliquées** partout où l'on modifie l'expérience, ou oubliées.

La programmation orientée objet (POO) répond à ces problèmes en **regroupant** les données et les comportements qui vont ensemble dans une même unité, qui se charge elle-même de faire respecter ses règles.

## Définitions

> **Classe.** Un modèle qui décrit une catégorie d'objets : les données qu'ils possèdent et les actions qu'ils savent faire. C'est un plan de construction.

> **Objet (instance).** Un exemplaire concret créé à partir d'une classe, avec ses propres valeurs.

> **Attribut (champ).** Une variable qui appartient à un objet et décrit son état : le prénom, l'expérience.

> **Méthode.** Une fonction définie dans une classe, qui décrit un comportement : gagner de l'expérience, afficher un résumé.

> **Constructeur.** Une méthode spéciale appelée à la création d'un objet pour l'initialiser.

> **Encapsulation.** Le principe qui consiste à cacher l'état interne d'un objet et à n'autoriser sa modification qu'à travers des méthodes qui font respecter les règles.

## Classe et objet

Une classe est au code ce qu'un plan est à une maison : le plan décrit les pièces, mais on n'habite pas dans un plan. On construit des maisons à partir du plan, chacune avec sa propre couleur de façade.

```java
public class Apprenant {

    private String prenom;
    private int xp;

    public Apprenant(String prenom) {
        this.prenom = prenom;
        this.xp = 0;
    }

    public void gagnerXp(int points) {
        xp += points;
    }

    public int getXp() {
        return xp;
    }

    public String getPrenom() {
        return prenom;
    }
}
```

```java
Apprenant emma = new Apprenant("Emma");
Apprenant lucas = new Apprenant("Lucas");

emma.gagnerXp(50);
emma.gagnerXp(30);

System.out.println(emma.getXp());    // 80
System.out.println(lucas.getXp());   // 0 : chaque objet a son propre état
```

- `new Apprenant("Emma")` **crée** un objet en mémoire et appelle le constructeur.
- Le point `.` permet d'appeler une méthode **sur un objet précis** : `emma.gagnerXp(50)` modifie l'expérience d'Emma, pas celle de Lucas.

## Les références

Une variable de type objet ne contient pas l'objet, mais une **référence** vers lui. Deux variables peuvent donc désigner le même objet :

```java
Apprenant a = new Apprenant("Emma");
Apprenant b = a;          // b désigne le MÊME objet que a

b.gagnerXp(100);
System.out.println(a.getXp());   // 100 : a et b sont deux noms pour un seul objet
```

```text
 a ──┐
     ├──► [ Apprenant : prenom = "Emma", xp = 100 ]
 b ──┘
```

Tant qu'aucune variable ne référence plus un objet, la JVM le supprime automatiquement de la mémoire : c'est le **ramasse-miettes** (garbage collector). En Java, on ne libère jamais la mémoire à la main.

## Le constructeur

Le constructeur porte le **nom de la classe** et n'a **pas de type de retour**. Son rôle est de garantir qu'un objet est **valide dès sa création** : impossible d'obtenir un apprenant sans prénom si le constructeur l'exige.

Le mot-clé `this` désigne l'objet en cours de construction. Il distingue l'attribut `this.prenom` du paramètre `prenom` qui porte le même nom.

Une classe peut avoir plusieurs constructeurs avec des paramètres différents : c'est la **surcharge**. Un constructeur peut en appeler un autre avec `this(...)` pour éviter de dupliquer la logique :

```java
public Apprenant(String prenom) {
    this(prenom, 0);                // délègue au constructeur complet
}

public Apprenant(String prenom, int xp) {
    this.prenom = prenom;
    this.xp = xp;
}
```

Si vous n'écrivez aucun constructeur, Java en fournit un **par défaut**, sans paramètre, qui laisse les attributs à leur valeur par défaut : `0` pour les nombres, `false` pour les booléens, `null` pour les objets.

## L'encapsulation

Les attributs sont déclarés `private` : **seul le code de la classe** peut les lire ou les modifier. L'extérieur passe par des méthodes publiques qui **font respecter les règles**.

```java
public void gagnerXp(int points) {
    if (points <= 0) {
        throw new IllegalArgumentException("Le gain d'XP doit être positif");
    }
    xp += points;
}
```

```java
emma.xp = -500;        // erreur de compilation : xp has private access in Apprenant
emma.gagnerXp(-500);   // refusé à l'exécution avec un message clair
```

La règle n'est écrite **qu'à un seul endroit**, dans la classe. Aucun code extérieur ne peut la contourner.

| Modificateur | Visible depuis |
|--------------|----------------|
| `private` | La classe elle-même |
| (aucun) | Les classes du même package |
| `protected` | Le package et les sous-classes |
| `public` | Partout |

Règle simple : commencez par `private` et n'ouvrez que ce qui est nécessaire.

## Getters et setters : avec mesure

Un **getter** lit un attribut (`getXp()`), un **setter** le modifie (`setXp(int xp)`). Beaucoup d'outils les génèrent automatiquement pour chaque attribut. C'est un réflexe à questionner : un setter public sans contrôle sur chaque champ revient à rendre l'attribut public, et l'encapsulation disparaît.

Préférez des méthodes qui expriment une **intention métier** :

| Au lieu de | Préférez | Pourquoi |
|------------|----------|----------|
| `setXp(getXp() + 50)` | `gagnerXp(50)` | La règle vit dans la classe |
| `setSolde(solde - 100)` | `retirer(100)` | Le découvert autorisé est vérifié |
| `setStatut("VALIDE")` | `valider()` | Impossible de mettre un statut inventé |

## Les membres statiques

Un attribut ou une méthode `static` appartient à la **classe** et non à chaque objet. Tous les objets le partagent.

```java
public class Apprenant {

    private static int nombreInscrits = 0;

    private final String prenom;

    public Apprenant(String prenom) {
        this.prenom = prenom;
        nombreInscrits++;
    }

    public static int getNombreInscrits() {
        return nombreInscrits;
    }
}
```

```java
new Apprenant("Emma");
new Apprenant("Lucas");
System.out.println(Apprenant.getNombreInscrits());   // 2
```

On appelle un membre statique sur la **classe** (`Apprenant.getNombreInscrits()`), pas sur un objet. `Math.round()` ou `Integer.parseInt()` sont des méthodes statiques. Une méthode statique n'a pas de `this` : elle ne peut pas accéder aux attributs d'un objet.

## toString et equals

Toute classe hérite de méthodes générales définies dans la classe `Object`. Deux d'entre elles méritent d'être redéfinies.

`toString` renvoie une représentation textuelle de l'objet, utilisée par `println` et dans les journaux. Par défaut, elle affiche quelque chose comme `Apprenant@1b6d3586`, peu utile.

```java
@Override
public String toString() {
    return "Apprenant[prenom=" + prenom + ", xp=" + xp + "]";
}
```

`equals` décide si deux objets sont **égaux par leur contenu**. Par défaut, il se comporte comme `==` et compare les références. Quand on redéfinit `equals`, il faut **toujours** redéfinir aussi `hashCode`, sinon les objets se comportent mal dans les collections comme `HashSet` ou `HashMap`.

## Les records

Beaucoup de classes n'ont qu'un rôle : **transporter des données immuables**. Écrire pour elles le constructeur, les accesseurs, `equals`, `hashCode` et `toString` représente des dizaines de lignes sans intérêt. Java 16 a introduit les **records** pour ce cas :

```java
public record Note(String matiere, double valeur) {

    public Note {
        if (valeur < 0 || valeur > 20) {
            throw new IllegalArgumentException("Note hors bornes : " + valeur);
        }
    }
}
```

```java
Note note = new Note("Java", 15.5);
System.out.println(note.valeur());    // 15.5 : l'accesseur porte le nom du composant
System.out.println(note);             // Note[matiere=Java, valeur=15.5]
System.out.println(note.equals(new Note("Java", 15.5)));   // true
```

Le bloc `public Note { ... }` est un **constructeur compact** : il valide les données avant l'affectation automatique des champs. Les champs d'un record sont `final` : un record est immuable.

| | Classe classique | Record |
|---|------------------|--------|
| État modifiable | Oui | Non |
| Constructeur, accesseurs, `equals`, `hashCode`, `toString` | À écrire | Générés |
| Usage typique | Objet avec un comportement et un état qui évolue | Valeur ou donnée transportée (DTO) |

## Exemple complet

Un apprenant avec des règles de progression : l'expérience ne baisse jamais, et un niveau est calculé à partir de l'expérience.

```java
public class Apprenant {

    private static final int XP_PAR_NIVEAU = 100;

    private final String prenom;
    private final String email;
    private int xp;

    public Apprenant(String prenom, String email) {
        if (prenom == null || prenom.isBlank()) {
            throw new IllegalArgumentException("Le prénom est obligatoire");
        }
        if (email == null || !email.contains("@")) {
            throw new IllegalArgumentException("L'adresse e-mail est invalide");
        }
        this.prenom = prenom;
        this.email = email;
    }

    public void gagnerXp(int points) {
        if (points <= 0) {
            throw new IllegalArgumentException("Le gain d'XP doit être positif");
        }
        xp += points;
    }

    public int niveau() {
        return xp / XP_PAR_NIVEAU + 1;
    }

    public int getXp() {
        return xp;
    }

    @Override
    public String toString() {
        return prenom + " (niveau " + niveau() + ", " + xp + " XP)";
    }
}
```

```java
Apprenant emma = new Apprenant("Emma", "emma@exemple.fr");
emma.gagnerXp(120);
emma.gagnerXp(45);
System.out.println(emma);   // Emma (niveau 2, 165 XP)
```

Le prénom et l'e-mail sont `final` : fixés à la création, ils ne changent plus. L'expérience ne peut évoluer qu'à travers `gagnerXp`. Et le niveau n'est pas stocké mais **calculé**, il ne peut donc jamais être incohérent avec l'expérience.

## Les erreurs fréquentes

- **Des attributs `public`**, ou des setters sans contrôle pour chaque champ.
- **Oublier `new`** et appeler une méthode sur une variable qui vaut `null`.
- **Confondre la classe et l'objet**, par exemple en rendant `static` un attribut propre à chaque objet : tous les apprenants partageraient alors la même expérience.
- **Un constructeur qui laisse l'objet invalide**, obligeant à appeler trois setters avant de pouvoir s'en servir.
- **Redéfinir `equals` sans `hashCode`.**

## Retour au besoin

Les neuf variables éparpillées du début deviennent trois objets `Apprenant`, chacun avec son propre état. La règle « l'expérience ne baisse jamais » est écrite une seule fois, dans la classe, et plus aucun code extérieur ne peut la contourner. Qu'il y ait 3 ou 3 000 apprenants, le code reste le même. C'est la base de toute la programmation en Java, et de frameworks comme Spring Boot.

## À retenir

- Une classe est un modèle, un objet en est une instance créée avec `new`.
- Une variable objet contient une référence : deux variables peuvent désigner le même objet.
- Le constructeur rend l'objet valide dès sa création.
- Les attributs sont `private`, les règles métier vivent dans des méthodes qui expriment une intention.
- Un record est la bonne forme pour des données immuables.

## Pour aller plus loin

- Le tutoriel officiel sur les classes et les objets : [dev.java/learn/classes-objects](https://dev.java/learn/classes-objects/)
