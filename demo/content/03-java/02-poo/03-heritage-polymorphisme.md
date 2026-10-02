## Objectifs

- Comprendre le problème de la duplication entre classes proches
- Créer une sous-classe avec `extends` et appeler le parent avec `super`
- Redéfinir une méthode avec `@Override`
- Comprendre le polymorphisme et ce qu'il apporte
- Respecter le principe de substitution de Liskov
- Choisir entre héritage et composition

## Le besoin

La plateforme gère trois sortes d'utilisateurs : des apprenants, des formateurs et des administrateurs. Première version :

```java
public class Apprenant {
    private String email;
    private String motDePasse;
    public boolean verifierMotDePasse(String saisie) { ... }
    public String description() { return "Apprenant " + email; }
}

public class Formateur {
    private String email;
    private String motDePasse;
    public boolean verifierMotDePasse(String saisie) { ... }   // copié-collé
    public String description() { return "Formateur " + email; }
}
```

Deux problèmes :

- **La duplication.** L'e-mail, le mot de passe et sa vérification sont copiés dans chaque classe. Une faille corrigée dans l'une restera dans les autres.
- **Le traitement commun.** Pour afficher la liste de tous les utilisateurs, il faut une boucle pour les apprenants, une pour les formateurs, une pour les administrateurs. Et en ajouter une à chaque nouveau type.

Ces trois classes ont une partie **commune** (ce sont tous des utilisateurs) et une partie **spécifique**. L'héritage permet d'écrire la partie commune une seule fois. Le polymorphisme permet de les traiter toutes de la même façon.

## Définitions

> **Héritage.** Un mécanisme par lequel une classe (la sous-classe, ou classe fille) reprend les attributs et méthodes d'une autre (la super-classe, ou classe parente) et peut les spécialiser.

> **Relation « est un ».** L'héritage modélise une relation où la sous-classe est un cas particulier du parent : un formateur **est un** utilisateur.

> **Redéfinition (override).** Le fait, pour une sous-classe, de fournir sa propre version d'une méthode héritée.

> **Polymorphisme.** La capacité à manipuler des objets de types différents à travers un type commun, chaque objet réagissant selon son type réel.

> **Composition.** Le fait qu'un objet contienne d'autres objets et leur délègue une partie du travail. Elle modélise une relation « a un ».

## L'héritage avec extends

```java
public class Utilisateur {

    protected final String email;

    public Utilisateur(String email) {
        this.email = email;
    }

    public String description() {
        return "Utilisateur " + email;
    }
}

public class Formateur extends Utilisateur {

    private final String specialite;

    public Formateur(String email, String specialite) {
        super(email);
        this.specialite = specialite;
    }

    @Override
    public String description() {
        return "Formateur " + email + " spécialisé en " + specialite;
    }

    public String getSpecialite() {
        return specialite;
    }
}
```

Ce que `Formateur` obtient :

| Élément | Origine |
|---------|---------|
| `email` | Hérité de `Utilisateur` |
| `description()` | Hérité, puis **redéfini** |
| `specialite`, `getSpecialite()` | Propre à `Formateur` |

Points clés :

- `extends Utilisateur` déclare l'héritage.
- `super(email)` appelle le constructeur du parent. Il doit être la **première instruction** du constructeur : le parent est construit avant l'enfant.
- `protected` rend `email` accessible aux sous-classes, tout en le cachant au reste du programme.
- Java n'autorise qu'**un seul parent** par classe.
- Toute classe hérite, directement ou non, de `Object`. C'est de là que viennent `toString`, `equals` et `hashCode`.

## Redéfinir une méthode avec @Override

L'annotation `@Override` demande au compilateur de vérifier qu'on redéfinit bien une méthode **existante** du parent.

```java
@Override
public String descritpion() {    // faute de frappe
    return "Formateur " + email;
}
```

```text
error: method does not override or implement a method from a supertype
```

Sans l'annotation, le code compilerait : on aurait simplement créé une **nouvelle** méthode `descritpion`, et `description()` continuerait d'afficher le texte du parent. Un bug silencieux devient une erreur de compilation.

Une redéfinition peut aussi **compléter** le comportement du parent plutôt que le remplacer, avec `super.methode()` :

```java
@Override
public String description() {
    return super.description() + " (formateur)";
}
```

## Le polymorphisme

Une variable d'un **type parent** peut désigner un objet de n'importe quelle **sous-classe**. À l'exécution, c'est la méthode de l'**objet réel** qui est appelée.

```java
List<Utilisateur> utilisateurs = List.of(
        new Utilisateur("emma@exemple.fr"),
        new Formateur("sophie@exemple.fr", "Java"),
        new Administrateur("admin@exemple.fr")
);

for (Utilisateur utilisateur : utilisateurs) {
    System.out.println(utilisateur.description());
}
```

```text
Utilisateur emma@exemple.fr
Formateur sophie@exemple.fr spécialisé en Java
Administrateur admin@exemple.fr
```

Deux types entrent en jeu pour chaque variable :

| Type | Déterminé | Rôle |
|------|-----------|------|
| **Déclaré** : `Utilisateur` | À la compilation | Décide quelles méthodes on a le **droit** d'appeler |
| **Réel** : `Formateur` | À l'exécution | Décide **quelle version** de la méthode s'exécute |

```java
Utilisateur u = new Formateur("sophie@exemple.fr", "Java");
u.description();       // version de Formateur
u.getSpecialite();     // erreur de compilation : Utilisateur ne déclare pas cette méthode
```

La boucle ne connaît que `Utilisateur`. Ajouter demain une classe `Tuteur` ne demande **aucune modification** de cette boucle : c'est tout l'intérêt du polymorphisme. Le code est **ouvert à l'extension** (on ajoute des types) et **fermé à la modification** (on ne touche pas au code existant). C'est le principe ouvert-fermé, le O de SOLID.

## Le signal instanceof

Du code qui enchaîne les `instanceof` pour choisir un comportement est souvent le signe d'un polymorphisme manquant :

```java
// À éviter : chaque nouveau type impose de modifier ce code
String libelle;
if (utilisateur instanceof Formateur) {
    libelle = "Formateur";
} else if (utilisateur instanceof Administrateur) {
    libelle = "Administrateur";
} else {
    libelle = "Utilisateur";
}
```

Le comportement a sa place dans une méthode redéfinie par chaque sous-classe : `utilisateur.description()`. `instanceof` reste utile ponctuellement, par exemple à la frontière d'un système, mais il ne doit pas remplacer la conception.

## Le principe de substitution

Une sous-classe doit pouvoir **remplacer** son parent partout sans surprise. C'est le principe de substitution de Liskov, le L de SOLID. Elle peut spécialiser un comportement, mais pas **rompre le contrat** du parent.

Exemple classique d'héritage trompeur : `Carre extends Rectangle`. Mathématiquement, un carré est un rectangle. Mais si `Rectangle` propose `setLargeur` et `setHauteur` :

```java
void doublerLargeur(Rectangle r) {
    int hauteurAvant = r.getHauteur();
    r.setLargeur(r.getLargeur() * 2);
    // Un rectangle garde sa hauteur. Un carré, lui, a dû changer ses deux côtés :
    // le code qui croyait manipuler un rectangle obtient un résultat inattendu.
}
```

Autres signaux d'alerte : une méthode redéfinie qui lève systématiquement `UnsupportedOperationException`, ou qui refuse des valeurs que le parent acceptait. La relation « est un » du langage courant ne suffit pas : il faut que le **comportement** soit compatible.

## Héritage ou composition ?

L'héritage crée un **couplage fort** : une modification du parent se répercute sur tous les enfants, et l'on ne choisit qu'un seul parent. Quand la relation est plutôt « a un » que « est un », préférez la **composition** : la classe contient un objet et lui délègue le travail.

```java
// Composition : un bloc A des modules, il n'EST PAS un module
public class Bloc {

    private final List<Module> modules = new ArrayList<>();

    public void ajouterModule(Module module) {
        modules.add(module);
    }

    public int dureeTotale() {
        int total = 0;
        for (Module module : modules) {
            total += module.duree();
        }
        return total;
    }
}
```

| Question | Réponse | Outil |
|----------|---------|-------|
| Un formateur est-il un utilisateur ? | Oui, en tout point | Héritage |
| Un bloc est-il un module ? | Non, il **contient** des modules | Composition |
| Un service d'inscription est-il un service d'e-mail ? | Non, il **utilise** un service d'e-mail | Composition |

En cas de doute, la composition est souvent le choix le plus souple. On retrouvera ce principe avec l'injection de dépendances de Spring.

## Exemple complet

Un calcul de tarif selon le type d'abonnement, sans aucun `instanceof` :

```java
public class Abonnement {

    protected final double prixMensuel;

    public Abonnement(double prixMensuel) {
        this.prixMensuel = prixMensuel;
    }

    public double prixAnnuel() {
        return prixMensuel * 12;
    }
}

public class AbonnementEtudiant extends Abonnement {

    public AbonnementEtudiant(double prixMensuel) {
        super(prixMensuel);
    }

    @Override
    public double prixAnnuel() {
        return super.prixAnnuel() * 0.5;   // moitié prix
    }
}

public class AbonnementEntreprise extends Abonnement {

    private final int nombreLicences;

    public AbonnementEntreprise(double prixMensuel, int nombreLicences) {
        super(prixMensuel);
        this.nombreLicences = nombreLicences;
    }

    @Override
    public double prixAnnuel() {
        return prixMensuel * 10 * nombreLicences;   // deux mois offerts par licence
    }
}
```

```java
List<Abonnement> abonnements = List.of(
        new Abonnement(20),
        new AbonnementEtudiant(20),
        new AbonnementEntreprise(20, 5)
);

double chiffreAffaires = 0;
for (Abonnement abonnement : abonnements) {
    chiffreAffaires += abonnement.prixAnnuel();
}
System.out.println(chiffreAffaires);   // 240 + 120 + 1000 = 1360.0
```

## Les erreurs fréquentes

- **Hériter pour réutiliser du code** alors que la relation n'est pas « est un ».
- **Oublier `@Override`**, et une faute de frappe qui crée une nouvelle méthode.
- **Oublier `super(...)`** quand le parent n'a pas de constructeur sans paramètre : erreur de compilation.
- **Des cascades de `instanceof`** au lieu d'une méthode redéfinie.
- **Des hiérarchies profondes** sur cinq niveaux, impossibles à suivre.

## Retour au besoin

La vérification du mot de passe est désormais écrite une seule fois, dans `Utilisateur`, et tous les types d'utilisateurs en profitent. Une seule boucle traite toute la liste, et chaque objet s'affiche selon son type réel. Ajouter un nouveau type d'utilisateur ne demande de modifier aucune ligne existante. Et quand la relation n'est pas « est un », la composition offre la même réutilisation sans le couplage.

## À retenir

- `extends` crée une relation « est un », `super` appelle le parent.
- `@Override` fait vérifier la redéfinition par le compilateur.
- Le type déclaré décide ce qu'on peut appeler, le type réel décide quelle version s'exécute.
- Le polymorphisme évite les cascades de `instanceof` et permet d'ajouter des types sans modifier l'existant.
- Une sous-classe doit respecter le contrat de son parent, et en cas de doute la composition est plus souple que l'héritage.

## Pour aller plus loin

- Le tutoriel officiel sur l'héritage : [dev.java/learn/inheritance](https://dev.java/learn/inheritance/)
