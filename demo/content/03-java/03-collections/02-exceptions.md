## Objectifs

- Comprendre ce qu'est une exception et comment elle se propage
- Lire une trace de pile pour trouver l'origine d'une erreur
- Distinguer exceptions vérifiées et non vérifiées
- Capturer une exception avec `try-catch-finally`
- Libérer des ressources avec `try-with-resources`
- Lever une exception et créer une exception métier

## Le besoin

Un programme rencontre forcément des situations qui l'empêchent de continuer normalement :

- l'utilisateur tape « douze » là où l'on attend un nombre ;
- le fichier de notes à importer n'existe pas ;
- un apprenant tente de retirer plus d'argent que son solde ne le permet ;
- la connexion à la base de données est coupée.

Une ancienne approche consiste à renvoyer un **code d'erreur** : `-1` pour « introuvable », `false` pour « échec ».

```java
int resultat = retirer(compte, 500);
if (resultat == -1) { ... }        // encore faut-il penser à le tester
```

Ce système a de graves défauts : rien n'oblige l'appelant à vérifier le code, le code ne dit pas **pourquoi** l'opération a échoué, et il se mélange avec les vraies valeurs de retour. Oublier un test, et le programme continue avec une donnée fausse.

Java utilise un mécanisme qui **interrompt** le déroulement normal et ne peut pas passer inaperçu : les exceptions.

## Définitions

> **Exception.** Un objet qui représente une situation anormale. Elle est « levée » (lancée) au point où le problème survient et interrompt l'exécution normale.

> **Propagation.** Une exception non traitée remonte de méthode appelante en méthode appelante, jusqu'à trouver un bloc qui la capture.

> **Capture.** Le fait d'intercepter une exception avec un bloc `catch` pour la traiter.

> **Pile d'appels.** La liste des méthodes en cours d'exécution, chacune appelée par la précédente, depuis `main`.

> **Trace de pile (stack trace).** L'affichage de la pile d'appels au moment où l'exception a été levée. C'est l'outil principal pour localiser un bug.

> **Exception métier.** Une exception créée par le développeur pour représenter la violation d'une règle du domaine, comme un solde insuffisant.

## La propagation

Quand une exception est levée, la méthode s'arrête immédiatement. L'exception remonte vers la méthode appelante, puis vers la suivante, jusqu'à ce qu'un bloc `catch` la capture. Si personne ne la capture, le programme s'arrête et affiche la trace de pile.

```java
public class Demo {

    public static void main(String[] args) {
        afficherMoyenne("douze");
    }

    static void afficherMoyenne(String saisie) {
        int note = convertir(saisie);
        System.out.println(note);
    }

    static int convertir(String texte) {
        return Integer.parseInt(texte);
    }
}
```

```text
Exception in thread "main" java.lang.NumberFormatException: For input string: "douze"
    at java.base/java.lang.Integer.parseInt(Integer.java:661)
    at Demo.convertir(Demo.java:13)
    at Demo.afficherMoyenne(Demo.java:8)
    at Demo.main(Demo.java:4)
```

## Lire une trace de pile

Une trace se lit **de haut en bas** :

1. La **première ligne** donne le type de l'exception et son message : `NumberFormatException`, la chaîne « douze » n'est pas un nombre.
2. Les lignes `at` donnent la pile d'appels, de l'endroit de l'erreur vers `main`.
3. Cherchez la **première ligne qui concerne votre code** : `Demo.convertir(Demo.java:13)`. C'est là que tout commence, à la ligne 13.

Les lignes `java.base/...` appartiennent à la bibliothèque Java : le problème vient presque toujours de ce que votre code lui a transmis.

## La hiérarchie des exceptions

```text
Throwable
 ├── Error                        problèmes graves de la JVM : on ne les capture pas
 │    └── OutOfMemoryError
 └── Exception
      ├── IOException             vérifiée
      ├── SQLException            vérifiée
      └── RuntimeException        non vérifiée
           ├── NullPointerException
           ├── IllegalArgumentException
           ├── IllegalStateException
           ├── NumberFormatException
           └── IndexOutOfBoundsException
```

## Vérifiées ou non vérifiées

| Type | Exemple | Obligation | Signale généralement |
|------|---------|------------|----------------------|
| Vérifiée (checked) | `IOException` | Le compilateur impose de la capturer ou de la déclarer avec `throws` | Un problème **extérieur** que l'appelant peut traiter : fichier absent, réseau coupé |
| Non vérifiée (unchecked) | `IllegalArgumentException` | Aucune | Une **erreur de programmation** ou une règle métier violée |

```java
// Vérifiée : le compilateur exige un traitement
public String lireFichier(Path chemin) throws IOException {
    return Files.readString(chemin);
}
```

Le mot-clé `throws` dans la signature **déclare** que la méthode peut laisser passer cette exception. L'appelant doit alors à son tour la capturer ou la déclarer.

## Capturer avec try-catch-finally

```java
try {
    int age = Integer.parseInt(saisie);
    System.out.println("Âge : " + age);
} catch (NumberFormatException e) {
    System.out.println("Veuillez saisir un nombre entier.");
} finally {
    System.out.println("Saisie traitée.");
}
```

| Bloc | Rôle |
|------|------|
| `try` | Le code qui peut échouer |
| `catch` | Le traitement si une exception du type indiqué est levée. On peut en enchaîner plusieurs, du plus précis au plus général |
| `finally` | Exécuté dans tous les cas, exception ou non, par exemple pour libérer une ressource |

Plusieurs exceptions peuvent être traitées de la même façon : `catch (NumberFormatException | NullPointerException e)`.

L'objet `e` donne des informations utiles : `e.getMessage()` pour le message, et il se transmet à un journal pour conserver la trace complète.

### Ne jamais étouffer une exception

```java
try {
    enregistrer(apprenant);
} catch (Exception e) {
    // rien
}
```

Un bloc `catch` vide est l'une des pires pratiques : l'erreur disparaît sans laisser de trace, le programme continue avec des données fausses et le bug devient introuvable. Une exception capturée doit être **traitée**, **journalisée** ou **relancée**.

## Libérer les ressources avec try-with-resources

Un fichier, une connexion à une base ou un flux réseau doivent être **fermés** après usage, même en cas d'erreur. Sinon, le système finit par manquer de ressources. `try-with-resources` s'en charge automatiquement pour tout objet qui implémente l'interface `AutoCloseable`.

```java
try (BufferedReader lecteur = Files.newBufferedReader(Path.of("notes.txt"))) {
    String ligne;
    while ((ligne = lecteur.readLine()) != null) {
        System.out.println(ligne);
    }
} catch (IOException e) {
    System.out.println("Lecture impossible : " + e.getMessage());
}
```

La ressource déclarée entre parenthèses est fermée automatiquement à la sortie du bloc, qu'il se termine normalement ou par une exception. C'est plus court et plus sûr qu'un `finally` écrit à la main.

## Lever une exception

On lève une exception avec `throw` dès qu'une méthode reçoit une valeur qu'elle ne peut pas traiter. Échouer **tôt**, avec un message **clair**, évite qu'une donnée invalide se propage et provoque une erreur incompréhensible plus loin.

```java
public void inscrire(String email) {
    if (email == null || email.isBlank()) {
        throw new IllegalArgumentException("L'adresse e-mail est obligatoire");
    }
    // ...
}
```

| Exception standard | Quand la lever |
|--------------------|----------------|
| `IllegalArgumentException` | Un paramètre reçu est invalide |
| `IllegalStateException` | L'objet n'est pas dans un état qui permet l'opération : quiz déjà terminé, compte clôturé |
| `NullPointerException` | Un paramètre obligatoire vaut `null`, souvent via `Objects.requireNonNull(valeur, "message")` |
| `UnsupportedOperationException` | L'opération n'est pas prise en charge |

## Créer une exception métier

Une exception dédiée rend le code plus **expressif** et permet de la traiter **spécifiquement**.

```java
public class SoldeInsuffisantException extends RuntimeException {

    public SoldeInsuffisantException(double solde, double montant) {
        super("Solde insuffisant : " + solde + " € disponibles pour un retrait de " + montant + " €");
    }
}
```

```java
public void retirer(double montant) {
    if (montant > solde + decouvertAutorise) {
        throw new SoldeInsuffisantException(solde, montant);
    }
    solde -= montant;
}
```

```java
try {
    compte.retirer(500);
} catch (SoldeInsuffisantException e) {
    System.out.println("Retrait refusé : " + e.getMessage());
}
```

Dans une API Spring Boot, un **gestionnaire global** transforme ensuite chaque exception métier en réponse HTTP adaptée : `SoldeInsuffisantException` devient une erreur 409 avec un message lisible par le front.

Quand on capture une exception technique pour en lever une autre, on transmet l'originale comme **cause**, pour ne pas perdre la trace :

```java
catch (IOException e) {
    throw new ImportImpossibleException("Import du fichier de notes impossible", e);
}
```

## Capturer au bon endroit

On capture une exception **là où l'on sait quoi en faire**. Une méthode de bas niveau qui ne peut rien décider la laisse remonter. C'est la couche qui parle à l'utilisateur, un menu en console, un contrôleur web, qui choisit le message à afficher.

Capturer trop tôt oblige à inventer une valeur de repli qui cache le problème. Capturer trop tard, ou jamais, arrête le programme.

## Exemple complet

Importer des notes depuis un fichier, en signalant les lignes invalides sans arrêter l'import :

```java
public class ImportNotes {

    public static List<Double> importer(Path fichier) throws IOException {
        List<Double> notes = new ArrayList<>();
        int numeroLigne = 0;

        try (BufferedReader lecteur = Files.newBufferedReader(fichier)) {
            String ligne;
            while ((ligne = lecteur.readLine()) != null) {
                numeroLigne++;
                try {
                    notes.add(convertirNote(ligne));
                } catch (IllegalArgumentException e) {
                    System.out.println("Ligne " + numeroLigne + " ignorée : " + e.getMessage());
                }
            }
        }
        return notes;
    }

    private static double convertirNote(String texte) {
        double note = Double.parseDouble(texte.trim());
        if (note < 0 || note > 20) {
            throw new IllegalArgumentException("note hors bornes (" + note + ")");
        }
        return note;
    }
}
```

- `NumberFormatException` hérite de `IllegalArgumentException` : un seul `catch` traite à la fois le texte non numérique et la note hors bornes.
- Une ligne invalide est signalée, puis l'import continue.
- Un fichier absent, en revanche, est un problème que `importer` ne sait pas résoudre : l'`IOException` remonte à l'appelant, qui décidera quoi afficher.

## Les erreurs fréquentes

- **Un `catch` vide**, ou un `catch (Exception e)` qui avale tout.
- **Capturer `Exception` partout** au lieu du type précis attendu.
- **Utiliser les exceptions pour le déroulement normal**, par exemple pour sortir d'une boucle.
- **Perdre la cause** en relançant une nouvelle exception sans l'originale.
- **Oublier de fermer une ressource**, au lieu d'utiliser `try-with-resources`.
- **Des messages vagues** comme « Erreur » qui n'aident personne.

## Retour au besoin

Plus aucune erreur ne passe inaperçue : une exception interrompt le traitement et remonte jusqu'au code capable de la traiter. Le message et le type disent précisément ce qui s'est passé, et la trace de pile indique où. Les règles métier, comme le solde insuffisant, deviennent des exceptions nommées que l'interface peut transformer en messages clairs pour l'utilisateur.

## À retenir

- Une exception interrompt l'exécution et remonte la pile jusqu'à un `catch`.
- Une trace de pile se lit de haut en bas : type, message, puis première ligne de votre code.
- Les exceptions vérifiées doivent être capturées ou déclarées, les autres non.
- Un `catch` vide cache les erreurs : ne l'écrivez jamais.
- `try-with-resources` ferme les ressources automatiquement.
- Une exception métier nommée rend le code plus lisible qu'un message générique.

## Pour aller plus loin

- Le tutoriel officiel sur les exceptions : [dev.java/learn/exceptions](https://dev.java/learn/exceptions/)
