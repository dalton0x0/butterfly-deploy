## Contexte

Avant de construire une API complète, vous mettez en place le socle d'un projet Spring Boot et vérifiez que l'injection de dépendances et la configuration fonctionnent.

## Consignes

1. Générez un projet sur start.spring.io :
   - Maven, Java 21 ou plus récent, la dernière version stable de Spring Boot ;
   - dépendances : Spring Web, Validation, Lombok et Spring Boot Actuator.

2. Créez une interface `GenerateurCode` avec une méthode `String generer()`. Créez-en deux implémentations :
   - `GenerateurCodeAleatoire` qui renvoie 8 caractères alphanumériques aléatoires ;
   - `GenerateurCodeSequentiel` qui renvoie `FORM-0001`, `FORM-0002`, etc.

3. Créez un record `CodeProperties` lié au préfixe `formations.code`, avec :
   - `prefixe` (non vide, `FORM` par défaut grâce à `@DefaultValue`) ;
   - `longueur` (entre 4 et 12).

   Utilisez ces valeurs dans les deux générateurs. Une longueur hors bornes doit empêcher l'application de démarrer.

4. Faites de `GenerateurCodeSequentiel` l'implémentation par défaut. Créez un service `CodeService` qui reçoit le générateur par constructeur.

5. Créez un contrôleur `GET /api/codes` qui renvoie un nouveau code à chaque appel.

6. Créez deux profils :
   - `dev` : port 8080, logs de vos packages en `DEBUG` ;
   - `prod` : port lu dans la variable d'environnement `PORT`, logs en `INFO`.

7. Écrivez un test unitaire de `CodeService` **sans** démarrer Spring, en lui passant un générateur écrit pour le test.

## Contraintes

- Injection uniquement par constructeur, aucun `@Autowired` sur un champ.
- Aucun `@Value` : toute la configuration passe par le record.
- `GET /actuator/health` répond `UP`.

## Livrable

Déposez une archive `.zip` du projet, sans le dossier `target`, et une capture d'écran de l'application qui échoue au démarrage avec une longueur invalide.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Le projet démarre et `/api/codes` répond | 3 |
| Les deux implémentations et le choix par défaut sont corrects | 4 |
| La configuration typée est validée au démarrage | 5 |
| Les profils sont correctement séparés | 3 |
| Le test unitaire fonctionne sans Spring | 5 |
