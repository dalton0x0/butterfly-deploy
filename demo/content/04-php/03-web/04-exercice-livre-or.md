## Contexte

Un centre de formation veut un livre d'or sur son site : les visiteurs laissent un message que tout le monde peut lire. C'est l'exemple type d'une page exposée aux attaques. Votre mission : le construire en PHP pur et le rendre sûr.

## Consignes

1. Créez une table MySQL `messages` avec un identifiant, un pseudo (50 caractères au plus), un message (1000 caractères au plus) et une date de publication.

2. Créez une page `index.php` qui :
   - affiche les messages, du plus récent au plus ancien, 10 par page avec une pagination par paramètre `?page=` ;
   - propose un formulaire pour publier un message.

3. À l'envoi du formulaire :
   - validez le pseudo (2 à 50 caractères) et le message (5 à 1000 caractères) ;
   - réaffichez le formulaire avec les erreurs et les valeurs saisies en cas de problème ;
   - enregistrez le message avec une requête préparée ;
   - redirigez selon le motif Post-Redirect-Get.

4. Protégez l'application :
   - toutes les requêtes SQL sont préparées ;
   - tout affichage de donnée utilisateur passe par `htmlspecialchars` ;
   - le formulaire est protégé par un jeton CSRF ;
   - le paramètre `page` est converti en entier et borné.

5. Isolez l'accès aux données dans une classe `MessageRepository` et la connexion PDO dans un fichier de configuration qui lit ses identifiants dans des variables d'environnement.

## Tests à réaliser et à documenter

Dans un fichier `tests.txt`, décrivez le résultat observé pour chacun de ces essais :

1. Publier un message contenant `<script>alert('XSS')</script>`.
2. Publier un pseudo contenant `' OR '1'='1`.
3. Envoyer le formulaire après avoir modifié la valeur du jeton CSRF avec les outils de développement du navigateur.
4. Actualiser la page juste après une publication réussie.
5. Ouvrir `index.php?page=-3` puis `index.php?page=abc`.

## Livrable

Déposez une archive `.zip` du projet contenant le script SQL de création de la table et le fichier `tests.txt`.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Le livre d'or fonctionne : publication, affichage, pagination | 4 |
| Validation et réaffichage des erreurs | 3 |
| Aucune injection SQL possible | 3 |
| Aucune faille XSS | 3 |
| Protection CSRF | 3 |
| Organisation du code et configuration hors du code | 2 |
| Tests documentés | 2 |
