## Objectifs

- Comprendre pourquoi tester et quoi tester en priorité
- Distinguer tests unitaires et tests de fonctionnalité
- Configurer une base de test isolée
- Préparer des données avec les factories et leurs états
- Tester une route, sa validation et ses autorisations
- Neutraliser les services externes avec les fakes

## Le besoin

L'API d'inscription contient désormais des règles importantes : un apprenant ne s'inscrit pas deux fois, une formation complète refuse les inscriptions, un formateur ne note que ses propres apprenants. Un jour, un développeur modifie la policy pour ajouter un nouveau rôle. Il vérifie à la main que son nouveau rôle fonctionne, et met en production.

Sans le savoir, il a cassé la règle qui empêchait un formateur de noter les apprenants d'un collègue. Personne ne s'en aperçoit pendant trois semaines.

Vérifier à la main, après chaque modification, **toutes** les règles de l'application est impossible : il y en a trop, et c'est exactement le genre de tâche que l'on finit par négliger. Les tests automatisés vérifient tout, à chaque modification, en quelques secondes.

## Définitions

> **Test automatisé.** Un programme qui exécute une partie de l'application et vérifie que le résultat est celui attendu.

> **Régression.** Une fonctionnalité qui fonctionnait et qui est cassée par une modification.

> **Test unitaire.** Un test qui vérifie une classe ou une fonction isolée, sans base de données ni requête HTTP.

> **Test de fonctionnalité (feature test).** Un test qui envoie une vraie requête HTTP à l'application, et vérifie la réponse et l'état de la base.

> **Assertion.** Une vérification : « le statut doit être 201 », « la base doit contenir cette ligne ».

> **Factory.** Une classe qui fabrique des modèles avec des données réalistes, pour préparer les tests.

> **Fake.** Une implémentation factice d'un service externe (e-mails, notifications, stockage), qui enregistre les appels au lieu de les exécuter.

## Pourquoi tester ?

| Bénéfice | Détail |
|----------|--------|
| Contre les régressions | Chaque règle cassée est détectée immédiatement |
| Confiance | On ose refactoriser, puisque les tests signalent tout changement de comportement |
| Documentation | Un test nommé « refuse une inscription en double » décrit une règle métier |
| Intégration continue | Les tests sont lancés automatiquement avant chaque fusion |

## Les outils

Laravel fonctionne avec **PHPUnit** ou **Pest**, un outil à la syntaxe plus concise qui s'appuie sur PHPUnit. Les exemples ci-dessous utilisent Pest, proposé par défaut par l'installateur. Les deux coexistent sans problème.

| Type | Dossier | Teste |
|------|---------|-------|
| Unitaire | `tests/Unit` | Une classe isolée, sans base ni HTTP |
| Fonctionnalité | `tests/Feature` | Une requête HTTP complète, de la route à la base |

```bash
php artisan make:test InscriptionApiTest          # test de fonctionnalité
php artisan make:test CalculMoyenneTest --unit    # test unitaire
php artisan test                                  # lancer tous les tests
php artisan test --filter=inscription             # lancer seulement certains tests
```

Dans une application Laravel, les **tests de fonctionnalité** apportent le plus de valeur : ils vérifient d'un coup la route, le middleware, la validation, la policy, le contrôleur et la base.

## La base de test

Les tests ne doivent **jamais** toucher la base de développement, encore moins celle de production. Le fichier `phpunit.xml` configure une base dédiée, souvent **SQLite en mémoire** : rapide, et recréée à chaque exécution.

```xml
<env name="DB_CONNECTION" value="sqlite"/>
<env name="DB_DATABASE" value=":memory:"/>
```

Le trait `RefreshDatabase` applique les migrations et remet la base à zéro **avant chaque test**. Chaque test part d'un état connu, et ne dépend jamais des autres. On l'active pour tous les tests de fonctionnalité dans `tests/Pest.php` :

```php
pest()->extend(Tests\TestCase::class)
    ->use(Illuminate\Foundation\Testing\RefreshDatabase::class)
    ->in('Feature');
```

## Les factories et leurs états

Une **factory** fabrique des modèles valides en une ligne. Des **états** décrivent des variantes nommées :

```php
class UserFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'password' => 'Motdepasse!2026',
            'role' => Role::Apprenant,
        ];
    }

    public function formateur(): static
    {
        return $this->state(['role' => Role::Formateur]);
    }

    public function admin(): static
    {
        return $this->state(['role' => Role::Admin]);
    }
}
```

```php
$apprenant = User::factory()->create();
$formateur = User::factory()->formateur()->create();
$formations = Formation::factory()->count(10)->create();
$brouillon = Formation::factory()->brouillon()->create(['titre' => 'Laravel avancé']);
$formation = Formation::factory()->for($formateur, 'formateur')->create();
```

Les factories rendent les tests **lisibles** : on ne voit que les données qui comptent pour le cas testé, le reste est généré.

## Un test de fonctionnalité

```php
use App\Models\Formation;
use App\Models\User;

it('liste uniquement les formations publiées', function () {
    Formation::factory()->count(3)->create();
    Formation::factory()->brouillon()->create();

    $this->getJson('/api/formations')
        ->assertOk()
        ->assertJsonCount(3, 'data');
});

it('refuse une formation sans titre', function () {
    $formateur = User::factory()->formateur()->create();

    $this->actingAs($formateur)
        ->postJson('/api/formations', ['titre' => '', 'prix' => 100])
        ->assertUnprocessable()
        ->assertJsonValidationErrors(['titre']);
});

it('interdit à un formateur de supprimer la formation d\'un autre', function () {
    $formation = Formation::factory()->create();
    $autreFormateur = User::factory()->formateur()->create();

    $this->actingAs($autreFormateur)
        ->deleteJson("/api/formations/{$formation->id}")
        ->assertForbidden();

    $this->assertModelExists($formation);
});
```

Chaque test suit le même schéma :

1. **Préparer** : créer les données avec les factories.
2. **Agir** : envoyer la requête, en tant qu'un utilisateur donné.
3. **Vérifier** : le statut, le JSON renvoyé et l'état de la base.

`actingAs` simule un utilisateur connecté, sans passer par la page de connexion. Ces tests supposent un état `formateur()` défini dans `UserFactory`, et le troisième une policy qui réserve la suppression au formateur responsable de la formation.

## Les assertions courantes

| Assertion | Vérifie |
|-----------|---------|
| `assertOk()`, `assertCreated()`, `assertNoContent()` | Statuts 200, 201 et 204 |
| `assertUnauthorized()`, `assertForbidden()`, `assertNotFound()` | Statuts 401, 403 et 404 |
| `assertUnprocessable()` | Statut 422 |
| `assertJsonValidationErrors(['titre'])` | Les champs en erreur |
| `assertJsonPath('data.titre', 'Java')` | Une valeur précise du JSON |
| `assertJsonCount(3, 'data')` | Le nombre d'éléments d'une liste |
| `assertJsonMissingPath('data.password')` | Un champ absent de la réponse |
| `assertDatabaseHas('inscriptions', [...])` | Une ligne existe en base |
| `assertDatabaseCount('inscriptions', 1)` | Le nombre de lignes |
| `assertModelExists($modele)`, `assertModelMissing($modele)` | Un modèle existe ou a été supprimé |

`assertJsonMissingPath` est précieux pour la sécurité : il vérifie qu'un champ sensible n'est pas exposé par une API Resource.

## Quoi tester en priorité ?

On ne teste pas tout avec la même intensité. Les priorités :

| Priorité | Quoi | Exemple |
|----------|------|---------|
| 1 | Les **autorisations** : chaque action interdite renvoie bien 403 | Un formateur ne supprime pas la formation d'un collègue |
| 2 | Les **règles métier** | Une inscription en double est refusée, une formation complète aussi |
| 3 | La **validation** et ses cas limites | Une note de 20 est acceptée, 20,5 refusée |
| 4 | Les **cas d'erreur** | Une ressource inexistante renvoie 404 |
| 5 | Le cas nominal | Une inscription valide est enregistrée |

Les failles et les bugs se cachent dans les cas d'erreur et les autorisations, bien plus que dans le cas nominal que l'on vérifie naturellement à la main.

Un bon test a **un nom qui décrit le comportement** et vérifie **une seule idée**. Quand il échoue, on sait immédiatement quelle règle est cassée.

## Neutraliser les services externes

Un test ne doit pas envoyer de vrais e-mails, ni appeler un vrai service de paiement. Laravel fournit des **fakes** pour ses principaux services :

```php
use App\Mail\ConfirmationInscription;
use Illuminate\Support\Facades\Mail;

it('envoie un e-mail de confirmation à l\'inscription', function () {
    Mail::fake();
    $apprenant = User::factory()->create();
    $formation = Formation::factory()->create();

    $this->actingAs($apprenant)
        ->postJson("/api/formations/{$formation->id}/inscriptions")
        ->assertCreated();

    Mail::assertSent(ConfirmationInscription::class, fn ($mail) => $mail->hasTo($apprenant->email));
});
```

`Mail::fake()` remplace l'envoi réel par un enregistrement. `Mail::assertSent` vérifie ensuite qu'un e-mail précis a été demandé, au bon destinataire. Des fakes similaires existent pour les notifications (`Notification::fake`), les files d'attente (`Queue::fake`), le stockage de fichiers (`Storage::fake`) et les requêtes HTTP sortantes (`Http::fake`).

## Exemple complet

Les tests de la règle de notation, qui auraient détecté la régression du début :

```php
use App\Models\Formation;
use App\Models\User;

beforeEach(function () {
    $this->formateur = User::factory()->formateur()->create();
    $this->formation = Formation::factory()->for($this->formateur, 'formateur')->create();
    $this->apprenant = User::factory()->create();
    $this->formation->apprenants()->attach($this->apprenant);
});

it('permet au formateur responsable de noter un inscrit', function () {
    $this->actingAs($this->formateur)
        ->patchJson("/api/formations/{$this->formation->id}/inscrits/{$this->apprenant->id}", ['note_finale' => 15.5])
        ->assertOk();

    $this->assertDatabaseHas('inscriptions', [
        'user_id' => $this->apprenant->id,
        'formation_id' => $this->formation->id,
        'note_finale' => 15.5,
    ]);
});

it('interdit à un autre formateur de noter', function () {
    $collegue = User::factory()->formateur()->create();

    $this->actingAs($collegue)
        ->patchJson("/api/formations/{$this->formation->id}/inscrits/{$this->apprenant->id}", ['note_finale' => 20])
        ->assertForbidden();
});

it('refuse une note hors de l\'intervalle 0 à 20', function (float $note) {
    $this->actingAs($this->formateur)
        ->patchJson("/api/formations/{$this->formation->id}/inscrits/{$this->apprenant->id}", ['note_finale' => $note])
        ->assertUnprocessable()
        ->assertJsonValidationErrors(['note_finale']);
})->with([-1, 20.5, 100]);

it('refuse un visiteur non connecté', function () {
    $this->patchJson("/api/formations/{$this->formation->id}/inscrits/{$this->apprenant->id}", ['note_finale' => 12])
        ->assertUnauthorized();
});
```

- `beforeEach` prépare les données communes à tous les tests du fichier.
- `->with([...])` exécute le même test avec plusieurs valeurs : c'est un **jeu de données**, qui couvre les cas limites sans dupliquer le code.
- Le deuxième test aurait échoué le jour de la modification de la policy, avant la mise en production.

## Les erreurs fréquentes

- **Tester sur la base de développement**, et perdre ses données.
- **Des tests qui dépendent les uns des autres** ou de l'ordre d'exécution.
- **Ne tester que le cas nominal.**
- **Envoyer de vrais e-mails** pendant les tests, faute de `Mail::fake()`.
- **Des tests qui vérifient dix choses**, et dont l'échec n'explique rien.
- **Des données de test écrites à la main** sur vingt lignes au lieu d'une factory.

## Retour au besoin

La régression du début aurait été détectée en quelques secondes, avant même la fusion de la modification. Chaque règle importante, et surtout chaque autorisation, est vérifiée par un test lisible qui la documente. La base de test isolée, les factories et les fakes rendent ces tests rapides, fiables et indépendants. On peut désormais faire évoluer l'application avec confiance.

## À retenir

- Tests de fonctionnalité pour les routes, tests unitaires pour les classes isolées.
- `RefreshDatabase` et une base dédiée : chaque test part d'un état propre.
- Les factories et leurs états fabriquent des données réalistes en une ligne.
- Testez en priorité les autorisations, les règles métier, la validation et les erreurs.
- `Mail::fake()` et les autres fakes neutralisent les services externes.

## Pour aller plus loin

- Les tests dans Laravel : [laravel.com/docs/testing](https://laravel.com/docs/testing)
- Les tests HTTP : [laravel.com/docs/http-tests](https://laravel.com/docs/http-tests)
- La documentation de Pest : [pestphp.com/docs](https://pestphp.com/docs)
