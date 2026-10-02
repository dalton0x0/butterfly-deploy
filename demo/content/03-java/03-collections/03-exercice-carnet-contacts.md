## Contexte

Vous développez le cœur d'un carnet de contacts en ligne de commande. Il doit stocker les contacts, empêcher les doublons et signaler clairement les erreurs.

## Consignes

1. Créez un record `Contact(String nom, String prenom, String email, String telephone)`. Son constructeur compact refuse un nom ou un e-mail vide et un e-mail sans `@`.

2. Créez une exception métier `ContactIntrouvableException` qui hérite de `RuntimeException`.

3. Créez une classe `CarnetContacts` qui stocke les contacts dans une `Map<String, Contact>` dont la clé est l'e-mail en minuscules. Elle propose :

| Méthode | Comportement attendu |
|---------|----------------------|
| `ajouter(Contact contact)` | Ajoute le contact. Refuse un e-mail déjà présent avec une `IllegalStateException`. |
| `rechercher(String email)` | Renvoie le contact ou lève `ContactIntrouvableException`. |
| `supprimer(String email)` | Supprime le contact ou lève `ContactIntrouvableException`. |
| `lister()` | Renvoie les contacts triés par nom puis par prénom, dans une liste non modifiable. |
| `rechercherParNom(String debut)` | Renvoie les contacts dont le nom commence par le texte donné, sans tenir compte de la casse. |

4. Écrivez une classe `Main` qui propose un menu en boucle : ajouter, rechercher, supprimer, lister, quitter. Chaque erreur est capturée et affichée sans arrêter le programme.

## Contraintes

- Aucun bloc `catch` vide.
- La recherche par e-mail ne dépend pas de la casse : `Emma@Exemple.fr` et `emma@exemple.fr` désignent le même contact.
- `lister` ne permet pas à l'appelant de modifier le carnet.

## Pour aller plus loin

Sauvegardez le carnet dans un fichier texte à la sortie du programme et rechargez-le au démarrage avec `try-with-resources`.

## Livrable

Déposez une archive `.zip` du projet et une capture d'écran montrant un ajout, une erreur de doublon et une recherche.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Le record valide ses données | 3 |
| Le choix et l'usage de la `Map` sont pertinents | 4 |
| Les exceptions sont levées et capturées au bon endroit | 5 |
| Le tri et la recherche par nom sont corrects | 4 |
| Le menu est robuste aux erreurs | 2 |
| Bonus « pour aller plus loin » | 2 |
