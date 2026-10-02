## Contexte

L'équipe pédagogique veut un rapport automatique à partir des résultats d'une session d'examens. Vous allez produire ce rapport avec la Stream API, sans aucune boucle `for` ni `while`.

## Données de départ

Copiez ces données dans votre programme :

```java
record Resultat(String apprenant, String promo, String matiere, double note) {}

List<Resultat> resultats = List.of(
        new Resultat("Emma", "2026", "Java", 16.5),
        new Resultat("Emma", "2026", "SQL", 14),
        new Resultat("Lucas", "2026", "Java", 9.5),
        new Resultat("Lucas", "2026", "SQL", 12),
        new Resultat("Nina", "2025", "Java", 18),
        new Resultat("Nina", "2025", "SQL", 17.5),
        new Resultat("Hugo", "2026", "Java", 7),
        new Resultat("Hugo", "2026", "SQL", 8.5),
        new Resultat("Léa", "2025", "Java", 13),
        new Resultat("Léa", "2025", "SQL", 11)
);
```

## Consignes

Écrivez une méthode par question, chacune avec un seul pipeline de stream :

1. La liste des notes de Java, triées par ordre décroissant.
2. La moyenne générale de toutes les notes.
3. La moyenne par matière, sous forme de `Map<String, Double>`.
4. La moyenne de chaque apprenant, sous forme de `Map<String, Double>`.
5. Les apprenants dont la moyenne est inférieure à 10, triés par ordre alphabétique.
6. La meilleure note de SQL et le nom de l'apprenant qui l'a obtenue.
7. Le nombre d'apprenants distincts par promotion.

Affichez ensuite un rapport lisible qui regroupe ces sept résultats.

## Contraintes

- Aucune boucle `for`, `for-each` ou `while` dans le calcul des résultats.
- Aucune variable extérieure modifiée depuis une lambda.
- Les `Optional` sont traités explicitement, sans appel à `get()` sans vérification.

## Aide

`Collectors.averagingDouble` calcule une moyenne à l'intérieur d'un `groupingBy`. `Collectors.collectingAndThen` permet d'appliquer un traitement au résultat d'un collecteur.

## Pour aller plus loin

Ajoutez une mention à chaque apprenant selon sa moyenne (« Très bien » à partir de 16, « Bien » à partir de 14, « Assez bien » à partir de 12) et affichez le classement complet.

## Livrable

Déposez une archive `.zip` du projet et un fichier `rapport.txt` contenant la sortie de votre programme.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Les sept résultats sont justes | 7 |
| Les pipelines sont lisibles et bien découpés | 5 |
| Les collecteurs sont utilisés à bon escient | 4 |
| Les `Optional` sont traités proprement | 2 |
| Bonus « pour aller plus loin » | 2 |
