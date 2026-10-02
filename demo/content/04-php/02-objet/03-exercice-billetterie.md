## Contexte

Une association organise trois types d'événements : des conférences, des ateliers pratiques et des webinaires. Chaque type calcule son prix différemment, certains peuvent être remboursés et certains ont un nombre de places limité. Vous modélisez sa billetterie en PHP objet, en appliquant les outils du cours dans un nouveau domaine.

## Consignes

1. Créez une énumération `Tarif` avec les cas `Plein`, `Reduit` et `Gratuit`, adossée à une chaîne, avec une méthode `coefficient(): float` qui renvoie respectivement 1, 0,5 et 0.

2. Créez une classe abstraite `Evenement` avec un titre, une date (`DateTimeImmutable`), une méthode abstraite `prixDeBase(): int` qui renvoie un montant en centimes, et une méthode `prix(Tarif $tarif): int` qui applique le coefficient du tarif.

3. Créez trois classes `final` :

| Classe | Données propres | Prix de base |
|--------|-----------------|--------------|
| `Conference` | Nom de l'intervenant | 15 € |
| `Atelier` | Durée en heures | 12 € par heure |
| `Webinaire` | Lien de connexion | 5 €, puis gratuit à moins de 48 h de l'événement |

4. Créez une interface `Remboursable` avec une méthode `montantRembourse(int $prixPaye, DateTimeImmutable $demandeLe): int`. Seuls les conférences et les ateliers l'implémentent : remboursement total jusqu'à 7 jours avant l'événement, 50 % ensuite, rien le jour même.

5. Créez un trait `AvecPlacesLimitees` qui gère une capacité, réserve une place avec `reserver(): void` et lève une exception quand l'événement est complet. Seuls les ateliers l'utilisent.

6. Créez une classe `Billetterie` qui propose :
   - `ajouter(Evenement $evenement): void` ;
   - `chiffreAffairesPrevisionnel(array $ventes): int`, où chaque vente associe un événement et un tarif ;
   - `evenementsRemboursables(): array`.

7. Écrivez un script `index.php` qui crée au moins cinq événements, simule des ventes et des demandes de remboursement, et affiche les résultats en euros au format français.

## Contraintes

- `declare(strict_types=1);` dans chaque fichier, une classe par fichier, autoload PSR-4 avec Composer.
- Promotion de propriétés dans les constructeurs, propriétés `readonly` quand elles ne changent pas.
- Tous les montants sont manipulés en centimes entiers.
- Aucun `instanceof` dans `chiffreAffairesPrevisionnel`. Dans `evenementsRemboursables`, seul un `instanceof Remboursable` est accepté.

## Livrable

Déposez une archive `.zip` du projet sans le dossier `vendor`, et une capture d'écran de l'exécution de `index.php`.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| La hiérarchie et l'énumération sont correctes | 5 |
| Les prix et les remboursements sont justes | 4 |
| L'interface et le trait sont utilisés à bon escient | 4 |
| La billetterie fonctionne sans `instanceof` superflu | 4 |
| Typage strict, montants en centimes et organisation PSR-4 | 3 |
