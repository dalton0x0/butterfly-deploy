## Contexte

Vous démarrez un petit site vitrine personnel. Avant d'écrire la moindre ligne, vous décidez de le versionner proprement avec Git.

## Consignes

1. Configurez votre nom et votre adresse e-mail dans Git si ce n'est pas déjà fait.
2. Créez un dossier `site-vitrine` et initialisez-y un dépôt avec `main` comme branche par défaut.
3. Créez un fichier `.gitignore` qui exclut `.env`, `*.log` et le dossier `.idea/`. Faites-en votre **premier commit**.
4. Créez une page `index.html` minimale avec un titre. Faites un commit.
5. Ajoutez un fichier `style.css` et liez-le à la page. Faites un commit.
6. Créez un fichier `.env` contenant `API_KEY=secret`. Vérifiez avec `git status` qu'il n'apparaît pas.
7. Modifiez `index.html` **et** `style.css`, puis enregistrez-les dans **deux commits séparés** en utilisant l'index.
8. Affichez l'historique avec `git log --oneline` et redirigez la sortie dans un fichier : `git log --oneline > historique.txt`.

## Contraintes

- Au moins cinq commits au total.
- Chaque message de commit décrit clairement la modification. Vous pouvez suivre la convention `type: description` (par exemple `feat: add contact section`).
- Le fichier `.env` ne doit apparaître dans aucun commit.

## Livrable

Déposez une archive `.zip` du dossier `site-vitrine` **avec son dossier caché `.git`**. Votre formateur pourra ainsi consulter l'historique. Ajoutez le fichier `historique.txt`.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Le dépôt est initialisé et contient au moins cinq commits | 4 |
| Le `.gitignore` est correct et `.env` n'est jamais versionné | 5 |
| Les commits de l'étape 7 sont bien séparés | 5 |
| Les messages de commit sont clairs et cohérents | 6 |
