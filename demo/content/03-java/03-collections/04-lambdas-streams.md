## Objectifs

- Comprendre la différence entre style impératif et style déclaratif
- Écrire une expression lambda et une référence de méthode
- Connaître les principales interfaces fonctionnelles
- Construire un pipeline avec la Stream API : filtrer, transformer, trier, agréger
- Regrouper des données avec les collecteurs
- Traiter l'absence de résultat avec `Optional`

## Le besoin

On veut les prénoms des apprenants ayant au moins 150 XP, triés par expérience décroissante. En style classique :

```java
List<Apprenant> selection = new ArrayList<>();
for (Apprenant a : apprenants) {
    if (a.xp() >= 150) {
        selection.add(a);
    }
}
selection.sort(new Comparator<Apprenant>() {
    @Override
    public int compare(Apprenant a, Apprenant b) {
        return Integer.compare(b.xp(), a.xp());
    }
});
List<String> prenoms = new ArrayList<>();
for (Apprenant a : selection) {
    prenoms.add(a.prenom());
}
```

Quinze lignes pour une idée qui tient en une phrase. Le code décrit **comment** faire (créer une liste, boucler, tester, ajouter), et il faut le relire attentivement pour comprendre **ce qu'il** fait. Chaque boucle est aussi une occasion de se tromper.

Depuis Java 8, on peut écrire la même chose en décrivant directement le résultat voulu :

```java
List<String> prenoms = apprenants.stream()
        .filter(a -> a.xp() >= 150)
        .sorted(Comparator.comparingInt(Apprenant::xp).reversed())
        .map(Apprenant::prenom)
        .toList();
```

Chaque ligne se lit comme une étape de la phrase : garder, trier, extraire. Ce cours présente les deux outils qui rendent cette écriture possible : les **lambdas** et les **streams**.

## Définitions

> **Style impératif.** On décrit pas à pas **comment** obtenir un résultat : boucles, variables temporaires, conditions.

> **Style déclaratif.** On décrit **ce que** l'on veut obtenir, et la bibliothèque se charge du comment.

> **Expression lambda.** Une fonction anonyme, écrite de façon concise, que l'on peut passer en paramètre comme une valeur.

> **Interface fonctionnelle.** Une interface qui ne déclare qu'une seule méthode abstraite. Une lambda en est une implémentation.

> **Référence de méthode.** Une écriture encore plus courte d'une lambda qui se contente d'appeler une méthode existante : `Apprenant::prenom`.

> **Stream.** Une suite d'éléments sur laquelle on enchaîne des opérations. Un stream ne stocke rien : il décrit un traitement appliqué à une source.

## Les expressions lambda

Une lambda s'écrit `(paramètres) -> expression` :

```java
Predicate<Integer> estAdmis = note -> note >= 10;
Function<String, Integer> longueur = texte -> texte.length();
Comparator<String> parLongueur = (a, b) -> Integer.compare(a.length(), b.length());
BinaryOperator<Integer> somme = (a, b) -> a + b;

estAdmis.test(12);        // true
longueur.apply("Java");   // 4
somme.apply(3, 4);        // 7
```

| Forme | Exemple |
|-------|---------|
| Un paramètre, parenthèses facultatives | `note -> note >= 10` |
| Plusieurs paramètres | `(a, b) -> a + b` |
| Aucun paramètre | `() -> "Bonjour"` |
| Plusieurs instructions | `x -> { int y = x * 2; return y + 1; }` |

Une lambda n'est pas magique : elle est la version courte d'une classe anonyme qui implémente une interface. Les deux écritures suivantes sont équivalentes :

```java
Predicate<Integer> estAdmis = new Predicate<Integer>() {
    @Override
    public boolean test(Integer note) {
        return note >= 10;
    }
};

Predicate<Integer> estAdmis = note -> note >= 10;
```

## Les interfaces fonctionnelles courantes

Le package `java.util.function` fournit les interfaces les plus utiles :

| Interface | Méthode | Rôle | Exemple |
|-----------|---------|------|---------|
| `Predicate<T>` | `boolean test(T)` | Tester une condition, filtrer | `a -> a.xp() > 100` |
| `Function<T, R>` | `R apply(T)` | Transformer un T en R | `a -> a.prenom()` |
| `Consumer<T>` | `void accept(T)` | Consommer une valeur sans rien renvoyer | `a -> System.out.println(a)` |
| `Supplier<T>` | `T get()` | Fournir une valeur | `() -> new ArrayList<>()` |
| `BinaryOperator<T>` | `T apply(T, T)` | Combiner deux valeurs | `(a, b) -> a + b` |

## Les références de méthode

Quand une lambda se contente d'appeler une méthode existante, une **référence de méthode** est plus lisible :

| Lambda | Référence de méthode | Type |
|--------|----------------------|------|
| `a -> a.prenom()` | `Apprenant::prenom` | Méthode d'instance de l'élément |
| `texte -> Integer.parseInt(texte)` | `Integer::parseInt` | Méthode statique |
| `x -> System.out.println(x)` | `System.out::println` | Méthode d'un objet précis |
| `() -> new ArrayList<>()` | `ArrayList::new` | Constructeur |

## La Stream API

Reprenons l'exemple d'une liste d'apprenants :

```java
record Apprenant(String prenom, String promo, int xp) {}

List<Apprenant> apprenants = List.of(
        new Apprenant("Emma", "2026", 320),
        new Apprenant("Lucas", "2026", 180),
        new Apprenant("Nina", "2025", 450),
        new Apprenant("Hugo", "2026", 90)
);
```

Un **pipeline** comporte trois parties :

```text
 source          opérations intermédiaires                      opération terminale
apprenants  ──►  filter(...)  ──►  sorted(...)  ──►  map(...)  ──►  toList()
 .stream()       garde             trie              transforme      produit le résultat
```

1. Une **source** : `liste.stream()`, `Stream.of(...)`, `Arrays.stream(tableau)`.
2. Des opérations **intermédiaires**, qui renvoient un nouveau stream et s'enchaînent.
3. Une opération **terminale**, qui déclenche le calcul et produit le résultat.

| Opération intermédiaire | Rôle |
|-------------------------|------|
| `filter(predicat)` | Garde les éléments qui vérifient la condition |
| `map(fonction)` | Transforme chaque élément |
| `sorted()`, `sorted(comparateur)` | Trie |
| `distinct()` | Supprime les doublons |
| `limit(n)`, `skip(n)` | Garde les n premiers, ignore les n premiers |

| Opération terminale | Résultat |
|---------------------|----------|
| `toList()` | Une liste non modifiable |
| `count()` | Le nombre d'éléments |
| `forEach(action)` | Applique une action à chaque élément |
| `anyMatch`, `allMatch`, `noneMatch` | Un booléen |
| `findFirst()`, `max(...)`, `min(...)` | Un `Optional` |
| `collect(collecteur)` | Une collection ou une `Map` construite sur mesure |

```java
List<String> meilleurs = apprenants.stream()
        .filter(a -> a.xp() >= 150)
        .sorted(Comparator.comparingInt(Apprenant::xp).reversed())
        .map(Apprenant::prenom)
        .toList();                                        // [Nina, Emma, Lucas]
```

### Deux propriétés essentielles

- **Les opérations intermédiaires sont paresseuses.** Rien n'est calculé tant qu'aucune opération terminale n'est appelée. Un pipeline sans opération terminale ne fait rien.
- **Un stream ne se consomme qu'une fois.** Pour un deuxième traitement, on en crée un nouveau à partir de la source.

Un stream ne **modifie jamais** la collection source : il produit un nouveau résultat.

## Agréger des valeurs

Les streams spécialisés `IntStream`, `LongStream` et `DoubleStream` fournissent des opérations numériques. On y passe avec `mapToInt`, `mapToDouble`...

```java
int totalXp = apprenants.stream()
        .mapToInt(Apprenant::xp)
        .sum();                                  // 1040

double moyenne = apprenants.stream()
        .mapToInt(Apprenant::xp)
        .average()
        .orElse(0);                              // 260.0

boolean tousActifs = apprenants.stream()
        .allMatch(a -> a.xp() > 0);              // true

long debutants = apprenants.stream()
        .filter(a -> a.xp() < 100)
        .count();                                // 1
```

`average` renvoie un `OptionalDouble` : une liste vide n'a pas de moyenne. `orElse` fournit la valeur de repli.

## Regrouper avec les collecteurs

`collect` construit un résultat sur mesure grâce à la classe `Collectors`. Le plus utile est `groupingBy`, l'équivalent d'un `GROUP BY` en SQL :

```java
Map<String, List<Apprenant>> parPromo = apprenants.stream()
        .collect(Collectors.groupingBy(Apprenant::promo));

Map<String, Long> effectifParPromo = apprenants.stream()
        .collect(Collectors.groupingBy(Apprenant::promo, Collectors.counting()));
// 2025 : 1 apprenant, 2026 : 3 apprenants (l'ordre d'une HashMap n'est pas garanti)

Map<String, Double> xpMoyenParPromo = apprenants.stream()
        .collect(Collectors.groupingBy(Apprenant::promo, Collectors.averagingInt(Apprenant::xp)));

String liste = apprenants.stream()
        .map(Apprenant::prenom)
        .collect(Collectors.joining(", "));      // "Emma, Lucas, Nina, Hugo"

Map<Boolean, List<Apprenant>> separes = apprenants.stream()
        .collect(Collectors.partitioningBy(a -> a.xp() >= 200));
```

## Optional : rendre l'absence explicite

`findFirst`, `max` ou `min` peuvent ne rien trouver. Plutôt que de renvoyer `null`, source de `NullPointerException`, ils renvoient un `Optional` : une **boîte** qui contient une valeur ou rien.

```java
Optional<Apprenant> meilleur = apprenants.stream()
        .max(Comparator.comparingInt(Apprenant::xp));

String prenom = apprenants.stream()
        .filter(a -> a.promo().equals("2024"))
        .map(Apprenant::prenom)
        .findFirst()
        .orElse("Aucun apprenant");
```

| Méthode | Rôle |
|---------|------|
| `orElse(valeur)` | Valeur de repli si la boîte est vide |
| `orElseThrow(() -> ...)` | Lever une exception si la boîte est vide |
| `ifPresent(action)` | Agir seulement si une valeur est présente |
| `map(fonction)` | Transformer la valeur si elle existe |
| `isPresent()`, `isEmpty()` | Tester le contenu |

Évitez `get()` sans vérification : il lève une exception sur une boîte vide, ce qui ramène exactement le problème que `Optional` voulait éviter. Dans Spring Data, `findById` renvoie un `Optional`, et l'on écrit typiquement `repository.findById(id).orElseThrow(() -> new ResourceNotFoundException(...))`.

## Boucle ou stream ?

Un stream n'est pas toujours plus lisible qu'une boucle.

| Préférez un stream pour | Préférez une boucle pour |
|-------------------------|--------------------------|
| Filtrer, transformer, trier, agréger | Un traitement avec des effets de bord complexes |
| Regrouper et compter | Une logique qui s'interrompt selon des règles élaborées |
| Un traitement qui se lit comme une phrase | Un algorithme qui manipule des indices |

Et une règle importante : une lambda ne doit pas **modifier une variable extérieure**. Le compilateur l'interdit d'ailleurs pour les variables locales, qui doivent être effectivement `final`.

```java
int total = 0;
apprenants.forEach(a -> total += a.xp());     // erreur de compilation
int total = apprenants.stream().mapToInt(Apprenant::xp).sum();   // correct
```

## Exemple complet

Un tableau de bord des résultats d'une session :

```java
record Resultat(String apprenant, String matiere, double note) {}

List<Resultat> resultats = List.of(
        new Resultat("Emma", "Java", 16.5), new Resultat("Emma", "SQL", 14),
        new Resultat("Lucas", "Java", 9.5), new Resultat("Lucas", "SQL", 12),
        new Resultat("Nina", "Java", 18), new Resultat("Nina", "SQL", 17.5)
);

Map<String, Double> moyenneParApprenant = resultats.stream()
        .collect(Collectors.groupingBy(Resultat::apprenant,
                TreeMap::new,
                Collectors.averagingDouble(Resultat::note)));

String majorJava = resultats.stream()
        .filter(r -> r.matiere().equals("Java"))
        .max(Comparator.comparingDouble(Resultat::note))
        .map(Resultat::apprenant)
        .orElse("Aucun");

List<String> enDifficulte = moyenneParApprenant.entrySet().stream()
        .filter(e -> e.getValue() < 12)
        .map(Map.Entry::getKey)
        .toList();

System.out.println(moyenneParApprenant);   // {Emma=15.25, Lucas=10.75, Nina=17.75}
System.out.println(majorJava);             // Nina
System.out.println(enDifficulte);          // [Lucas]
```

La variante de `groupingBy` avec `TreeMap::new` choisit le type de `Map` produit : ici, une `TreeMap` pour obtenir les apprenants triés par ordre alphabétique.

## Les erreurs fréquentes

- **Oublier l'opération terminale**, et un pipeline qui ne fait rien.
- **Réutiliser un stream déjà consommé** : `IllegalStateException`.
- **Appeler `get()` sur un `Optional`** sans vérifier qu'il contient une valeur.
- **Modifier une collection extérieure depuis une lambda** au lieu de collecter le résultat.
- **Des pipelines de quinze étapes** : découpez-les en méthodes bien nommées.

## Retour au besoin

Les quinze lignes du début tiennent en cinq, qui se lisent comme la phrase qu'elles traduisent. Les lambdas permettent de passer un comportement en paramètre, les streams d'enchaîner filtrage, transformation, tri et agrégation sans boucle ni variable temporaire. Et `Optional` rend explicite le cas où rien n'est trouvé. Ces outils sont omniprésents dans le code Java moderne, et notamment dans les applications Spring Boot.

## À retenir

- Une lambda implémente une interface fonctionnelle en une ligne, une référence de méthode encore plus simplement.
- Un pipeline : une source, des opérations intermédiaires, une opération terminale.
- Rien n'est calculé avant l'opération terminale, et un stream ne se consomme qu'une fois.
- `groupingBy` regroupe comme un `GROUP BY`, `Optional` rend l'absence de résultat explicite.
- Stream pour filtrer, transformer et agréger, boucle pour une logique complexe à effets de bord.

## Pour aller plus loin

- Le tutoriel officiel sur les lambdas : [dev.java/learn/lambdas](https://dev.java/learn/lambdas/)
- Le tutoriel officiel sur la Stream API : [dev.java/learn/api/streams](https://dev.java/learn/api/streams/)
