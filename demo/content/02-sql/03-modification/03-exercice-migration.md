## Contexte

L'organisme de formation change ses règles. Vous devez écrire le script qui fait évoluer la base de production. Une erreur coûterait cher : le script doit être sûr, vérifiable et réversible tant qu'il n'est pas validé.

## Préparation

Réutilisez la base de l'exercice « Explorer une base de formations », rechargée à neuf.

## Évolutions demandées

1. Ajoutez à la table `apprenants` une colonne `deleted_at DATETIME NULL` pour permettre la suppression logique.
2. Augmentez de 5 % le prix des formations de la catégorie Développement, en arrondissant à l'euro.
3. L'apprenant Hugo Richard quitte l'organisme : marquez-le comme supprimé logiquement, sans toucher à ses inscriptions.
4. La formation Linux est remplacée par Kubernetes. Transférez les inscriptions de Linux vers Kubernetes en réinitialisant leur note, puis supprimez la formation Linux.
5. Ajoutez un index adapté à la recherche des inscriptions d'une formation par date d'inscription.

## Contraintes

- Les étapes 2 à 4 sont exécutées dans **une seule transaction**.
- Chaque `UPDATE` et `DELETE` est précédé du `SELECT` de vérification correspondant.
- Aucun `UPDATE` ni `DELETE` sans `WHERE`.
- Le script se termine par des requêtes de contrôle qui prouvent que chaque évolution est appliquée.

## Questions

Répondez dans un fichier `reponses.txt` :

1. Que se passerait-il si l'étape 4 échouait au milieu de la transaction ?
2. Pourquoi la suppression de la formation Linux aurait-elle échoué sans le transfert préalable des inscriptions ?
3. Donnez le résultat de `EXPLAIN` sur une requête qui utilise l'index de l'étape 5 et commentez la colonne `type`.

## Livrable

Déposez une archive `.zip` contenant le script `migration.sql` et le fichier `reponses.txt`.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Les cinq évolutions sont correctes | 7 |
| La transaction englobe les étapes 2 à 4 | 4 |
| Chaque modification est vérifiée avant et après | 4 |
| L'index est pertinent et justifié avec `EXPLAIN` | 3 |
| Les réponses aux questions sont justes | 2 |
