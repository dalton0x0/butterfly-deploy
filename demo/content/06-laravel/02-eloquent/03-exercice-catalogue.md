## Contexte

Le site vitrine du module précédent passe à la vitesse supérieure : le catalogue est désormais stocké en base et administrable.

## Consignes

1. Configurez une base MySQL dans le `.env`.

2. Créez les migrations, modèles, factories et seeders pour :
   - `Categorie` : nom unique ;
   - `Formation` : catégorie, titre unique, slug unique, description, durée, prix, niveau (`debutant`, `intermediaire`, `avance`), publiée ou non ;
   - `Module` : formation, titre, position. Une formation a plusieurs modules ordonnés.

3. Les seeders créent 4 catégories, 15 formations et 3 à 6 modules par formation, grâce aux factories.

4. Déclarez toutes les relations. Ajoutez un scope `publiees()` et un cast d'énumération pour le niveau avec une énumération PHP `Niveau`.

5. Adaptez le site vitrine :
   - le catalogue n'affiche que les formations publiées, avec leur catégorie et leur nombre de modules, 9 par page ;
   - le filtre par catégorie et par niveau fonctionne ensemble ;
   - la page de détail utilise la liaison de modèle par slug et affiche les modules dans l'ordre.

6. Ajoutez une commande `php artisan formations:statistiques` qui affiche le nombre de formations et le prix moyen par catégorie.

## Contraintes

- Aucun problème N+1 : activez `Model::preventLazyLoading()` en local et vérifiez qu'aucune exception n'apparaît.
- Uniquement Eloquent : pas de `DB::table()` ni de SQL brut.
- Les colonnes modifiables sont déclarées dans `$fillable`.

## Livrable

Déposez une archive `.zip` du projet sans `vendor` ni `node_modules`, avec une capture d'écran du catalogue filtré et de la sortie de la commande.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Migrations cohérentes avec contraintes et clés étrangères | 4 |
| Relations, scope et cast d'énumération | 4 |
| Factories et seeders fonctionnels | 3 |
| Catalogue filtré et paginé sans N+1 | 5 |
| Commande Artisan de statistiques | 2 |
| Liaison de modèle par slug | 2 |
