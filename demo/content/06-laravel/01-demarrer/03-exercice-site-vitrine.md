## Contexte

Un organisme de formation veut un site vitrine simple : une page d'accueil, un catalogue et une page par formation. Les données sont encore fixes, la base de données arrivera au module suivant.

## Consignes

1. Créez un projet Laravel `formations-vitrine`.

2. Créez une classe `App\Support\CatalogueFormations` avec une méthode `toutes(): array` qui renvoie au moins six formations sous forme de tableaux associatifs : un identifiant texte (`slug`), un titre, une catégorie, une durée, un prix et une description.

3. Créez les routes nommées :

| URL | Nom | Contenu |
|-----|-----|---------|
| `/` | `accueil` | Présentation et trois formations mises en avant |
| `/formations` | `formations.index` | Catalogue complet, filtrable par catégorie avec `?categorie=` |
| `/formations/{slug}` | `formations.show` | Détail d'une formation, 404 si le slug est inconnu |
| `/contact` | `contact` | Page de contact statique |

4. Créez un `FormationController` qui reçoit `CatalogueFormations` par **injection** dans son constructeur.

5. Créez un composant de mise en page `x-layout` avec une navigation dont le lien de la page courante est mis en évidence (indice : `request()->routeIs()`).

6. Affichez le prix au format français, par exemple `1 200,00 €`, grâce à `number_format`.

## Contraintes

- Aucune URL écrite à la main dans les vues : uniquement `route()`.
- Aucune donnée affichée avec `{!! !!}`.
- La page 404 personnalisée se trouve dans `resources/views/errors/404.blade.php`.

## Livrable

Déposez une archive `.zip` du projet **sans** les dossiers `vendor` et `node_modules`, avec des captures d'écran des quatre pages.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Les quatre routes fonctionnent et sont nommées | 5 |
| Le filtre par catégorie et la page 404 fonctionnent | 4 |
| Le contrôleur reçoit le catalogue par injection | 3 |
| Le composant de mise en page est utilisé partout | 4 |
| Qualité des vues Blade et absence d'URL en dur | 4 |
