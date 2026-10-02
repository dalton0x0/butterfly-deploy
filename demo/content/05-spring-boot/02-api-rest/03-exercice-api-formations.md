## Contexte

Un organisme de formation veut exposer son catalogue à une application front. Vous construisez l'API REST, avec des données stockées en mémoire pour l'instant. La base de données arrivera au module suivant.

## Consignes

1. Créez un record `Formation` interne (id, titre, durée en heures, prix, niveau) et une énumération `Niveau` (`DEBUTANT`, `INTERMEDIAIRE`, `AVANCE`).

2. Créez les DTO :
   - `FormationRequest` avec ses contraintes : titre obligatoire de 3 à 150 caractères, durée entre 1 et 500 heures, prix positif ou nul, niveau obligatoire ;
   - `FormationResponse` qui ajoute un champ calculé `prixParHeure`, arrondi à deux décimales.

3. Créez une interface `FormationService` et son implémentation qui stocke les formations dans une `Map` en mémoire, avec un compteur pour les identifiants. Préremplissez trois formations au démarrage.

4. Créez le contrôleur `/api/formations` :

| Verbe | URL | Comportement |
|-------|-----|--------------|
| `GET` | `/api/formations?niveau=DEBUTANT` | Liste, filtre facultatif par niveau |
| `GET` | `/api/formations/{id}` | Détail |
| `POST` | `/api/formations` | Création, 201 et en-tête `Location` |
| `PUT` | `/api/formations/{id}` | Modification |
| `DELETE` | `/api/formations/{id}` | Suppression, 204 |

5. Règle métier : deux formations ne peuvent pas avoir le même titre, sans tenir compte de la casse.

6. Pour l'instant, une formation introuvable renvoie 404 avec `ResponseStatusException`. Le prochain cours présentera une approche plus propre.

7. Écrivez une collection de requêtes (Postman, Bruno ou fichier `.http` d'IntelliJ) qui couvre chaque point d'entrée, un cas de validation échouée et un cas de doublon.

## Contraintes

- Le contrôleur ne contient aucune logique métier.
- Le service ne manipule aucun objet HTTP.
- Injection par constructeur partout.

## Livrable

Déposez une archive `.zip` du projet (sans `target`) avec la collection de requêtes exportée.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Les cinq points d'entrée respectent REST et les bons statuts | 6 |
| Les DTO et la validation sont corrects | 5 |
| La règle d'unicité du titre est dans le service | 3 |
| Séparation contrôleur et service | 3 |
| Collection de requêtes complète | 3 |
