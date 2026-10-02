## Contexte

Le jeu du nombre mystère est un classique pour pratiquer les boucles et les conditions. Le programme choisit un nombre au hasard, le joueur doit le trouver.

## Consignes

Écrivez une classe `NombreMystere` qui :

1. Tire un nombre entier aléatoire entre 1 et 100 inclus.
2. Demande au joueur de proposer un nombre, avec la classe `Scanner`.
3. Indique après chaque proposition « C'est plus » ou « C'est moins ».
4. Compte le nombre d'essais.
5. Affiche un message de victoire avec le nombre d'essais quand le nombre est trouvé.
6. Limite la partie à **10 essais**. Au-delà, affiche la solution et termine la partie.

Pour tirer un nombre aléatoire :

```java
import java.util.Random;

int mystere = new Random().nextInt(100) + 1;   // entre 1 et 100
```

Exemple de partie :

```text
Devinez le nombre entre 1 et 100.
Essai 1 : 50
C'est moins.
Essai 2 : 25
C'est plus.
Essai 3 : 37
Bravo, vous avez trouvé 37 en 3 essais !
```

## Contraintes

- Les bornes (1 et 100) et le nombre d'essais maximal (10) sont des constantes.
- Une proposition hors des bornes affiche un avertissement et ne compte pas comme un essai.
- Le programme ne doit pas planter si le joueur tape autre chose qu'un nombre. Indice : `scanner.hasNextInt()`.

## Pour aller plus loin

À la fin d'une partie, proposez de rejouer. Conservez le meilleur score (le plus petit nombre d'essais) entre les parties.

## Livrable

Déposez une archive `.zip` contenant `NombreMystere.java` et une capture d'écran d'une partie gagnée.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Le jeu fonctionne de bout en bout | 6 |
| La limite de 10 essais est respectée | 3 |
| Les saisies invalides sont gérées sans plantage | 4 |
| Les constantes et le nommage sont clairs | 4 |
| Bonus « pour aller plus loin » | 3 |
