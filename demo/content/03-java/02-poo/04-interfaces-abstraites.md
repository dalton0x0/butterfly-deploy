## Objectifs

- Comprendre le problème du couplage à une implémentation précise
- Définir un contrat avec une interface et l'implémenter
- Utiliser les méthodes par défaut
- Factoriser un comportement commun avec une classe abstraite
- Choisir entre interface et classe abstraite
- Concevoir des interfaces ciblées

## Le besoin

La plateforme envoie une notification à chaque inscription. Première version :

```java
public class ServiceInscription {

    private final EnvoiEmail envoiEmail = new EnvoiEmail();

    public void inscrire(String email) {
        // ... enregistrement de l'inscription
        envoiEmail.envoyer(email, "Bienvenue !");
    }
}
```

Trois demandes arrivent :

- le client veut aussi pouvoir envoyer des **SMS**, et plus tard des notifications dans l'application ;
- en **développement**, on ne veut envoyer aucun vrai message ;
- pour les **tests automatisés**, on veut vérifier qu'une notification est bien demandée, sans envoyer d'e-mail.

Avec ce code, chaque demande oblige à **modifier** `ServiceInscription`, qui est soudé à une classe précise. Il faudrait que le service sache seulement qu'il dispose de « quelque chose qui sait notifier », sans savoir **comment**. C'est exactement ce qu'exprime une interface.

## Définitions

> **Interface.** Un contrat qui décrit ce qu'un objet sait faire, sous forme de signatures de méthodes, sans dire comment il le fait.

> **Implémentation.** Une classe qui s'engage à respecter une interface, avec `implements`, en fournissant le code de chacune de ses méthodes.

> **Classe abstraite.** Une classe qui ne peut pas être instanciée. Elle sert de base commune à des sous-classes et peut contenir à la fois du code complet et des méthodes abstraites.

> **Méthode abstraite.** Une méthode déclarée sans corps, que les sous-classes doivent obligatoirement implémenter.

> **Couplage.** Le degré de dépendance entre deux classes. Un couplage faible permet de modifier l'une sans toucher à l'autre.

## Les interfaces

```java
public interface Notification {

    void notifier(String destinataire, String message);
}
```

Une interface ne contient que des **signatures** : le nom, les paramètres et le type de retour. Ses méthodes sont implicitement `public` et abstraites.

```java
public class NotificationEmail implements Notification {

    @Override
    public void notifier(String destinataire, String message) {
        System.out.println("E-mail à " + destinataire + " : " + message);
    }
}

public class NotificationSms implements Notification {

    @Override
    public void notifier(String destinataire, String message) {
        System.out.println("SMS à " + destinataire + " : " + message);
    }
}
```

Le service ne dépend plus que du **contrat**, et reçoit l'implémentation de l'extérieur :

```java
public class ServiceInscription {

    private final Notification notification;

    public ServiceInscription(Notification notification) {
        this.notification = notification;
    }

    public void inscrire(String email) {
        // ... enregistrement
        notification.notifier(email, "Bienvenue !");
    }
}
```

```java
ServiceInscription enProduction = new ServiceInscription(new NotificationEmail());
ServiceInscription parSms = new ServiceInscription(new NotificationSms());
```

Le même service fonctionne avec n'importe quelle implémentation, **sans aucune modification**. C'est exactement ce que fait Spring avec l'**injection de dépendances** : un service reçoit ses collaborateurs par son constructeur et ne connaît que leur interface. C'est le principe d'inversion des dépendances, le D de SOLID.

## Tester grâce aux interfaces

Pour un test, on écrit une implémentation factice qui se contente de mémoriser les appels :

```java
public class NotificationFactice implements Notification {

    private final List<String> destinataires = new ArrayList<>();

    @Override
    public void notifier(String destinataire, String message) {
        destinataires.add(destinataire);
    }

    public List<String> getDestinataires() {
        return destinataires;
    }
}
```

```java
NotificationFactice factice = new NotificationFactice();
ServiceInscription service = new ServiceInscription(factice);

service.inscrire("emma@exemple.fr");

System.out.println(factice.getDestinataires());   // [emma@exemple.fr]
```

Aucun e-mail n'est envoyé, et l'on vérifie pourtant que le service a bien demandé une notification.

## Plusieurs interfaces

Une classe peut implémenter **plusieurs** interfaces, contrairement à l'héritage qui est limité à un parent. Chaque interface décrit une **capacité** :

```java
public class Video implements Notable, Telechargeable {
    // ...
}
```

Une interface est aussi un **type** : on peut déclarer une variable, un paramètre ou une liste de type `Notification`.

## Les méthodes par défaut

Depuis Java 8, une interface peut fournir une implémentation par défaut avec le mot-clé `default`. Toutes les classes qui l'implémentent en profitent, et peuvent la redéfinir.

```java
public interface Notification {

    void notifier(String destinataire, String message);

    default void notifierUrgent(String destinataire, String message) {
        notifier(destinataire, "[URGENT] " + message);
    }
}
```

Leur usage premier est de faire **évoluer** une interface sans casser les classes qui l'implémentent déjà : ajouter une méthode abstraite obligerait à modifier toutes les implémentations existantes.

## Les classes abstraites

Une classe **abstraite** ne peut pas être instanciée. Elle sert de base commune à des sous-classes proches, qui partagent du **code** et un **état**.

```java
public abstract class Contenu {

    private final String titre;

    protected Contenu(String titre) {
        this.titre = titre;
    }

    public String getTitre() {
        return titre;
    }

    public abstract int dureeEstimeeMinutes();

    public String resume() {
        return titre + " (" + dureeEstimeeMinutes() + " min)";
    }
}

public class Cours extends Contenu {

    private final int nombreSections;

    public Cours(String titre, int nombreSections) {
        super(titre);
        this.nombreSections = nombreSections;
    }

    @Override
    public int dureeEstimeeMinutes() {
        return nombreSections * 10;
    }
}

public class Video extends Contenu {

    private final int dureeSecondes;

    public Video(String titre, int dureeSecondes) {
        super(titre);
        this.dureeSecondes = dureeSecondes;
    }

    @Override
    public int dureeEstimeeMinutes() {
        return (dureeSecondes + 59) / 60;   // arrondi à la minute supérieure
    }
}
```

```java
new Contenu("Test");            // erreur de compilation : Contenu is abstract

Contenu cours = new Cours("Les collections", 4);
System.out.println(cours.resume());   // Les collections (40 min)
```

La méthode `resume` est écrite **une seule fois** dans le parent, et s'appuie sur `dureeEstimeeMinutes`, propre à chaque sous-classe. Ce schéma, où le parent définit la structure d'un traitement et les enfants en complètent une étape, s'appelle le **patron de méthode** (template method).

## Interface ou classe abstraite ?

| Critère | Interface | Classe abstraite |
|---------|-----------|------------------|
| Instanciable | Non | Non |
| État (attributs d'instance) | Non, seulement des constantes | Oui |
| Constructeur | Non | Oui |
| Code complet | Méthodes `default` et `static` | Oui, librement |
| Héritage multiple | Une classe peut en implémenter plusieurs | Un seul parent |
| Relation exprimée | « sait faire » (une capacité) | « est un » (une famille) |

En pratique, on commence par une **interface**. On ajoute une classe abstraite quand plusieurs implémentations partagent **réellement** du code et un état. Les deux se combinent souvent : une interface pour le contrat, une classe abstraite qui l'implémente partiellement pour factoriser le code commun.

## Des interfaces ciblées

Une interface trop large oblige certaines classes à implémenter des méthodes dont elles n'ont pas besoin :

```java
// Trop large
public interface Contenu {
    int duree();
    double noteMoyenne();          // un quiz n'a pas d'avis
    byte[] telechargerPdf();       // une vidéo ne se télécharge pas en PDF
}

public class Quiz implements Contenu {
    @Override
    public double noteMoyenne() {
        throw new UnsupportedOperationException();   // signal d'une mauvaise conception
    }
    // ...
}
```

C'est le principe de ségrégation des interfaces, le I de SOLID : préférez plusieurs petits contrats cohérents (`AvecDuree`, `Notable`, `Telechargeable`), et chaque classe implémente ceux qui la concernent. Une interface d'**une seule méthode** est parfaitement légitime.

Attention à l'excès inverse : créer une interface pour chaque classe « au cas où » n'apporte rien. Une abstraction se justifie par un **besoin réel** de variation, de remplacement ou de test.

## Exemple complet

Un calcul de réductions applicable à n'importe quelle formation, extensible sans modification :

```java
public interface Reduction {

    double appliquer(double prix);
}

public class ReductionPourcentage implements Reduction {

    private final double pourcentage;

    public ReductionPourcentage(double pourcentage) {
        this.pourcentage = pourcentage;
    }

    @Override
    public double appliquer(double prix) {
        return prix * (1 - pourcentage / 100);
    }
}

public class ReductionMontant implements Reduction {

    private final double montant;

    public ReductionMontant(double montant) {
        this.montant = montant;
    }

    @Override
    public double appliquer(double prix) {
        return Math.max(0, prix - montant);
    }
}

public class Caisse {

    public double prixFinal(double prix, List<Reduction> reductions) {
        double resultat = prix;
        for (Reduction reduction : reductions) {
            resultat = reduction.appliquer(resultat);
        }
        return resultat;
    }
}
```

```java
Caisse caisse = new Caisse();
double prix = caisse.prixFinal(1000, List.of(
        new ReductionPourcentage(10),   // 1000 → 900
        new ReductionMontant(50)        // 900 → 850
));
System.out.println(prix);   // 850.0
```

Une nouvelle réduction, comme un parrainage, s'ajoute en créant une classe. `Caisse` ne change jamais.

## Les erreurs fréquentes

- **Dépendre d'une classe concrète** (`new EnvoiEmail()` dans le service) au lieu d'une interface reçue par le constructeur.
- **Une interface fourre-tout**, et des implémentations qui lèvent `UnsupportedOperationException`.
- **Une interface par classe par anticipation**, sans besoin réel.
- **Une classe abstraite sans aucun code commun** : une interface suffisait.

## Retour au besoin

`ServiceInscription` ne connaît plus que le contrat `Notification`. L'e-mail, le SMS, une implémentation silencieuse pour le développement ou factice pour les tests se branchent sans modifier une seule ligne du service. Les classes abstraites complètent l'outil quand plusieurs implémentations partagent réellement du code. Ce principe de dépendre d'abstractions est au cœur de Spring, que vous aborderez dans le bloc Spring Boot.

## À retenir

- Une interface définit un contrat, une classe peut en implémenter plusieurs.
- Dépendre d'une interface reçue par le constructeur rend le code facile à faire évoluer et à tester.
- Une classe abstraite partage du code et un état entre des sous-classes proches.
- On commence par une interface, et on n'ajoute une abstraction que pour un besoin réel.
- Plusieurs petites interfaces ciblées valent mieux qu'une interface fourre-tout.

## Pour aller plus loin

- Le tutoriel officiel sur les interfaces : [dev.java/learn/interfaces](https://dev.java/learn/interfaces/)
