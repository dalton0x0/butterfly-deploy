## Objectifs

- Comprendre le rôle de PDO et d'une connexion à une base de données
- Se connecter à MySQL avec les bonnes options
- Exécuter des requêtes préparées et comprendre pourquoi elles sont indispensables
- Récupérer des résultats et écrire des données
- Gérer les erreurs sans exposer d'information sensible
- Utiliser une transaction et organiser l'accès aux données dans une classe

## Le besoin

Le formulaire de contact enregistre ses messages dans un fichier texte. Cela fonctionne pour une démonstration, mais pas pour une vraie application :

- impossible de **rechercher** efficacement les messages d'une adresse précise parmi des milliers de lignes ;
- deux visiteurs qui envoient un message **au même moment** peuvent mélanger leurs écritures ;
- impossible de **relier** un message à un apprenant, à une formation, à une réponse du secrétariat.

Tout ce que nous avons appris dans le bloc SQL, tables, contraintes, jointures et transactions, répond à ces besoins. Il faut maintenant que le script PHP puisse **parler à la base de données** : ouvrir une connexion, envoyer des requêtes et récupérer les résultats. C'est le rôle de PDO.

## Définitions

> **PDO (PHP Data Objects).** L'interface standard de PHP pour accéder à une base de données. Le même code fonctionne avec MySQL, PostgreSQL ou SQLite : seule la chaîne de connexion change.

> **DSN (Data Source Name).** La chaîne qui décrit la base à laquelle se connecter : le pilote, l'hôte, le nom de la base et le jeu de caractères.

> **Requête préparée.** Une requête envoyée en deux temps : d'abord le code SQL avec des marqueurs, ensuite les valeurs. Les valeurs ne peuvent jamais être interprétées comme du SQL.

> **Marqueur (placeholder).** Un emplacement réservé dans une requête préparée : nommé (`:email`) ou positionnel (`?`).

> **Repository.** Une classe qui regroupe les requêtes d'accès aux données d'un même domaine.

## Se connecter

```php
<?php

declare(strict_types=1);

$pdo = new PDO(
    'mysql:host=localhost;port=3306;dbname=formations;charset=utf8mb4',
    getenv('DB_USERNAME'),
    getenv('DB_PASSWORD'),
    [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]
);
```

| Élément | Rôle |
|---------|------|
| `mysql:host=...;dbname=...` | Le DSN : pilote MySQL, serveur et base |
| `charset=utf8mb4` | Garantit le bon traitement des accents et des emojis |
| `ERRMODE_EXCEPTION` | Une erreur SQL lève une `PDOException` au lieu d'échouer en silence. C'est le mode par défaut depuis PHP 8 |
| `FETCH_ASSOC` | Les lignes sont renvoyées sous forme de tableaux associatifs `['titre' => 'Java', ...]` |
| `EMULATE_PREPARES => false` | Les requêtes sont réellement préparées par le serveur MySQL, et les types numériques sont conservés |

Les identifiants de connexion ne s'écrivent **jamais en dur** dans le code : un dépôt Git partagé ou une fuite de code source donnerait accès à la base. Ils viennent de variables d'environnement ou d'un fichier de configuration non versionné.

On crée **une seule** connexion par requête HTTP, et on la transmet aux classes qui en ont besoin. En ouvrir une à chaque fonction ralentirait fortement l'application.

## Pourquoi les requêtes préparées ?

La tentation est de construire la requête en concaténant les valeurs reçues :

```php
// DANGEREUX : ne jamais faire cela
$email = $_POST['email'];
$resultat = $pdo->query("SELECT * FROM apprenants WHERE email = '$email'");
```

Si un visiteur saisit `' OR '1'='1` dans le champ e-mail, la requête devient :

```sql
SELECT * FROM apprenants WHERE email = '' OR '1'='1'
```

La condition est toujours vraie : la requête renvoie **tous** les apprenants. C'est une **injection SQL**, l'une des failles les plus graves et les plus répandues. Le cours suivant la détaille.

Une requête préparée sépare **le code** et **les données** :

```text
1. Envoi du modèle :   SELECT * FROM apprenants WHERE email = :email
2. Envoi des valeurs : email = "' OR '1'='1"
```

La base a déjà analysé la structure de la requête à l'étape 1. À l'étape 2, la valeur est traitée comme une **simple chaîne à comparer**, quels que soient les caractères qu'elle contient. L'injection devient impossible.

## Exécuter une requête préparée

```php
$requete = $pdo->prepare(
    'SELECT id, titre, prix FROM formations WHERE categorie_id = :categorie AND prix <= :prixMax ORDER BY prix'
);
$requete->execute([
    'categorie' => 2,
    'prixMax' => 800,
]);
$formations = $requete->fetchAll();
```

```php
// Avec des marqueurs positionnels
$requete = $pdo->prepare('SELECT * FROM formations WHERE categorie_id = ? AND prix <= ?');
$requete->execute([2, 800]);
```

Les marqueurs nommés sont plus lisibles dès qu'il y a plusieurs paramètres. Une requête sans aucune valeur variable peut s'exécuter directement avec `$pdo->query('SELECT COUNT(*) FROM formations')`.

## Récupérer les résultats

| Méthode | Résultat |
|---------|----------|
| `fetch()` | La ligne suivante, ou `false` s'il n'y en a plus |
| `fetchAll()` | Toutes les lignes dans un tableau |
| `fetchColumn()` | La première colonne de la ligne suivante, pratique pour un `COUNT` |

```php
$requete = $pdo->prepare('SELECT * FROM apprenants WHERE email = :email');
$requete->execute(['email' => $email]);
$apprenant = $requete->fetch();

if ($apprenant === false) {
    // aucun apprenant avec cette adresse
}

$nombre = (int) $pdo->query('SELECT COUNT(*) FROM formations')->fetchColumn();
```

Pour un grand nombre de lignes, parcourir le résultat avec `fetch()` dans une boucle `while` consomme moins de mémoire que de tout charger avec `fetchAll()`.

## Écrire des données

```php
$requete = $pdo->prepare(
    'INSERT INTO apprenants (prenom, nom, email) VALUES (:prenom, :nom, :email)'
);
$requete->execute([
    'prenom' => $prenom,
    'nom' => $nom,
    'email' => $email,
]);
$id = (int) $pdo->lastInsertId();

$requete = $pdo->prepare('UPDATE formations SET prix = :prix WHERE id = :id');
$requete->execute(['prix' => 950, 'id' => 2]);
$lignesModifiees = $requete->rowCount();
```

`lastInsertId()` donne l'identifiant attribué par `AUTO_INCREMENT`. `rowCount()` indique combien de lignes ont été touchées : `0` après un `UPDATE` peut signaler un identifiant inexistant.

## Gérer les erreurs

En mode exception, une erreur SQL lève une `PDOException`. Son code suit la norme SQLSTATE : `23000` signale une violation de contrainte, comme un doublon sur une colonne `UNIQUE`.

```php
try {
    $requete->execute(['prenom' => $prenom, 'nom' => $nom, 'email' => $email]);
} catch (PDOException $e) {
    if ($e->getCode() === '23000') {
        $erreurs['email'] = 'Un compte existe déjà avec cette adresse.';
    } else {
        error_log($e->getMessage());
        throw $e;
    }
}
```

N'affichez **jamais** le message brut d'une `PDOException` à l'utilisateur. Il peut contenir le nom des tables, des colonnes ou un extrait de la requête : autant d'informations utiles à un attaquant. Journalisez-le côté serveur et affichez un message générique.

## Les transactions

Le bloc SQL a montré l'intérêt des transactions. Avec PDO :

```php
try {
    $pdo->beginTransaction();

    $pdo->prepare('DELETE FROM inscriptions WHERE apprenant_id = :apprenant AND formation_id = :ancienne')
        ->execute(['apprenant' => 4, 'ancienne' => 7]);

    $pdo->prepare('INSERT INTO inscriptions (apprenant_id, formation_id, inscrit_le) VALUES (:apprenant, :nouvelle, CURDATE())')
        ->execute(['apprenant' => 4, 'nouvelle' => 8]);

    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    throw $e;
}
```

Si la deuxième requête échoue, le `rollBack` annule la première : l'apprenant garde son inscription d'origine. `Throwable` capture à la fois les exceptions et les erreurs de PHP.

## Organiser l'accès aux données

Des requêtes SQL dispersées dans toutes les pages deviennent vite ingérables : la même requête est recopiée, une modification de table oblige à chercher partout. On les regroupe dans une classe dédiée, un **repository**, qui reçoit la connexion par son constructeur.

```php
final class ApprenantRepository
{
    public function __construct(private PDO $pdo)
    {
    }

    public function trouverParEmail(string $email): ?array
    {
        $requete = $this->pdo->prepare('SELECT id, prenom, nom, email FROM apprenants WHERE email = :email');
        $requete->execute(['email' => $email]);

        return $requete->fetch() ?: null;
    }

    public function creer(string $prenom, string $nom, string $email): int
    {
        $this->pdo->prepare('INSERT INTO apprenants (prenom, nom, email) VALUES (:prenom, :nom, :email)')
            ->execute(['prenom' => $prenom, 'nom' => $nom, 'email' => $email]);

        return (int) $this->pdo->lastInsertId();
    }

    /** @return array<int, array<string, mixed>> */
    public function listerParPage(int $page, int $parPage = 20): array
    {
        $requete = $this->pdo->prepare(
            'SELECT id, prenom, nom FROM apprenants ORDER BY nom, id LIMIT :limite OFFSET :decalage'
        );
        $requete->bindValue('limite', $parPage, PDO::PARAM_INT);
        $requete->bindValue('decalage', ($page - 1) * $parPage, PDO::PARAM_INT);
        $requete->execute();

        return $requete->fetchAll();
    }
}
```

- `?: null` transforme le `false` renvoyé par `fetch()` en `null`, plus explicite pour l'appelant.
- `bindValue` avec `PDO::PARAM_INT` précise le type : indispensable pour `LIMIT` et `OFFSET`, qui n'acceptent pas une chaîne.
- Le reste de l'application appelle `$repository->trouverParEmail(...)` sans écrire de SQL.

C'est exactement le rôle que joueront les modèles **Eloquent** dans Laravel, avec beaucoup moins de code à écrire.

## Exemple complet

Le formulaire de contact enregistre désormais ses messages en base :

```sql
CREATE TABLE messages (
    id         BIGINT        NOT NULL AUTO_INCREMENT,
    email      VARCHAR(100)  NOT NULL,
    contenu    VARCHAR(2000) NOT NULL,
    envoye_le  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);
```

```php
final class MessageRepository
{
    public function __construct(private PDO $pdo)
    {
    }

    public function enregistrer(string $email, string $contenu): int
    {
        $this->pdo->prepare('INSERT INTO messages (email, contenu) VALUES (:email, :contenu)')
            ->execute(['email' => $email, 'contenu' => $contenu]);

        return (int) $this->pdo->lastInsertId();
    }

    public function compterDepuis(string $email, DateTimeImmutable $depuis): int
    {
        $requete = $this->pdo->prepare(
            'SELECT COUNT(*) FROM messages WHERE email = :email AND envoye_le >= :depuis'
        );
        $requete->execute(['email' => $email, 'depuis' => $depuis->format('Y-m-d H:i:s')]);

        return (int) $requete->fetchColumn();
    }
}
```

```php
$messages = new MessageRepository($pdo);

if ($messages->compterDepuis($email, new DateTimeImmutable('-1 hour')) >= 3) {
    $erreurs['message'] = 'Trop de messages envoyés, réessayez plus tard.';
} else {
    $messages->enregistrer($email, $message);
}
```

La base permet maintenant ce que le fichier ne permettait pas : limiter le nombre de messages par adresse sur une heure, en une requête.

## Les erreurs fréquentes

- **Concaténer une donnée reçue** dans une requête SQL au lieu de la préparer.
- **Des identifiants de connexion en dur** dans un fichier versionné.
- **Afficher le message d'une `PDOException`** à l'utilisateur.
- **Oublier `charset=utf8mb4`**, et des accents transformés en caractères illisibles.
- **Passer une chaîne à `LIMIT`** sans `PDO::PARAM_INT`.
- **Des requêtes dispersées** dans toutes les pages au lieu d'un repository.

## Retour au besoin

Les messages sont désormais stockés dans une vraie table, que l'on peut interroger, relier à d'autres données et protéger par des contraintes. Les requêtes préparées rendent toute injection SQL impossible, les transactions garantissent la cohérence et les repositories centralisent le SQL. Le script PHP dispose maintenant de toute la puissance du bloc SQL.

## À retenir

- PDO en mode exception, `FETCH_ASSOC` et `utf8mb4`, avec des identifiants qui viennent de l'environnement.
- Toujours des requêtes préparées pour les données variables : le code et les données voyagent séparément.
- Un message d'erreur SQL ne s'affiche jamais à l'utilisateur.
- `beginTransaction`, `commit` et `rollBack` pour les opérations liées.
- Les requêtes d'un même domaine se regroupent dans un repository.

## Pour aller plus loin

- PDO dans le manuel officiel : [php.net/manual/fr/book.pdo.php](https://www.php.net/manual/fr/book.pdo.php)
