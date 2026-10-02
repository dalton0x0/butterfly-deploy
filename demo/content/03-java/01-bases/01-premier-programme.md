## Objectifs

- Comprendre comment un programme passe du code source à l'exécution
- Connaître le rôle du JDK, du compilateur `javac` et de la JVM
- Écrire, compiler et exécuter un premier programme
- Lire la structure minimale d'une classe Java et la signature de `main`
- Afficher du texte et commenter son code

## Le besoin

Un ordinateur ne comprend qu'une seule langue : le **langage machine**, une suite d'instructions binaires propres à son processeur. Un programme écrit pour un processeur Intel sous Windows ne fonctionne pas tel quel sur un Mac à processeur Apple, ni sur un serveur Linux.

Écrire directement en langage machine est impossible à grande échelle. Les développeurs écrivent donc dans un **langage de programmation** lisible par un humain, puis le transforment en instructions machine. Deux approches historiques existent :

- **compiler** le programme pour chaque système : c'est rapide à l'exécution, mais il faut produire et distribuer une version par plateforme ;
- **interpréter** le code source à la volée : c'est portable, mais plus lent et les erreurs n'apparaissent qu'à l'exécution.

Dans les années 1990, Sun Microsystems voulait un langage capable de faire tourner le **même programme** sur des appareils très différents, sans le recompiler. Java est né de ce besoin, avec une promesse : « écrire une fois, exécuter partout ».

## Définitions

> **Code source.** Le programme tel que le développeur l'écrit, dans un fichier texte `.java`.

> **Compilateur (`javac`).** L'outil qui vérifie le code source et le traduit en bytecode. Il détecte les erreurs de syntaxe et de type avant toute exécution.

> **Bytecode.** Un code intermédiaire, stocké dans des fichiers `.class`, indépendant du processeur et du système d'exploitation.

> **JVM (Java Virtual Machine).** Le programme qui exécute le bytecode sur une machine donnée. Il existe une JVM pour chaque système : c'est elle qui s'adapte, pas votre programme.

> **JDK (Java Development Kit).** Le kit du développeur : compilateur, JVM et outils. C'est ce que l'on installe pour programmer en Java.

> **Classe.** L'unité de base d'un programme Java. Tout le code se trouve à l'intérieur d'une classe.

## Du code source à l'exécution

Java combine les deux approches : il **compile** vers un format intermédiaire, puis ce format est **exécuté** par une machine virtuelle.

```text
 HelloWorld.java  ──javac──►  HelloWorld.class  ──java──►  JVM Windows  ──►  processeur Intel
 (code source)               (bytecode, portable)          JVM macOS    ──►  processeur Apple
                                                            JVM Linux    ──►  processeur du serveur
```

Le même fichier `.class` fonctionne partout où une JVM est installée. Et la JVM moderne ne se contente pas d'interpréter : elle repère les parties du code les plus utilisées et les **compile en langage machine** pendant l'exécution (compilation JIT, « juste à temps »). C'est ce qui rend Java très performant sur les applications qui tournent longtemps, comme les serveurs.

| Élément | Rôle | Qui l'utilise |
|---------|------|---------------|
| JDK | Kit complet : `javac`, `java`, outils de diagnostic | Le développeur |
| JRE | Environnement d'exécution seul, sans compilateur | Historiquement, l'utilisateur final |
| JVM | Machine virtuelle qui exécute le bytecode | Tout le monde, via `java` |

## Installer le JDK

Installez un JDK en version **21 ou plus récente**. Les versions dites **LTS** (support à long terme), comme 21 et 25, sont celles que l'on rencontre en entreprise : elles reçoivent des correctifs pendant plusieurs années. Plusieurs distributions gratuites existent, par exemple Eclipse Temurin.

```bash
java -version
javac -version
```

```text
openjdk version "21.0.4" 2024-07-16 LTS
javac 21.0.4
```

## Le premier programme

Créez un fichier nommé exactement `HelloWorld.java` :

```java
public class HelloWorld {

    public static void main(String[] args) {
        System.out.println("Bonjour Butterfly !");
    }
}
```

Décomposons-le :

| Élément | Rôle |
|---------|------|
| `public class HelloWorld` | Déclare une classe publique nommée `HelloWorld` |
| `{ ... }` | Les accolades délimitent un bloc : le contenu de la classe, puis celui de la méthode |
| `public static void main(String[] args)` | Le point d'entrée : la méthode que la JVM appelle au démarrage |
| `System.out.println(...)` | Affiche un texte dans la console, suivi d'un retour à la ligne |
| `;` | Termine chaque instruction |

Règles à retenir dès maintenant :

- Le nom du fichier doit correspondre **exactement** au nom de la classe publique : `HelloWorld.java` contient `public class HelloWorld`. Sinon, le compilateur refuse le fichier.
- Java est **sensible à la casse** : `System`, `system` et `SYSTEM` sont trois noms différents.
- Par convention, un nom de classe commence par une majuscule et suit le style **PascalCase** : `CalculMoyenne`, `CompteBancaire`.

## Compiler et exécuter

Depuis un terminal placé dans le dossier du fichier :

```bash
javac HelloWorld.java   # compile : produit HelloWorld.class
java HelloWorld         # exécute : on donne le nom de la classe, sans extension
```

```text
Bonjour Butterfly !
```

Depuis Java 11, il est aussi possible de lancer directement un fichier source unique : `java HelloWorld.java`. La compilation se fait alors en mémoire. C'est pratique pour tester une idée, mais un vrai projet passe toujours par une compilation explicite, le plus souvent pilotée par un outil de construction comme **Maven** ou **Gradle** et lancée depuis un IDE comme IntelliJ IDEA.

## Lire une erreur de compilation

Oublions un point-virgule :

```java
System.out.println("Bonjour Butterfly !")
```

```text
HelloWorld.java:4: error: ';' expected
        System.out.println("Bonjour Butterfly !")
                                                 ^
1 error
```

Le compilateur indique le **fichier**, le **numéro de ligne**, la **nature** de l'erreur et un `^` sous l'endroit précis. Lisez toujours la **première** erreur en premier : les suivantes en sont souvent la conséquence.

C'est un avantage majeur d'un langage compilé : beaucoup d'erreurs sont détectées **avant** que le programme ne tourne, et non devant l'utilisateur.

## La signature de main

```java
public static void main(String[] args)
```

| Mot | Signification |
|-----|---------------|
| `public` | La méthode est accessible depuis l'extérieur de la classe, donc par la JVM |
| `static` | Elle appartient à la classe et non à un objet : la JVM peut l'appeler sans rien créer |
| `void` | Elle ne renvoie aucune valeur |
| `main` | Le nom que la JVM cherche au démarrage |
| `String[] args` | Les arguments passés en ligne de commande, sous forme de tableau de textes |

```java
public class Salutation {

    public static void main(String[] args) {
        System.out.println("Bonjour " + args[0] + " !");
    }
}
```

```bash
java Salutation Emma
```

```text
Bonjour Emma !
```

L'opérateur `+` entre deux textes les **concatène**. Sans argument, `args[0]` n'existe pas et le programme s'arrête sur une erreur : nous verrons au module 3 comment gérer ce genre de situation.

> **Bon à savoir.** Java 25 a finalisé une écriture simplifiée pour les petits programmes : une méthode `void main()` sans classe déclarée ni paramètre. Elle facilite les débuts, mais le code professionnel que vous lirez utilise encore la forme complète présentée ici.

## Afficher du texte

```java
System.out.println("Une ligne");            // affiche puis passe à la ligne
System.out.print("Sans retour ");           // affiche sans passer à la ligne
System.out.println("à la ligne");
System.out.printf("Total : %d apprenants, moyenne %.2f%n", 12, 13.456);
```

```text
Une ligne
Sans retour à la ligne
Total : 12 apprenants, moyenne 13,46
```

`printf` utilise des **marqueurs** remplacés par les valeurs : `%d` pour un entier, `%.2f` pour un décimal avec deux chiffres après la virgule, `%s` pour un texte, `%n` pour un retour à la ligne. Le séparateur décimal dépend de la langue du système.

## Les commentaires

```java
// Commentaire sur une ligne

/*
 * Commentaire
 * sur plusieurs lignes
 */

/**
 * Commentaire de documentation (Javadoc), placé au-dessus
 * d'une classe ou d'une méthode. L'outil javadoc en génère une documentation HTML.
 */
```

Un bon commentaire explique **pourquoi** le code fait quelque chose, pas **ce qu'il** fait. `// affiche le message` au-dessus d'un `println` n'apporte rien. `// La JVM exige cette signature exacte pour démarrer` explique une contrainte qui ne se devine pas.

## Exemple complet

Un programme qui présente un apprenant à partir des arguments reçus :

```java
/**
 * Affiche une carte de présentation à partir du prénom et de la formation
 * passés en ligne de commande.
 */
public class CartePresentation {

    public static void main(String[] args) {
        String prenom = args[0];
        String formation = args[1];

        System.out.println("==============================");
        System.out.printf("Apprenant : %s%n", prenom);
        System.out.printf("Formation : %s%n", formation);
        System.out.println("==============================");
    }
}
```

```bash
javac CartePresentation.java
java CartePresentation Emma Java
```

```text
==============================
Apprenant : Emma
Formation : Java
==============================
```

## Les erreurs fréquentes

- **Un nom de fichier différent du nom de la classe**, ou une casse différente : `helloworld.java` pour `HelloWorld`.
- **`java HelloWorld.class`** au lieu de `java HelloWorld`.
- **Oublier un point-virgule ou une accolade fermante.**
- **Modifier le `.java` sans recompiler**, et s'étonner que rien ne change.
- **Installer un JRE au lieu d'un JDK**, et ne pas trouver `javac`.

## Retour au besoin

Le programme `HelloWorld` a été écrit une seule fois. Compilé en bytecode, il s'exécute à l'identique sous Windows, macOS ou Linux, parce que chaque système dispose de sa propre JVM. Le compilateur, lui, a vérifié le code avant son exécution. C'est cette combinaison de portabilité et de rigueur qui a fait de Java l'un des langages les plus utilisés en entreprise, notamment pour les applications serveur comme celles construites avec Spring Boot.

## À retenir

- Le code source `.java` est compilé en bytecode `.class` par `javac`.
- La JVM exécute ce bytecode sur n'importe quel système : « écrire une fois, exécuter partout ».
- Le point d'entrée d'un programme est la méthode `public static void main(String[] args)`.
- Le nom du fichier suit exactement le nom de la classe publique qu'il contient.
- Une erreur de compilation se lit par sa première ligne : fichier, numéro de ligne, nature.

## Pour aller plus loin

- Le site officiel d'apprentissage de Java : [dev.java/learn](https://dev.java/learn/)
