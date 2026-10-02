## Contexte

La médiathèque d'une petite ville veut informatiser la gestion de ses prêts. Vous devez concevoir sa base de données.

## Le besoin exprimé

> La médiathèque possède des **documents** : livres, BD et DVD. Chaque document a un titre, une année de parution et un genre. Un document peut avoir plusieurs **auteurs** et un auteur peut avoir écrit plusieurs documents. La médiathèque possède souvent plusieurs **exemplaires** d'un même document, chacun avec un code-barres unique et un état (neuf, bon, abîmé).
>
> Les **adhérents** ont un nom, un prénom, une adresse e-mail unique et une date d'adhésion. Un adhérent peut **emprunter** un exemplaire : on enregistre la date d'emprunt, la date de retour prévue et la date de retour effective. Un adhérent ne peut pas avoir plus de cinq emprunts en cours.

## Consignes

1. Listez les entités, leurs attributs et les relations avec leurs cardinalités.
2. Dessinez le modèle conceptuel (MCD) avec l'outil de votre choix : draw.io, Looping, dbdiagram.io ou sur papier.
3. Écrivez le script SQL `schema.sql` qui crée toutes les tables pour MySQL 8, avec :
   - une clé primaire par table ;
   - toutes les clés étrangères, nommées ;
   - les contraintes `NOT NULL`, `UNIQUE` et `CHECK` pertinentes ;
   - des types adaptés à chaque colonne.
4. Écrivez un script `donnees.sql` qui insère un jeu d'essai : au moins 5 documents, 3 auteurs, 8 exemplaires, 4 adhérents et 6 emprunts dont 2 en cours.
5. Indiquez dans un fichier `choix.txt` quelle règle du besoin **ne peut pas** être garantie par une simple contrainte de table, et comment l'application devrait la faire respecter.

## Livrable

Déposez une archive `.zip` contenant le MCD (image ou PDF), `schema.sql`, `donnees.sql` et `choix.txt`.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Les entités et les cardinalités sont justes | 5 |
| La relation auteurs et documents est traduite par une table d'association | 3 |
| La distinction document et exemplaire est correcte | 3 |
| Le script crée les tables sans erreur avec les bonnes contraintes | 5 |
| Le jeu d'essai s'insère sans erreur | 2 |
| La règle non garantie par le schéma est identifiée | 2 |
