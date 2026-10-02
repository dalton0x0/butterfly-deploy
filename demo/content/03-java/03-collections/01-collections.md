## Objectifs

- Comprendre les limites des tableaux et l'intérêt des collections
- Connaître les trois grandes familles : `List`, `Set` et `Map`
- Choisir l'implémentation adaptée à un besoin
- Utiliser les génériques pour sécuriser le contenu d'une collection
- Parcourir, trier et modifier une collection sans erreur

## Le besoin

Pour gérer les inscrits d'une formation, un tableau semble suffire :

```java
String[] inscrits = new String[3];
inscrits[0] = "Emma";
inscrits[1] = "Lucas";
inscrits[2] = "Nina";
inscrits[3] = "Hugo";   // ArrayIndexOutOfBoundsException : le tableau est plein
```

Les tableaux montrent vite leurs limites :

- leur **taille est fixée** à la création : impossible d'ajouter un quatrième inscrit sans créer un nouveau tableau et tout recopier ;
- **supprimer** un élément laisse un trou qu'il faut combler à la main ;
- rien n'empêche d'inscrire **deux fois** la même personne ;
- pour retrouver l'expérience d'un apprenant à partir de son prénom, il faut parcourir tout le tableau.

Chaque programme finirait par réécrire ces opérations, avec ses propres bugs. Java fournit une bibliothèque de structures de données prêtes à l'emploi, testées et optimisées : les **collections**.

## Définitions

> **Collection.** Un objet qui regroupe un nombre variable d'éléments et fournit des opérations pour les ajouter, les retrouver, les parcourir et les supprimer.

> **Interface de collection.** Le contrat qui décrit ce qu'une famille de collections sait faire : `List`, `Set`, `Map`.

> **Implémentation.** Une classe concrète qui réalise ce contrat, avec ses propres performances : `ArrayList`, `HashSet`, `HashMap`.

> **Générique.** Un paramètre de type, écrit entre chevrons, qui précise ce que contient la collection : `List<String>` ne contient que des chaînes.

> **Immuable.** Qui ne peut pas être modifié après sa création.

## Interface et implémentation

Toutes les collections se trouvent dans le package `java.util`. On déclare la variable avec le type de l'**interface** et l'on choisit l'**implémentation** à droite :

```java
List<String> prenoms = new ArrayList<>();
```

Le reste du code ne dépend que du contrat `List`. Remplacer plus tard `ArrayList` par une autre implémentation ne demande de modifier qu'une seule ligne. C'est l'application directe du cours sur les interfaces.

## Les génériques

Les chevrons `<String>` indiquent que la liste ne contient que des `String`. Le compilateur le vérifie :

```java
List<String> prenoms = new ArrayList<>();
prenoms.add("Emma");
prenoms.add(42);                 // erreur de compilation

String premier = prenoms.get(0); // aucun cast nécessaire
```

L'opérateur losange `<>` à droite évite de répéter le type. Une collection ne stocke que des **objets** : pour des nombres, on utilise les classes enveloppes, `List<Integer>` et non `List<int>`.

## List : une suite ordonnée

Une `List` conserve l'**ordre d'insertion**, accepte les **doublons** et donne accès aux éléments par leur **indice**.

```java
List<String> modules = new ArrayList<>();
modules.add("Bases");
modules.add("POO");
modules.add("Collections");
modules.add(1, "Outils");         // insertion à l'indice 1

modules.get(0);                   // "Bases"
modules.size();                   // 4
modules.contains("POO");          // true
modules.indexOf("POO");           // 2
modules.remove("Bases");          // suppression par valeur
modules.set(0, "Outils avancés"); // remplacement
modules.isEmpty();                // false
```

| Implémentation | Points forts | Point faible |
|----------------|--------------|--------------|
| `ArrayList` | Accès par indice immédiat, le choix par défaut | Insertion en début de liste coûteuse |
| `LinkedList` | Insertion et suppression aux extrémités | Accès par indice lent |

Dans la grande majorité des cas, `ArrayList` est le bon choix.

## Set : des éléments uniques

Un `Set` **refuse les doublons**. Il s'appuie sur les méthodes `equals` et `hashCode` des éléments pour savoir si deux éléments sont identiques.

```java
Set<String> competences = new HashSet<>();
competences.add("Java");
competences.add("SQL");
boolean ajoute = competences.add("Java");   // false : déjà présent, rien n'est ajouté

competences.size();                          // 2
competences.contains("SQL");                 // true, très rapide même sur un grand ensemble
```

| Implémentation | Ordre de parcours | Usage |
|----------------|-------------------|-------|
| `HashSet` | Aucun ordre garanti | Le plus rapide, le choix par défaut |
| `LinkedHashSet` | Ordre d'insertion | Unicité et ordre d'arrivée |
| `TreeSet` | Ordre naturel trié | Unicité et tri automatique |

Pour placer vos propres objets dans un `HashSet`, ils doivent redéfinir `equals` **et** `hashCode`. Les records le font automatiquement.

## Map : des paires clé-valeur

Une `Map` associe une **clé unique** à une **valeur**. C'est la structure idéale pour retrouver instantanément une information à partir d'un identifiant, comme un dictionnaire associe une définition à un mot.

```java
Map<String, Integer> xpParApprenant = new HashMap<>();
xpParApprenant.put("Emma", 120);
xpParApprenant.put("Lucas", 80);
xpParApprenant.put("Emma", 150);                   // remplace la valeur précédente

xpParApprenant.get("Emma");                        // 150
xpParApprenant.get("Nina");                        // null : clé absente
xpParApprenant.getOrDefault("Nina", 0);            // 0
xpParApprenant.containsKey("Lucas");               // true
xpParApprenant.merge("Lucas", 20, Integer::sum);   // ajoute 20 : Lucas passe à 100
xpParApprenant.remove("Emma");
```

`merge` est très pratique pour les compteurs : si la clé est absente, il met la valeur ; sinon, il combine l'ancienne et la nouvelle avec la fonction fournie.

Trois façons de parcourir une `Map` :

```java
for (String prenom : xpParApprenant.keySet()) { ... }            // les clés
for (Integer xp : xpParApprenant.values()) { ... }               // les valeurs
for (Map.Entry<String, Integer> entree : xpParApprenant.entrySet()) {
    System.out.println(entree.getKey() + " : " + entree.getValue());
}
```

Comme pour les `Set`, il existe `HashMap` (aucun ordre), `LinkedHashMap` (ordre d'insertion) et `TreeMap` (clés triées).

## Collections immuables

`List.of`, `Set.of` et `Map.of` créent des collections **non modifiables**. Toute tentative d'ajout ou de suppression lève une `UnsupportedOperationException`.

```java
List<String> jours = List.of("Lundi", "Mardi", "Mercredi");
jours.add("Jeudi");   // UnsupportedOperationException
```

Elles sont idéales pour des données fixes, et pour **renvoyer** une collection sans risquer qu'un appelant la modifie. Pour obtenir une copie modifiable : `new ArrayList<>(List.of(...))`. Pour exposer une liste interne en lecture seule : `List.copyOf(liste)` ou `Collections.unmodifiableList(liste)`.

## Le piège de la suppression pendant le parcours

Supprimer un élément dans une boucle for-each lève une `ConcurrentModificationException` : la collection change sous les pieds de la boucle qui la parcourt.

```java
List<Integer> notes = new ArrayList<>(List.of(8, 14, 9, 17));

for (Integer note : notes) {
    if (note < 10) {
        notes.remove(note);   // ConcurrentModificationException
    }
}

notes.removeIf(note -> note < 10);   // correct : [14, 17]
```

`removeIf` reçoit une condition sous forme de lambda, une notion détaillée dans le cours sur les streams.

## Trier

```java
List<String> prenoms = new ArrayList<>(List.of("Lucas", "Emma", "Nina"));
Collections.sort(prenoms);                  // ordre naturel : [Emma, Lucas, Nina]
prenoms.sort(Comparator.reverseOrder());    // ordre inverse : [Nina, Lucas, Emma]
```

Pour trier des objets selon un de leurs attributs, `Comparator.comparing` est la forme la plus lisible, et se combine :

```java
apprenants.sort(Comparator.comparing(Apprenant::getNom)
        .thenComparing(Apprenant::getPrenom));

apprenants.sort(Comparator.comparingInt(Apprenant::getXp).reversed());
```

## Quelle collection choisir ?

| Besoin | Collection |
|--------|------------|
| Une suite ordonnée, avec doublons, accès par position | `List` avec `ArrayList` |
| Des éléments uniques, test d'appartenance rapide | `Set` avec `HashSet` |
| Des éléments uniques et triés | `TreeSet` |
| Retrouver une valeur à partir d'une clé | `Map` avec `HashMap` |
| Une donnée fixe qui ne doit pas changer | `List.of`, `Set.of`, `Map.of` |

## Exemple complet

Compter le nombre d'inscriptions par formation à partir d'une liste, sans doublon d'apprenant, puis afficher le résultat trié :

```java
record Inscription(String apprenant, String formation) {}

List<Inscription> inscriptions = List.of(
        new Inscription("Emma", "Java"),
        new Inscription("Lucas", "Java"),
        new Inscription("Emma", "SQL"),
        new Inscription("Emma", "Java"),     // doublon à ignorer
        new Inscription("Nina", "SQL")
);

Set<Inscription> uniques = new HashSet<>(inscriptions);       // le doublon disparaît
Map<String, Integer> parFormation = new TreeMap<>();          // clés triées

for (Inscription inscription : uniques) {
    parFormation.merge(inscription.formation(), 1, Integer::sum);
}

for (Map.Entry<String, Integer> entree : parFormation.entrySet()) {
    System.out.println(entree.getKey() + " : " + entree.getValue() + " inscrits");
}
```

```text
Java : 2 inscrits
SQL : 2 inscrits
```

Trois collections, trois rôles : la `List` reçoit les données brutes, le `Set` élimine les doublons grâce au `equals` généré du record, la `TreeMap` compte et trie.

## Les erreurs fréquentes

- **Déclarer avec l'implémentation** (`ArrayList<String> x = ...`) au lieu de l'interface.
- **Supprimer dans un for-each**, et une `ConcurrentModificationException`.
- **Modifier une collection créée avec `List.of`.**
- **Placer ses propres objets dans un `HashSet`** sans avoir redéfini `equals` et `hashCode`.
- **Compter sur l'ordre d'un `HashMap` ou d'un `HashSet`**, qui n'est pas garanti.

## Retour au besoin

La liste des inscrits grandit maintenant à la demande. Un `Set` interdit les inscriptions en double, et une `Map` retrouve l'expérience d'un apprenant instantanément à partir de son prénom. Aucune de ces opérations n'a été réécrite : elles sont fournies par la bibliothèque standard. Il reste à savoir gérer les erreurs proprement, puis à transformer ces collections de façon expressive avec les streams.

## À retenir

- On déclare avec l'interface (`List`, `Set`, `Map`) et on instancie avec l'implémentation.
- `ArrayList`, `HashSet` et `HashMap` sont les choix par défaut.
- Les génériques garantissent à la compilation le type des éléments.
- `List.of` et ses variantes créent des collections immuables.
- On supprime pendant un parcours avec `removeIf`, jamais dans un for-each.

## Pour aller plus loin

- Le tutoriel officiel sur les collections : [dev.java/learn/api/collections-framework](https://dev.java/learn/api/collections-framework/)
