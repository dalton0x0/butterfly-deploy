## Contexte

Un formateur souhaite un petit programme qui calcule la moyenne d'un apprenant à partir de ses notes et affiche une appréciation.

## Consignes

Écrivez une classe `CalculMoyenne` avec une méthode `main` qui :

1. Déclare un tableau de notes sur 20, par exemple `{12.5, 15, 9, 17.5, 11}`.
2. Calcule la **somme** puis la **moyenne** des notes.
3. Détermine la note **la plus haute** et la note **la plus basse**.
4. Affiche la moyenne arrondie à deux décimales avec `String.format("%.2f", moyenne)`.
5. Affiche une appréciation selon la moyenne :
   - moins de 10 : « Insuffisant »
   - de 10 à moins de 14 : « Satisfaisant »
   - 14 et plus : « Très bien »

Exemple de sortie attendue :

```text
Notes : 12.5, 15.0, 9.0, 17.5, 11.0
Moyenne : 13.00
Note la plus haute : 17.5
Note la plus basse : 9.0
Appréciation : Satisfaisant
```

Selon la langue de votre système, `String.format` peut afficher `13,00` avec une virgule. Les deux formes sont acceptées.

## Contraintes

- Utilisez une boucle `for` pour parcourir le tableau. N'utilisez pas encore la Stream API.
- Déclarez la note maximale (20) dans une constante `final`.
- Donnez des noms explicites à vos variables.

## Pour aller plus loin

Refusez les notes invalides (négatives ou supérieures à 20) en affichant un message clair au lieu de calculer une moyenne fausse.

## Livrable

Déposez une archive `.zip` contenant le fichier `CalculMoyenne.java` et une capture d'écran de l'exécution.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Le programme compile et s'exécute | 4 |
| La moyenne, le minimum et le maximum sont justes | 6 |
| L'appréciation respecte les seuils | 4 |
| Nommage clair et constante utilisée | 4 |
| Bonus « pour aller plus loin » | 2 |
