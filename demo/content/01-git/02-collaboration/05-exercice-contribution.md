## Contexte

Vous rejoignez une petite équipe qui développe une page listant des recettes de cuisine. Vous allez simuler le parcours complet d'une contribution : branche, commits conventionnels, pull request, relecture et version.

## Consignes

1. Créez sur GitHub (ou GitLab) un dépôt public `recettes-equipe` avec un `README.md`.
2. Clonez-le, puis ajoutez un fichier `recettes.md` contenant trois recettes. Poussez directement sur `main` : c'est la version initiale.
3. Créez une branche `feature/add-dessert-section` et ajoutez une section de desserts en **au moins deux commits** conventionnels.
4. Poussez la branche et ouvrez une **pull request** vers `main` avec une description qui explique la modification.
5. Commentez vous-même une ligne de la pull request comme le ferait un relecteur, puis ajoutez un commit qui répond à ce commentaire.
6. Fusionnez la pull request depuis la plateforme.
7. Récupérez la fusion en local, supprimez la branche et posez un tag annoté `v1.0.0` que vous poussez.

## Contraintes

- Tous les commits suivent Conventional Commits.
- La branche `main` ne reçoit aucun commit direct après l'étape 2.
- Le tag est annoté et contient un message.

## Livrable

Déposez un fichier `livrable.txt` contenant :

- l'URL du dépôt ;
- l'URL de la pull request ;
- la sortie de `git log --oneline --graph --all` ;
- la sortie de `git tag -n`.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| La branche et les commits respectent les conventions | 5 |
| La pull request est décrite et commentée | 5 |
| La fusion passe par la pull request | 4 |
| Le tag annoté est créé et poussé | 3 |
| La branche est nettoyée en local | 3 |
