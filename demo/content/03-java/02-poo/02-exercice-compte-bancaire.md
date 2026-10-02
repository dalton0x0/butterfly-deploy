## Contexte

Une banque en ligne a besoin d'une classe qui représente un compte courant. L'objectif est d'appliquer l'encapsulation : aucun code extérieur ne doit pouvoir mettre le compte dans un état incohérent.

## Consignes

Créez une classe `CompteBancaire` avec :

- un **numéro** de compte et un **titulaire**, fixés à la création et non modifiables ;
- un **solde** privé, initialisé à 0 ;
- un **découvert autorisé** fixé à la création (par exemple 200 €).

Et les méthodes suivantes :

| Méthode | Comportement attendu |
|---------|----------------------|
| `deposer(double montant)` | Ajoute le montant au solde. Refuse un montant nul ou négatif. |
| `retirer(double montant)` | Retire le montant si le découvert autorisé n'est pas dépassé. Sinon, refuse l'opération. |
| `virerVers(CompteBancaire destination, double montant)` | Retire du compte courant et dépose sur la destination. Rien ne bouge si le retrait est refusé. |
| `getSolde()` | Renvoie le solde. |

Les opérations refusées lèvent une `IllegalArgumentException` ou une `IllegalStateException` avec un message clair en français.

Écrivez enfin une classe `Main` qui crée deux comptes et démontre chaque cas : dépôt, retrait accepté, retrait refusé et virement.

## Contraintes

- Aucun setter sur le solde.
- Le numéro et le titulaire sont `final`.
- Un virement vers le même compte est refusé.

## Pour aller plus loin

Conservez un historique des opérations sous forme de liste de records `Operation(String type, double montant, LocalDateTime date)` et ajoutez une méthode qui l'affiche.

## Livrable

Déposez une archive `.zip` contenant vos fichiers `.java` et une capture d'écran de l'exécution de `Main`.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| L'encapsulation est respectée (attributs privés, pas de setter sur le solde) | 5 |
| Les règles de dépôt, retrait et découvert sont correctes | 6 |
| Le virement est cohérent en cas de refus | 4 |
| Les cas sont démontrés dans `Main` | 3 |
| Bonus « pour aller plus loin » | 2 |
