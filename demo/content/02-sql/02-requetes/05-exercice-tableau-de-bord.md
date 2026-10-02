## Contexte

La direction pédagogique veut un tableau de bord chiffré de l'activité de l'organisme. Chaque indicateur doit être produit par une requête SQL.

## Préparation

Réutilisez la base créée dans l'exercice « Explorer une base de formations ».

## Indicateurs à produire

1. Le nombre total d'inscriptions et le nombre d'inscriptions déjà notées, en une seule requête.
2. Le chiffre d'affaires total, en considérant que chaque inscription rapporte le prix de sa formation.
3. Le chiffre d'affaires par catégorie, du plus élevé au plus faible.
4. Le nombre d'inscrits par formation, **y compris** les formations sans inscrit qui doivent afficher 0.
5. La moyenne des notes par formation, arrondie à deux décimales, pour les formations ayant au moins une note.
6. Les apprenants ayant au moins deux inscriptions, avec leur nombre d'inscriptions.
7. Les formations dont la moyenne est inférieure à 12.
8. Les formations plus longues que la durée moyenne des formations.
9. Pour chaque ville (en ignorant les villes non renseignées), le nombre d'apprenants et leur moyenne générale.
10. La meilleure note de chaque formation avec le prénom de l'apprenant qui l'a obtenue.

## Aide

- Pour l'indicateur 4, pensez à `LEFT JOIN` et à la différence entre `COUNT(*)` et `COUNT(colonne)`.
- Pour l'indicateur 10, une sous-requête qui calcule la note maximale par formation peut être jointe à la table des inscriptions.

## Livrable

Déposez un fichier `tableau-de-bord.txt` contenant chaque requête précédée de `-- Indicateur n` et suivie en commentaire du résultat obtenu.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Indicateurs 1 à 3 : agrégations simples et jointures | 5 |
| Indicateur 4 : comptage avec les formations sans inscrit | 3 |
| Indicateurs 5 à 7 : `GROUP BY` et `HAVING` | 5 |
| Indicateurs 8 et 9 : sous-requête et filtre des `NULL` | 4 |
| Indicateur 10 : sous-requête jointe | 3 |
