## Contexte

Un organisme de formation vous confie sa base de données. Avant de construire des rapports, vous devez savoir l'interroger.

## Préparation

Exécutez ce script dans une base MySQL vide :

```sql
CREATE TABLE categories (id BIGINT PRIMARY KEY, nom VARCHAR(50) NOT NULL);
CREATE TABLE formations (
    id BIGINT PRIMARY KEY, categorie_id BIGINT NOT NULL, titre VARCHAR(150) NOT NULL,
    duree_heures INT NOT NULL, prix DECIMAL(8,2) NOT NULL,
    FOREIGN KEY (categorie_id) REFERENCES categories (id)
);
CREATE TABLE apprenants (
    id BIGINT PRIMARY KEY, prenom VARCHAR(50) NOT NULL, nom VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE, ville VARCHAR(50)
);
CREATE TABLE inscriptions (
    apprenant_id BIGINT NOT NULL, formation_id BIGINT NOT NULL, inscrit_le DATE NOT NULL,
    note_finale DECIMAL(4,2),
    PRIMARY KEY (apprenant_id, formation_id),
    FOREIGN KEY (apprenant_id) REFERENCES apprenants (id),
    FOREIGN KEY (formation_id) REFERENCES formations (id)
);

INSERT INTO categories VALUES (1, 'Développement'), (2, 'Données'), (3, 'Infrastructure');
INSERT INTO formations VALUES
    (1, 1, 'Java', 70, 1200.00), (2, 1, 'PHP', 60, 950.00), (3, 1, 'Spring Boot', 50, 1100.00),
    (4, 2, 'SQL', 35, 600.00), (5, 2, 'Analyse de données', 40, 800.00),
    (6, 3, 'Docker', 21, 450.00), (7, 3, 'Linux', 28, 400.00), (8, 3, 'Kubernetes', 35, 900.00);
INSERT INTO apprenants VALUES
    (1, 'Emma', 'Petit', 'emma.petit@exemple.fr', 'Paris'),
    (2, 'Lucas', 'Bernard', 'lucas.bernard@exemple.fr', 'Lyon'),
    (3, 'Nina', 'Robert', 'nina.robert@exemple.fr', 'Paris'),
    (4, 'Hugo', 'Richard', 'hugo.richard@exemple.fr', NULL),
    (5, 'Léa', 'Durand', 'lea.durand@exemple.fr', 'Nantes'),
    (6, 'Tom', 'Moreau', 'tom.moreau@exemple.fr', 'Lyon');
INSERT INTO inscriptions VALUES
    (1, 1, '2026-01-10', 16.50), (1, 4, '2026-01-10', 14.00), (1, 3, '2026-03-02', NULL),
    (2, 1, '2026-01-12', 9.50), (2, 2, '2026-02-01', 12.00),
    (3, 4, '2026-01-15', 17.50), (3, 5, '2026-02-20', 15.00), (3, 6, '2026-03-05', NULL),
    (4, 7, '2026-02-11', 8.00),
    (5, 2, '2026-01-20', 13.00), (5, 4, '2026-01-20', 11.00);
```

## Requêtes à écrire

1. Les formations de moins de 1 000 €, de la moins chère à la plus chère.
2. Les apprenants dont la ville n'est pas renseignée.
3. Les formations dont le titre contient « donn », sans tenir compte de la casse.
4. Le titre de chaque formation avec le nom de sa catégorie.
5. Pour chaque inscription : prénom et nom de l'apprenant, titre de la formation et note finale, triés par nom.
6. Les apprenants parisiens avec les titres des formations qu'ils suivent.
7. Les inscriptions pas encore notées, avec le prénom de l'apprenant et le titre de la formation.
8. Les apprenants inscrits à aucune formation.
9. Les formations qui n'ont aucun inscrit.
10. Tous les apprenants avec, le cas échéant, leurs formations obtenues avec une note d'au moins 12. Un apprenant sans formation réussie doit apparaître quand même.

## Livrable

Déposez un fichier `requetes.txt` contenant chaque requête précédée d'un commentaire `-- Question n`, suivie en commentaire du nombre de lignes obtenues.

## Critères d'évaluation

| Critère | Points |
|---------|--------|
| Questions 1 à 3 : filtres et tris | 4 |
| Questions 4 à 7 : jointures internes | 6 |
| Questions 8 et 9 : lignes sans correspondance | 5 |
| Question 10 : condition dans le `ON` du `LEFT JOIN` | 3 |
| Lisibilité des requêtes (alias, indentation) | 2 |
