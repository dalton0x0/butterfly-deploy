# Contenus de démonstration

Ce dossier charge dans une instance Butterfly un jeu de contenus prêts à parcourir : des blocs
complets avec leurs modules, cours, exercices et quiz, un formateur et deux apprenants.

## Sommaire

- [Ce qui est créé](#ce-qui-est-créé)
- [Lancement](#lancement)
- [Fonctionnement](#fonctionnement)
- [Relancer le script](#relancer-le-script)
- [Ajouter un bloc](#ajouter-un-bloc)
- [Limites](#limites)

## Ce qui est créé

Trois comptes avec une adresse confirmée et un mot de passe commun, `Butterfly-Demo2026` par
défaut :

| Rôle       | Nom            | Adresse                          |
|------------|----------------|----------------------------------|
| Formateur  | Sophie Laurent | `sophie.laurent@butterfly.local` |
| Apprenant  | Lucas Bernard  | `lucas.bernard@butterfly.local`  |
| Apprenant  | Emma Petit     | `emma.petit@butterfly.local`     |

Six blocs, tous assignés à ces trois comptes :

| Bloc                    | Modules | Prérequis                    |
|-------------------------|---------|------------------------------|
| Git                     | 2       | Aucun                        |
| SQL et bases de données | 3       | Aucun                        |
| Java                    | 3       | Aucun                        |
| PHP                     | 3       | Aucun                        |
| Spring Boot             | 3       | Java, SQL et bases de données |
| Laravel                 | 3       | PHP, SQL et bases de données  |

Soit 17 modules, 46 cours, 22 exercices notés sur 20 et 17 quiz de 8 questions. Dans chaque bloc,
un module a pour prérequis le module qui le précède et se termine par un quiz de 10 points : il
en faut 7 pour le réussir avec le seuil par défaut de 70 %. Les blocs Spring Boot et Laravel
restent verrouillés tant que leurs blocs prérequis ne sont pas terminés, ce qui suppose que le
formateur ait validé les exercices : c'est ce qui permet de montrer le déverrouillage progressif.

## Lancement

Prérequis : Node.js 20.6 ou plus récent. Aucune dépendance à installer.

La pile doit être démarrée et le backend sain (`docker compose ps`). Depuis la racine de ce dépôt :

```bash
node --env-file=.env demo/seed.mjs
```

Le script lit dans `.env` les identifiants de l'administrateur (`ADMIN_EMAIL`, `ADMIN_PASSWORD`) et
les ports de la pile (`FRONTEND_PORT`, `MAILPIT_UI_PORT`).

`node --env-file` coupe une valeur sans guillemets au premier `#`, là où Docker Compose la garde
entière. Si `ADMIN_PASSWORD` contient un `#`, entourez sa valeur de guillemets dans `.env` :
Compose les retire aussi, la valeur reste identique pour les deux.

Variables facultatives :

| Variable           | Défaut                                   | Rôle                                  |
|--------------------|------------------------------------------|---------------------------------------|
| `DEMO_PASSWORD`    | `Butterfly-Demo2026`                     | Mot de passe des comptes créés        |
| `DEMO_API_URL`     | `http://localhost:${FRONTEND_PORT}/api`  | Racine de l'API visée sans version, par exemple un backend lancé hors conteneur (`http://localhost:8080/api`). Le script ajoute lui-même `/v1` |
| `DEMO_MAILPIT_URL` | `http://localhost:${MAILPIT_UI_PORT}`    | Interface de Mailpit                  |

## Fonctionnement

Le script passe par l'API REST et jamais par la base. Chaque contenu subit donc les mêmes
validations qu'une saisie dans l'interface et les options de quiz sont mélangées à l'insertion
comme le fait le backend. Aucune migration Flyway n'est concernée : rien ne peut atteindre une
base de production par accident.

Les comptes sont activés par le vrai parcours. Depuis le backend v3.1.0, un compte créé par
l'administrateur n'a pas de mot de passe : il reçoit une invitation. Le script lit ce lien dans
Mailpit puis présente son jeton à l'API avec le mot de passe de démonstration, comme le ferait la
page d'activation. Si Mailpit n'est pas joignable, par exemple avec un relais SMTP réel, les comptes
restent **inutilisables** faute de mot de passe : le script le signale et il suffit de le relancer
une fois Mailpit disponible, une nouvelle invitation est alors demandée.

L'ordre du parcours suit l'ordre déclaré dans `block.json`. Cours et exercices partagent la même
suite de positions dans un module : un exercice reste verrouillé tant que les cours placés avant
lui ne sont pas terminés.

## Relancer le script

Le script peut être relancé sans risque :

- un compte qui existe déjà est conservé. S'il attend son activation, une nouvelle invitation est
  demandée puis acceptée. Un compte plus ancien qui a déjà un mot de passe, voit seulement son
  adresse confirmée si elle ne l'était pas ;
- un bloc qui existe déjà (même nom) est conservé tel quel, sans être mis à jour ;
- les blocs de démonstration sont ajoutés aux blocs déjà assignés à chaque compte, sans en retirer.

Tous les fichiers sont lus avant le premier appel à l'API : un fichier manquant ou un JSON invalide
arrête le script avant toute création. Une erreur renvoyée par l'API en cours de route laisse en
revanche un bloc incomplet. Il sera ignoré à la relance : videz-le puis supprimez-le depuis
l'interface avant de relancer.

## Ajouter un bloc

Chaque bloc est un dossier de `content`. Les dossiers sont traités dans l'ordre de leur préfixe
numérique : un bloc doit venir après ses prérequis puisqu'il les désigne par leur nom.

```
content/
  03-java/
    block.json            nom, description, prérequis, modules et ordre du contenu
    01-bases/
      01-premier-programme.md
      03-exercice-moyenne.md
      quiz.json
```

- Les cours et les énoncés sont en Markdown. L'interface convertit chaque retour à la ligne en saut
  visuel : écrivez un paragraphe sur une seule ligne.
- Les quiz suivent le format d'import de questions de l'interface. Un fichier `quiz.json` peut donc
  aussi être importé à la main depuis l'éditeur de quiz.
- Les rendus d'exercice acceptent PDF, PNG, JPEG, texte et ZIP. Un énoncé demande donc une archive
  `.zip` plutôt que des fichiers source dont le type ne serait pas reconnu.

## Limites

- Un bloc existant n'est jamais mis à jour : modifier un contenu déjà chargé passe par l'interface,
  ou par la suppression du bloc puis une relance.
- Le script ne crée aucune progression : les apprenants démarrent avec un parcours vierge.
