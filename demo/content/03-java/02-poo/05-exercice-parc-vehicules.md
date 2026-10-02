## Contexte

Une entreprise de location gère un parc de voitures, d'utilitaires et de vélos électriques. Chaque type de véhicule a son propre mode de calcul du prix de location. Vous allez modéliser ce parc en vous appuyant sur l'héritage, une interface et le polymorphisme.

## Consignes

1. Créez une classe abstraite `Vehicule` avec :
   - une immatriculation (ou un numéro de série pour les vélos) et un modèle ;
   - une méthode abstraite `double prixLocation(int jours)` ;
   - une méthode `String fiche()` qui renvoie une description commune.

2. Créez trois sous-classes avec leurs règles de prix :

| Véhicule | Règle de prix |
|----------|---------------|
| `Voiture` | 45 € par jour |
| `Utilitaire` | 70 € par jour, plus 0,25 € par kilo de charge utile déclarée |
| `VeloElectrique` | 15 € par jour, 20 % de remise à partir de 7 jours |

3. Créez une interface `Entretenable` avec une méthode `boolean entretienNecessaire()`. Seuls les véhicules à moteur l'implémentent : une voiture ou un utilitaire a besoin d'un entretien au-delà de 15 000 km depuis le dernier.

4. Créez une classe `Parc` qui contient une liste de véhicules et propose :
   - `ajouter(Vehicule vehicule)` ;
   - `double estimerLocation(int jours)` qui renvoie le prix total de location de tout le parc ;
   - `List<Vehicule> aEntretenir()` qui renvoie les véhicules nécessitant un entretien.

5. Écrivez une classe `Main` qui construit un parc d'au moins cinq véhicules et affiche les résultats.

## Contraintes

- La classe `Parc` ne doit contenir **aucun** `instanceof` dans `estimerLocation`. Le polymorphisme doit suffire.
- Chaque sous-classe utilise `@Override`.
- Les valeurs de tarif sont des constantes nommées.

## Pour aller plus loin

Remplacez les tarifs codés en dur par une réduction applicable à n'importe quel véhicule : une interface `Remise` avec plusieurs implémentations (remise fidélité, remise longue durée) passées à `estimerLocation`.

## Livrable

Déposez une archive `.zip` du projet et un court fichier `README.txt` qui justifie en quelques lignes vos choix entre héritage et interface.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| La hiérarchie de classes est cohérente | 5 |
| Les prix sont justes pour chaque type | 4 |
| Le polymorphisme est utilisé sans `instanceof` | 4 |
| L'interface `Entretenable` est bien ciblée | 3 |
| Justification des choix dans le README | 2 |
| Bonus « pour aller plus loin » | 2 |
