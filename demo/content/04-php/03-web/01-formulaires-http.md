## Objectifs

- Comprendre le protocole HTTP et le cycle requête et réponse
- Distinguer les méthodes `GET` et `POST` et connaître les codes de statut
- Lire les données reçues avec les superglobales
- Valider les saisies côté serveur et réafficher les erreurs
- Appliquer le motif Post-Redirect-Get
- Conserver des informations d'une page à l'autre avec les sessions

## Le besoin

L'organisme de formation veut un formulaire de contact sur son site. Le visiteur saisit son adresse et un message, clique sur « Envoyer », et le message doit être enregistré. Plusieurs questions se posent immédiatement :

- comment les données saisies dans le navigateur **arrivent-elles** jusqu'au script PHP ?
- que faire si l'adresse est **invalide** ou le message **vide** ? Il faut réafficher le formulaire avec les erreurs, sans obliger le visiteur à tout retaper ;
- si le visiteur **actualise** la page après l'envoi, le message ne doit pas être enregistré une seconde fois ;
- comment **se souvenir** qu'un utilisateur est connecté quand il passe d'une page à l'autre ?

Pour répondre, il faut comprendre comment le navigateur et le serveur communiquent : le protocole HTTP.

## Définitions

> **HTTP (HyperText Transfer Protocol).** Le protocole de communication du web. Le navigateur envoie une requête, le serveur renvoie une réponse.

> **Requête.** Un message du navigateur vers le serveur : une méthode, une URL, des en-têtes et parfois un corps contenant des données.

> **Réponse.** Un message du serveur vers le navigateur : un code de statut, des en-têtes et un corps, le plus souvent du HTML.

> **Superglobale.** Un tableau fourni par PHP, disponible partout, qui contient les informations de la requête : `$_GET`, `$_POST`, `$_SERVER`...

> **Sans état (stateless).** HTTP ne garde aucun souvenir entre deux requêtes : chacune est traitée indépendamment.

> **Session.** Un mécanisme qui associe des données stockées sur le serveur à un visiteur, reconnu grâce à un cookie.

## Le cycle requête et réponse

```text
POST /contact.php HTTP/1.1                     HTTP/1.1 303 See Other
Host: formations.exemple.fr                    Location: /contact.php?envoye=1
Content-Type: application/x-www-form-urlencoded
                                               (la réponse redirige le navigateur)
email=emma%40exemple.fr&message=Bonjour...
```

À gauche, la requête envoyée par le navigateur au clic sur « Envoyer ». À droite, la réponse du serveur. Chaque échange est indépendant : le serveur ne se souvient de rien entre deux requêtes.

## Les méthodes GET et POST

| Méthode | Usage | Données | Visible dans l'URL | Mise en favori |
|---------|-------|---------|--------------------|----------------|
| `GET` | Lire une ressource, faire une recherche, filtrer | Dans l'URL : `?page=2&q=java` | Oui | Possible |
| `POST` | Créer ou modifier, envoyer un formulaire | Dans le corps de la requête | Non | Impossible |

Une requête `GET` ne doit **jamais modifier** de données. Un moteur de recherche qui parcourt votre site, ou un navigateur qui précharge les liens, pourrait la déclencher sans que personne ne le veuille. Un lien « Supprimer » en `GET` peut ainsi effacer des données à l'insu de tous.

Ne mettez jamais d'information sensible dans une URL : elle apparaît dans l'historique du navigateur et dans les journaux des serveurs.

## Les codes de statut

| Code | Signification | Exemple |
|------|---------------|---------|
| 200 | Succès | La page s'affiche |
| 301, 302, 303 | Redirection | Après l'envoi d'un formulaire |
| 400 | Requête invalide | Données mal formées |
| 403 | Accès interdit | Page réservée aux administrateurs |
| 404 | Ressource introuvable | Page inexistante |
| 500 | Erreur du serveur | Exception non capturée |

```php
http_response_code(404);
```

## Les superglobales

PHP expose la requête dans des tableaux disponibles partout :

| Superglobale | Contenu |
|--------------|---------|
| `$_GET` | Paramètres de l'URL |
| `$_POST` | Champs d'un formulaire envoyé en `POST` |
| `$_SERVER` | Informations sur la requête et le serveur : `REQUEST_METHOD`, `REQUEST_URI`, `REMOTE_ADDR` |
| `$_SESSION` | Données de session, après `session_start()` |
| `$_COOKIE` | Cookies envoyés par le navigateur |
| `$_FILES` | Fichiers téléversés |

```php
// URL : /catalogue.php?categorie=2&page=3
$categorie = $_GET['categorie'] ?? null;    // '2' : toujours une chaîne
$page = (int) ($_GET['page'] ?? 1);          // 3, converti en entier
```

Toutes les valeurs reçues sont des **chaînes**, ou des tableaux de chaînes. Il faut les convertir et les valider avant usage.

## Un formulaire de contact

```php
<form method="post" action="contact.php" novalidate>
    <label for="email">Adresse e-mail</label>
    <input type="email" id="email" name="email" required>

    <label for="message">Message</label>
    <textarea id="message" name="message" required></textarea>

    <button type="submit">Envoyer</button>
</form>
```

L'attribut `name` de chaque champ devient la clé dans `$_POST` : `$_POST['email']`, `$_POST['message']`. Un champ sans `name` n'est pas envoyé.

## Valider côté serveur

Les attributs `required` ou `type="email"` améliorent l'expérience de l'utilisateur, mais ils se **contournent** en quelques secondes : outils de développement du navigateur, requête envoyée par un script. **Toute donnée reçue est suspecte** et doit être validée par le serveur.

```php
<?php

declare(strict_types=1);

$erreurs = [];
$email = '';
$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim($_POST['email'] ?? '');
    $message = trim($_POST['message'] ?? '');

    if (filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
        $erreurs['email'] = 'L\'adresse e-mail n\'est pas valide.';
    }
    if (mb_strlen($message) < 10 || mb_strlen($message) > 2000) {
        $erreurs['message'] = 'Le message doit contenir entre 10 et 2000 caractères.';
    }

    if ($erreurs === []) {
        enregistrerMessage($email, $message);
        header('Location: contact.php?envoye=1', true, 303);
        exit;
    }
}
```

| Élément | Rôle |
|---------|------|
| `$_SERVER['REQUEST_METHOD'] === 'POST'` | Distingue l'affichage du formulaire (`GET`) de son envoi (`POST`) |
| `?? ''` | Évite une erreur si le champ est absent de la requête |
| `trim` | Retire les espaces superflus au début et à la fin |
| `mb_strlen` | Compte les **caractères** et non les octets : une lettre accentuée compte pour un |
| `filter_var` | Validations prêtes à l'emploi : `FILTER_VALIDATE_EMAIL`, `FILTER_VALIDATE_INT`, `FILTER_VALIDATE_URL` |
| `$erreurs` | Un message par champ, pour les afficher au bon endroit |

## Réafficher le formulaire en cas d'erreur

En cas d'erreur, on réaffiche le formulaire avec les **valeurs saisies** et les **messages**, pour que l'utilisateur n'ait pas tout à retaper. Chaque valeur réaffichée passe par `htmlspecialchars`, qui empêche l'injection de code dans la page (voir le cours sur la sécurité).

```php
<label for="email">Adresse e-mail</label>
<input type="email" id="email" name="email" value="<?= htmlspecialchars($email) ?>">
<?php if (isset($erreurs['email'])): ?>
    <p class="erreur"><?= htmlspecialchars($erreurs['email']) ?></p>
<?php endif; ?>
```

La syntaxe `if (...): ... endif;` est une écriture alternative de PHP, plus lisible au milieu du HTML.

## Le motif Post-Redirect-Get

Après un traitement réussi en `POST`, si le serveur affiche directement la page de confirmation, le navigateur garde en mémoire la requête `POST`. Au moindre rafraîchissement, il propose de **renvoyer le formulaire**, et le message est enregistré une seconde fois.

Le motif **Post-Redirect-Get** (PRG) règle le problème : après le traitement, le serveur répond par une **redirection** vers une page en `GET`.

```text
1. POST /contact.php            →  traitement, enregistrement
2. 303 See Other                →  Location: /contact.php?envoye=1
3. GET /contact.php?envoye=1    →  affichage de la confirmation
```

Actualiser la page ne relance plus que l'étape 3, sans effet. N'oubliez pas `exit` après `header('Location: ...')` : sans lui, le script continue de s'exécuter après avoir demandé la redirection.

Le code 303 « See Other » demande explicitement au navigateur de suivre la redirection en `GET`.

## Les sessions

HTTP est **sans état** : chaque requête est indépendante. Pour se souvenir qu'un utilisateur est connecté, ou pour conserver un panier, on utilise une **session**.

```text
1re requête  : pas de cookie         →  PHP crée une session et envoie le cookie PHPSESSID=a91f...
requêtes suivantes : cookie PHPSESSID →  PHP retrouve les données de la session sur le serveur
```

```php
session_start();                          // à appeler avant tout affichage

$_SESSION['utilisateur_id'] = 42;         // enregistrer
$id = $_SESSION['utilisateur_id'] ?? null;   // lire, sur une autre page
unset($_SESSION['panier']);               // retirer une donnée
session_destroy();                        // à la déconnexion
```

Les données restent sur le **serveur** : le navigateur ne détient qu'un identifiant aléatoire. Quelques règles de sécurité :

- après une connexion, appelez `session_regenerate_id(true)` pour changer l'identifiant, et empêcher un attaquant de réutiliser un identifiant qu'il aurait imposé à la victime ;
- configurez le cookie de session avec les attributs `HttpOnly` (inaccessible au JavaScript), `Secure` (envoyé uniquement en HTTPS) et `SameSite=Lax`.

Les **messages flash** sont un usage courant de la session : un message stocké avant une redirection, affiché une seule fois sur la page suivante, puis supprimé.

```php
$_SESSION['flash'] = 'Votre message a bien été envoyé.';
header('Location: contact.php', true, 303);
exit;

// Sur la page suivante
if (isset($_SESSION['flash'])) {
    echo '<p class="succes">' . htmlspecialchars($_SESSION['flash']) . '</p>';
    unset($_SESSION['flash']);
}
```

## Exemple complet

Le formulaire de contact complet, en un seul fichier :

```php
<?php

declare(strict_types=1);

session_start();

$erreurs = [];
$email = '';
$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim($_POST['email'] ?? '');
    $message = trim($_POST['message'] ?? '');

    if (filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
        $erreurs['email'] = 'L\'adresse e-mail n\'est pas valide.';
    }
    if (mb_strlen($message) < 10) {
        $erreurs['message'] = 'Le message doit contenir au moins 10 caractères.';
    }

    if ($erreurs === []) {
        file_put_contents(__DIR__ . '/messages.log', "$email : $message" . PHP_EOL, FILE_APPEND);
        $_SESSION['flash'] = 'Merci, votre message a bien été envoyé.';
        header('Location: contact.php', true, 303);
        exit;
    }
}

$flash = $_SESSION['flash'] ?? null;
unset($_SESSION['flash']);
?>
<!DOCTYPE html>
<html lang="fr">
<body>
<?php if ($flash !== null): ?>
    <p class="succes"><?= htmlspecialchars($flash) ?></p>
<?php endif; ?>

<form method="post" action="contact.php" novalidate>
    <label for="email">Adresse e-mail</label>
    <input type="email" id="email" name="email" value="<?= htmlspecialchars($email) ?>">
    <?php if (isset($erreurs['email'])): ?>
        <p class="erreur"><?= htmlspecialchars($erreurs['email']) ?></p>
    <?php endif; ?>

    <label for="message">Message</label>
    <textarea id="message" name="message"><?= htmlspecialchars($message) ?></textarea>
    <?php if (isset($erreurs['message'])): ?>
        <p class="erreur"><?= htmlspecialchars($erreurs['message']) ?></p>
    <?php endif; ?>

    <button type="submit">Envoyer</button>
</form>
</body>
</html>
```

Le cours suivant remplacera le fichier de messages par une vraie base de données, et le cours sur la sécurité ajoutera une protection contre les requêtes forgées.

## Les erreurs fréquentes

- **Faire confiance à la validation du navigateur** et ne rien vérifier côté serveur.
- **Modifier des données en `GET`.**
- **Afficher la confirmation directement après un `POST`**, et des envois en double à chaque actualisation.
- **Oublier `exit`** après une redirection.
- **Réafficher une saisie sans `htmlspecialchars`.**
- **Appeler `session_start()` après un affichage**, et une erreur « headers already sent ».

## Retour au besoin

Les données du formulaire arrivent dans `$_POST`, sont validées côté serveur, et le formulaire se réaffiche avec les erreurs et les valeurs saisies. Après un envoi réussi, la redirection empêche tout doublon en cas d'actualisation, et la session transporte le message de confirmation d'une page à l'autre. Ces mécanismes sont exactement ceux que Laravel automatise : validation, redirection avec les anciennes valeurs, messages flash et sessions.

## À retenir

- HTTP est sans état : une requête, une réponse, et aucun souvenir entre les deux.
- `GET` pour lire, `POST` pour modifier.
- Toute donnée reçue est une chaîne, à valider côté serveur quels que soient les contrôles du navigateur.
- Après un `POST` réussi, on redirige vers un `GET`, et `header('Location: ...')` est toujours suivi de `exit`.
- La session conserve des données côté serveur, `session_regenerate_id(true)` après une connexion.

## Pour aller plus loin

- La gestion des formulaires dans le manuel officiel : [php.net/manual/fr/tutorial.forms.php](https://www.php.net/manual/fr/tutorial.forms.php)
- Les sessions : [php.net/manual/fr/book.session.php](https://www.php.net/manual/fr/book.session.php)
- La documentation MDN sur HTTP, en français : [developer.mozilla.org/fr/docs/Web/HTTP](https://developer.mozilla.org/fr/docs/Web/HTTP)
