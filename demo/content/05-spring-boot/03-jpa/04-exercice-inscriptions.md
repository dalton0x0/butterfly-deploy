## Contexte

Vous reprenez l'API de gestion de formations du module précédent. Elle doit maintenant stocker ses données dans MySQL et gérer les inscriptions des apprenants.

## Consignes

1. Ajoutez Spring Data JPA, le pilote MySQL et Flyway. Écrivez la migration `V1__initial_schema.sql` qui crée les tables `categories`, `formations`, `apprenants` et `inscriptions`, avec toutes les contraintes. Configurez Hibernate en `validate`.

2. Créez les entités correspondantes. `Inscription` est une entité d'association avec une date d'inscription et une note finale facultative.

3. Remplacez le stockage en mémoire des formations par un repository. Ajoutez :
   - la recherche par niveau et par prix maximum, paginée ;
   - la vérification d'unicité du titre sans tenir compte de la casse.

4. Ajoutez les points d'entrée des inscriptions :

| Verbe | URL | Comportement |
|-------|-----|--------------|
| `POST` | `/api/formations/{id}/inscriptions` | Inscrit un apprenant (identifiant dans le corps). 409 en cas de doublon, 409 si la formation est complète (20 places) |
| `GET` | `/api/formations/{id}/inscriptions` | Liste les inscrits avec leur nom, sans problème N+1 |
| `PATCH` | `/api/inscriptions/{id}/note` | Attribue une note entre 0 et 20 |
| `GET` | `/api/apprenants/{id}/inscriptions` | Liste les formations d'un apprenant avec sa moyenne |

5. Centralisez la gestion des erreurs avec un `@RestControllerAdvice` et un format de réponse unique.

6. Écrivez les tests :
   - au moins quatre tests unitaires du service d'inscription avec Mockito (cas nominal, doublon, formation complète, apprenant introuvable) ;
   - un test `@WebMvcTest` qui vérifie une erreur de validation ;
   - un test `@DataJpaTest` d'une requête personnalisée du repository.

## Contraintes

- Aucune entité ne sort des services : uniquement des DTO.
- Transactions sur les services, `readOnly` pour les lectures.
- Les relations `@ManyToOne` sont en `LAZY`.
- Le nombre de places maximum vient d'un record `@ConfigurationProperties`.

## Livrable

Déposez une archive `.zip` du projet (sans `target`) et une capture d'écran de l'exécution des tests.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Migration Flyway et entités cohérentes | 4 |
| Repositories et requêtes adaptées | 3 |
| Règles d'inscription dans le service, transactionnelles | 4 |
| Absence de N+1 sur la liste des inscrits | 2 |
| Gestion centralisée des erreurs | 2 |
| Tests unitaires et tests en tranche | 5 |
