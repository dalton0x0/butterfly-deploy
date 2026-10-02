## Contexte

Deux développeurs travaillent en parallèle sur la page d'accueil d'un site. Vous allez provoquer puis résoudre vous-même le conflit qui en résulte.

## Consignes

1. Créez un dépôt `conflit-demo` avec un fichier `accueil.html` contenant un titre `<h1>Bienvenue</h1>` et un paragraphe de présentation. Faites un commit sur `main`.
2. Créez une branche `feature/titre-marketing` et remplacez le titre par `<h1>Apprenez à votre rythme</h1>`. Faites un commit.
3. Revenez sur `main` et remplacez le **même** titre par `<h1>Bienvenue sur la plateforme</h1>`. Ajoutez aussi un pied de page. Faites un commit.
4. Fusionnez `feature/titre-marketing` dans `main`. Constatez le conflit.
5. Résolvez le conflit en gardant un titre qui combine les deux intentions, par exemple `<h1>Bienvenue : apprenez à votre rythme</h1>`, **et** en conservant le pied de page.
6. Terminez la fusion avec un commit.
7. Exportez l'historique graphique : `git log --oneline --graph --all > historique.txt`.

## Questions

Répondez brièvement dans un fichier `reponses.txt` :

1. Pourquoi le pied de page ajouté à l'étape 3 n'a-t-il provoqué aucun conflit ?
2. Pourquoi cette fusion n'a-t-elle pas pu se faire en fast-forward ?
3. Quelle commande auriez-vous utilisée pour abandonner la fusion ?

## Livrable

Déposez une archive `.zip` du dossier `conflit-demo` avec son dossier `.git`, ainsi que `historique.txt` et `reponses.txt`.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Le conflit est provoqué selon les étapes | 4 |
| La résolution est correcte, sans marqueur restant | 6 |
| Le commit de fusion est présent dans l'historique | 4 |
| Les réponses aux questions sont justes | 6 |
