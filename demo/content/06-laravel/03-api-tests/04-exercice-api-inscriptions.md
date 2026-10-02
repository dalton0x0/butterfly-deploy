## Contexte

L'organisme de formation lance une application mobile. Elle a besoin d'une API pour consulter le catalogue et gérer les inscriptions. Vous partez du projet de l'exercice « Gestion d'un catalogue de formations ».

## Consignes

1. Installez les routes d'API et Sanctum. Ajoutez au modèle `User` un rôle avec une énumération `Role` (`admin`, `formateur`, `apprenant`) et une relation vers les formations suivies, par une table pivot `inscriptions` portant une note finale.

2. Ajoutez à `formations` un formateur responsable et une capacité maximale.

3. Créez les points d'entrée :

| Verbe | URL | Accès | Comportement |
|-------|-----|-------|--------------|
| `POST` | `/api/login` | Public, 5 essais par minute | Renvoie un jeton Sanctum |
| `GET` | `/api/formations` | Public | Formations publiées, paginées, filtre par niveau |
| `GET` | `/api/formations/{formation}` | Public | Détail avec catégorie et nombre d'inscrits |
| `POST` | `/api/formations/{formation}/inscriptions` | Apprenant | Inscription. 409 si déjà inscrit ou formation complète |
| `DELETE` | `/api/formations/{formation}/inscriptions` | Apprenant | Désinscription |
| `GET` | `/api/formations/{formation}/inscrits` | Formateur responsable ou admin | Liste des inscrits |
| `PATCH` | `/api/formations/{formation}/inscrits/{user}` | Formateur responsable ou admin | Attribution d'une note de 0 à 20 |
| `GET` | `/api/me/formations` | Connecté | Formations suivies avec la note |

4. Toutes les réponses passent par des API Resources. Aucun champ sensible de l'utilisateur n'est exposé.

5. Les règles d'accès sont dans une `FormationPolicy`. La logique d'inscription (doublon, capacité) est dans une classe dédiée, par exemple `InscriptionService`, et non dans le contrôleur.

6. Écrivez au moins **dix** tests de fonctionnalité, dont :
   - un apprenant ne peut pas s'inscrire deux fois ;
   - une formation complète refuse une nouvelle inscription ;
   - un formateur ne peut pas noter les inscrits d'une formation qui n'est pas la sienne ;
   - un visiteur non connecté reçoit 401 sur une route protégée ;
   - une note hors de l'intervalle 0 à 20 est refusée.

## Contraintes

- Eloquent uniquement, aucun problème N+1.
- Validation par Form Requests.
- Codes de statut conformes aux conventions REST.

## Livrable

Déposez une archive `.zip` du projet sans `vendor` ni `node_modules`, avec une capture d'écran de `php artisan test` et une collection de requêtes (Postman, Bruno ou fichier `.http`).

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Les points d'entrée fonctionnent avec les bons statuts | 4 |
| Authentification Sanctum et limitation de débit | 2 |
| Policy et contrôles d'accès, aucune faille IDOR | 4 |
| Logique d'inscription isolée du contrôleur | 3 |
| API Resources sans fuite de données | 2 |
| Tests de fonctionnalité pertinents | 5 |
