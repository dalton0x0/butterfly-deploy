## Contexte

Une boutique de supports de cours veut calculer le montant d'un panier avant de construire son site. Vous écrivez la logique en PHP pur, sans framework.

## Données de départ

```php
$catalogue = [
    'LIV-JAVA' => ['libelle' => 'Livre Java', 'prix' => 39.90, 'categorie' => 'livre'],
    'LIV-PHP' => ['libelle' => 'Livre PHP', 'prix' => 34.50, 'categorie' => 'livre'],
    'VID-SQL' => ['libelle' => 'Vidéo SQL', 'prix' => 24.00, 'categorie' => 'video'],
    'KIT-DEV' => ['libelle' => 'Kit développeur', 'prix' => 89.00, 'categorie' => 'materiel'],
];

$panier = [
    'LIV-JAVA' => 2,
    'VID-SQL' => 1,
    'KIT-DEV' => 1,
];
```

## Consignes

Écrivez un script `panier.php` avec le typage strict et les fonctions suivantes :

| Fonction | Rôle |
|----------|------|
| `sousTotal(array $catalogue, array $panier): float` | Somme des prix multipliés par les quantités |
| `remise(float $sousTotal): float` | 10 % de remise à partir de 100 €, 15 % à partir de 200 € |
| `fraisDePort(float $montant): float` | 5,90 € en dessous de 50 €, gratuit au-delà |
| `lignesDetaillees(array $catalogue, array $panier): array` | Une ligne par article : libellé, quantité, prix unitaire et total de la ligne |
| `afficherFacture(...)` | Affiche la facture complète dans le terminal |

Exemple de fin de facture attendue :

```text
Sous-total    : 192.80 €
Remise (10 %) : -19.28 €
Frais de port :   0.00 €
Total         : 173.52 €
```

## Contraintes

- Chaque fonction est typée en paramètres et en retour.
- Les seuils et les taux sont des constantes (`const SEUIL_REMISE = 100;`).
- Un code article absent du catalogue lève une exception claire.
- Au moins une utilisation de `array_map` ou `array_filter`.
- Les montants sont affichés avec deux décimales grâce à `number_format`.

## Pour aller plus loin

Ajoutez un code promotionnel optionnel : `ETE10` retire 10 € sur les commandes de plus de 60 €, après la remise automatique.

## Livrable

Déposez une archive `.zip` contenant `panier.php` et une capture d'écran de son exécution.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Les montants sont justes | 6 |
| Les fonctions sont typées et ont une seule responsabilité | 5 |
| Les constantes et le nommage sont clairs | 3 |
| Le code article inconnu est géré | 2 |
| Les fonctions de tableaux sont utilisées à bon escient | 2 |
| Bonus « pour aller plus loin » | 2 |
