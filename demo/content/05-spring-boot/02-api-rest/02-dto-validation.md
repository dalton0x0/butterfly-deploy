## Objectifs

- Comprendre pourquoi une API n'expose jamais ses entités directement
- Écrire des DTO de requête et de réponse avec des records
- Convertir une entité en DTO avec une méthode de fabrique
- Valider les données reçues avec Jakarta Validation
- Distinguer validation de format et règles métier
- Créer une contrainte de validation personnalisée

## Le besoin

Pour aller vite, un développeur renvoie directement l'entité `Utilisateur` depuis son contrôleur, et l'accepte telle quelle à la modification :

```java
@GetMapping("/{id}")
public Utilisateur lire(@PathVariable Long id) {
    return utilisateurRepository.findById(id).orElseThrow();
}

@PutMapping("/{id}")
public Utilisateur modifier(@PathVariable Long id, @RequestBody Utilisateur utilisateur) {
    return utilisateurRepository.save(utilisateur);
}
```

Plusieurs catastrophes se préparent :

- **Fuite de données** : le JSON renvoyé contient le mot de passe haché, la date de dernière connexion, et tout ce que l'entité possède.
- **Affectation de masse** : un apprenant envoie `{"prenom": "Emma", "role": "ADMIN"}` et devient administrateur.
- **Données invalides** : rien n'empêche un prénom vide, un e-mail sans `@` ou un prix négatif.
- **Couplage** : renommer une colonne de la table change le JSON, et le front casse.
- **Erreurs de sérialisation** : une relation bidirectionnelle (une formation connaît ses inscriptions, qui connaissent leur formation) produit une boucle infinie lors de la conversion en JSON.

Il faut séparer ce que l'API **échange** de ce que l'application **stocke**, et contrôler chaque donnée reçue avant de l'utiliser.

## Définitions

> **Entité.** Une classe qui représente une table de la base de données. Elle appartient à l'intérieur de l'application.

> **DTO (Data Transfer Object).** Un objet dont le seul rôle est de transporter des données entre deux couches ou deux systèmes. Il définit ce que l'API reçoit ou renvoie.

> **Contrat d'API.** La forme exacte des données échangées. Le front s'appuie dessus : il doit rester stable.

> **Affectation de masse (mass assignment).** Une faille où un client modifie des champs qu'il ne devrait pas pouvoir toucher, en les ajoutant à sa requête.

> **Jakarta Validation (Bean Validation).** La spécification Java de validation par annotations, implémentée par Hibernate Validator.

## Les DTO en entrée et en sortie

```text
Client                          API                                   Base
  │  FormationRequest (JSON)     │                                      │
  ├─────────────────────────────►│  validation                          │
  │                              │  FormationRequest → Formation ──────►│
  │                              │                                      │
  │  FormationResponse (JSON)    │  Formation → FormationResponse ◄─────┤
  │◄─────────────────────────────┤                                      │
```

| Objet | Contient | Exemple de champ absent |
|-------|----------|-------------------------|
| `FormationRequest` | Ce que le client a le **droit** d'envoyer | `id`, `createdAt` : fixés par le serveur |
| `Formation` (entité) | Tout ce qui est stocké | |
| `FormationResponse` | Ce que le client a **besoin** de voir | Le formateur responsable, si le client n'a pas à le connaître |

Chaque DTO est taillé pour son usage. On en crée souvent plusieurs pour une même entité : un DTO de création, un DTO de résumé pour les listes, un DTO de détail.

## Des records comme DTO

Les records sont parfaits pour les DTO : immuables, concis, avec leurs accesseurs, `equals` et `toString` générés.

```java
public record FormationRequest(

        @NotBlank(message = "Le titre est obligatoire")
        @Size(max = 150, message = "Le titre ne doit pas dépasser 150 caractères")
        String titre,

        @NotNull(message = "La durée est obligatoire")
        @Positive(message = "La durée doit être strictement positive")
        Integer dureeHeures,

        @NotNull(message = "Le prix est obligatoire")
        @DecimalMin(value = "0.0", message = "Le prix ne peut pas être négatif")
        BigDecimal prix,

        @NotNull(message = "La catégorie est obligatoire")
        Long categorieId
) {
}
```

```java
public record FormationResponse(Long id, String titre, int dureeHeures, BigDecimal prix, String categorie) {

    public static FormationResponse fromEntity(Formation formation) {
        return new FormationResponse(
                formation.getId(),
                formation.getTitre(),
                formation.getDureeHeures(),
                formation.getPrix(),
                formation.getCategorie().getNom());
    }
}
```

La méthode de fabrique statique `fromEntity` **centralise** la conversion : un seul endroit à modifier si la représentation change. Le champ `categorie` montre aussi qu'un DTO peut **aplatir** une relation : le client reçoit directement le nom de la catégorie, sans objet imbriqué.

Pour les projets plus grands, une bibliothèque comme **MapStruct** génère ces conversions à la compilation.

## La validation déclarative

Le starter `spring-boot-starter-validation` apporte Jakarta Validation. Les contraintes se déclarent par **annotations** sur les champs, et s'activent avec `@Valid` sur le paramètre du contrôleur.

| Annotation | Vérifie que... | Exemple |
|------------|----------------|---------|
| `@NotNull` | la valeur n'est pas `null` | Un identifiant de catégorie |
| `@NotBlank` | la chaîne n'est ni `null`, ni vide, ni faite d'espaces | Un titre |
| `@NotEmpty` | la chaîne ou la collection n'est ni `null` ni vide | Une liste de modules |
| `@Size(min, max)` | la longueur d'une chaîne ou la taille d'une collection est dans les bornes | Un titre de 150 caractères au plus |
| `@Min`, `@Max` | un entier est dans les bornes | Une note entre 0 et 20 |
| `@Positive`, `@PositiveOrZero` | un nombre est positif | Une durée |
| `@DecimalMin`, `@DecimalMax` | un décimal est dans les bornes | Un prix |
| `@Email` | la chaîne a la forme d'une adresse e-mail | Une adresse |
| `@Pattern(regexp)` | la chaîne respecte une expression régulière | Un code postal |
| `@Past`, `@Future` | une date est passée ou future | Une date de naissance |
| `@Valid` (sur un champ) | valide aussi l'objet imbriqué | Une liste d'options de quiz |

Si une contrainte échoue, Spring lève une `MethodArgumentNotValidException` et répond **400** avant même d'entrer dans la méthode du contrôleur. Le service ne reçoit jamais de données mal formées. Le cours suivant montre comment transformer cette exception en réponse claire, champ par champ.

### Le piège des types primitifs

Pour un nombre obligatoire, utilisez le type **enveloppe** (`Integer`) plutôt que le primitif (`int`). Un champ absent du JSON donnerait sinon silencieusement `0`, que `@NotNull` ne pourrait pas détecter : un `int` ne vaut jamais `null`.

```json
{"titre": "Docker", "prix": 450, "categorieId": 3}
```

Avec `int dureeHeures`, cette requête créerait une formation de 0 heure. Avec `Integer dureeHeures` et `@NotNull`, elle est refusée.

### Valider des objets imbriqués

```java
public record QuestionRequest(

        @NotBlank String enonce,

        @NotNull @Size(min = 2, message = "Une question doit comporter au moins deux options")
        @Valid
        List<OptionRequest> options
) {
}
```

Sans `@Valid` sur la liste, les contraintes de chaque `OptionRequest` seraient ignorées.

## Validation de format et règles métier

La validation par annotations vérifie la **forme** des données : présence, longueur, format, bornes. Elle ne sait rien de l'état de la base.

Les **règles métier**, qui dépendent de l'état de la base ou du contexte, se vérifient dans le **service** :

| Règle | Où la vérifier |
|-------|----------------|
| Le titre est obligatoire et fait 150 caractères au plus | Annotations du DTO |
| Le titre est unique | Service, en interrogeant la base |
| La catégorie indiquée existe | Service |
| La formation n'est pas complète | Service |
| Un formateur ne modifie que ses propres formations | Service |

```java
@Transactional
public FormationResponse creer(FormationRequest request) {
    if (formationRepository.existsByTitreIgnoreCase(request.titre())) {
        throw new DuplicateResourceException("Une formation porte déjà ce titre");
    }
    Categorie categorie = categorieRepository.findById(request.categorieId())
            .orElseThrow(() -> new ResourceNotFoundException("Catégorie", request.categorieId()));

    Formation formation = new Formation();
    formation.setTitre(request.titre().trim());
    formation.setDureeHeures(request.dureeHeures());
    formation.setPrix(request.prix());
    formation.setCategorie(categorie);

    return FormationResponse.fromEntity(formationRepository.save(formation));
}
```

Le service construit l'entité **champ par champ** à partir du DTO. Un champ `role` ou `id` ajouté par un client malveillant n'existe même pas dans `FormationRequest` : il est ignoré. L'affectation de masse est impossible.

Une contrainte `UNIQUE` en base reste indispensable en complément : deux requêtes simultanées pourraient passer la vérification du service en même temps.

## Une contrainte personnalisée

Une règle de format réutilisée à plusieurs endroits peut devenir une **annotation**. La forme la plus simple est une **contrainte composée**, qui réutilise des annotations existantes :

```java
@Documented
@Constraint(validatedBy = {})
@Pattern(regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[^A-Za-z0-9]).{10,}$",
        message = "Le mot de passe doit contenir au moins 10 caractères dont une majuscule, une minuscule, un chiffre et un caractère spécial")
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
public @interface MotDePasseRobuste {
    String message() default "Mot de passe trop faible";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
```

```java
public record InscriptionRequest(
        @NotBlank @Email String email,
        @NotBlank @MotDePasseRobuste String motDePasse
) {
}
```

La règle du mot de passe est écrite une fois et s'applique partout avec une annotation lisible. Pour une règle plus complexe, on écrit une classe qui implémente `ConstraintValidator`.

## Exemple complet

Création d'un apprenant, du JSON reçu à la réponse :

```java
public record ApprenantRequest(
        @NotBlank @Size(max = 50) String prenom,
        @NotBlank @Size(max = 50) String nom,
        @NotBlank @Email @Size(max = 100) String email
) {
}

public record ApprenantResponse(Long id, String nomComplet, String email) {

    public static ApprenantResponse fromEntity(Apprenant apprenant) {
        return new ApprenantResponse(
                apprenant.getId(),
                apprenant.getPrenom() + " " + apprenant.getNom(),
                apprenant.getEmail());
    }
}
```

```bash
curl -X POST http://localhost:8080/api/apprenants \
     -H "Content-Type: application/json" \
     -d '{"prenom": "", "nom": "Petit", "email": "pas-une-adresse", "role": "ADMIN"}'
```

- `prenom` vide et `email` invalide : réponse **400**, le service n'est jamais appelé.
- `role` : ignoré, il n'existe pas dans `ApprenantRequest`.
- En cas de succès, la réponse ne contient que `id`, `nomComplet` et `email`, jamais le mot de passe ni les champs techniques.

## Les erreurs fréquentes

- **Renvoyer une entité** depuis un contrôleur.
- **Recevoir une entité** en `@RequestBody`, et ouvrir la porte à l'affectation de masse.
- **Oublier `@Valid`**, et des annotations de validation qui ne servent à rien.
- **`int` au lieu de `Integer`** pour un champ obligatoire.
- **Vérifier l'unicité par annotation** : elle se vérifie dans le service, et par une contrainte en base.
- **Oublier `@Valid` sur une liste imbriquée.**

## Retour au besoin

L'API n'expose plus que ce qu'elle a choisi d'exposer : le mot de passe haché ne quitte jamais le serveur. Le client ne peut envoyer que les champs prévus par le DTO, et un rôle ajouté dans la requête est simplement ignoré. Les données mal formées sont refusées avant d'atteindre le service, et les règles métier sont vérifiées au bon endroit. Enfin, la structure de la base peut évoluer sans casser le contrat avec le front.

## À retenir

- Une API n'expose jamais ses entités : des DTO en entrée et en sortie, taillés pour chaque usage.
- Les records sont la forme idéale d'un DTO, avec une méthode `fromEntity` pour la conversion.
- `@Valid` déclenche la validation, et un échec répond 400 avant l'appel du service.
- `Integer` plutôt que `int` pour un nombre obligatoire.
- La forme se valide par annotations, les règles métier dans le service.

## Pour aller plus loin

- La validation dans la documentation de Spring Boot : [docs.spring.io/spring-boot/reference/io/validation.html](https://docs.spring.io/spring-boot/reference/io/validation.html)
- La liste des contraintes de Jakarta Validation : [jakarta.ee/specifications/bean-validation](https://jakarta.ee/specifications/bean-validation/)
