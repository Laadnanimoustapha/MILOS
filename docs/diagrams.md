# Diagrammes UML - Systeme de l'etat civil

Ces diagrammes decrivent l'application actuelle: un tableau de bord pour les declarations de naissance et de deces, avec formulaires multi-etapes, pieces justificatives, recherche dans les archives et validation finale.

Format choisi: **Mermaid dans Markdown**. Il peut etre affiche dans GitHub, VS Code avec extension Mermaid, ou sur https://mermaid.live.

## 1. Diagramme de cas d'utilisation

```mermaid
flowchart LR
  agent["Agent d'etat civil"]
  declarant["Declarant / Citoyen"]

  subgraph systeme["Systeme de gestion de l'etat civil"]
    UC01([Ouvrir le tableau de bord])
    UC02([Gerer les declarations de naissance])
    UC03([Enregistrer une naissance])
    UC04([Consulter les declarations de naissance])
    UC05([Valider les declarations de naissance])
    UC06([Gerer les donnees marginales de naissance])

    UC07([Gerer les declarations de deces])
    UC08([Enregistrer un deces])
    UC09([Rechercher et consulter les deces])
    UC10([Valider les declarations de deces])
    UC11([Comparer les informations de deces])
    UC12([Gerer les donnees marginales de deces])

    UC13([Saisir les informations du declarant])
    UC14([Saisir les donnees de la personne])
    UC15([Rechercher dans les archives])
    UC16([Ajouter des pieces justificatives])
    UC17([Verifier la synthese])
    UC18([Confirmer et envoyer])
    UC19([Consulter les notifications])
  end

  agent --> UC01
  agent --> UC02
  agent --> UC07
  agent --> UC04
  agent --> UC05
  agent --> UC09
  agent --> UC10
  agent --> UC11
  agent --> UC06
  agent --> UC12
  agent --> UC19

  declarant --> UC13
  declarant --> UC16

  UC02 --> UC03
  UC02 --> UC04
  UC02 --> UC05
  UC02 --> UC19
  UC07 --> UC08
  UC07 --> UC09
  UC07 --> UC10
  UC07 --> UC11
  UC07 --> UC19

  UC03 -. include .-> UC13
  UC03 -. include .-> UC14
  UC03 -. include .-> UC15
  UC03 -. include .-> UC16
  UC03 -. include .-> UC17
  UC03 -. include .-> UC18

  UC08 -. include .-> UC13
  UC08 -. include .-> UC14
  UC08 -. include .-> UC15
  UC08 -. include .-> UC16
  UC08 -. include .-> UC17
  UC08 -. include .-> UC18

  classDef actor fill:#ffffff,stroke:#0A4D3C,stroke-width:2px,color:#0A4D3C;
  classDef usecase fill:#FAF8F2,stroke:#D4AF37,stroke-width:1px,color:#1A1A1A;
  class agent,declarant actor;
  class UC01,UC02,UC03,UC04,UC05,UC06,UC07,UC08,UC09,UC10,UC11,UC12,UC13,UC14,UC15,UC16,UC17,UC18,UC19 usecase;
```

## 2. Diagramme de classes

```mermaid
classDiagram
  direction LR

  class AgentEtatCivil {
    +String id
    +String nom
    +String role
    +ouvrirModule()
    +saisirDeclaration()
    +validerDeclaration()
  }

  class Declarant {
    +String nom
    +String cin
    +String relation
    +fournirInformations()
    +fournirPieces()
  }

  class Declaration {
    <<abstract>>
    +String id
    +String numero
    +String typeDeclaration
    +Date dateDeclaration
    +String statut
    +passerEtape()
    +revenirEtape()
    +genererSynthese()
    +confirmer()
  }

  class DeclarationNaissance {
    +Date dateNaissance
    +String lieuNaissance
    +String sexe
    +Boolean jourInconnu
    +ajouterJumeau()
  }

  class DeclarationDeces {
    +String numeroCertificat
    +Date dateDeces
    +String lieuDeces
    +String causeDeces
    +Boolean identiteInconnue
    +comparerInformations()
  }

  class Personne {
    +String prenom
    +String nom
    +String cin
    +Date dateNaissance
    +String adresse
    +Boolean inconnue
  }

  class Enfant {
    +String sexe
    +String lieuNaissance
  }

  class Defunt {
    +Date dateDeces
    +String lieuDeces
  }

  class Parent {
    +String profession
    +String lien
  }

  class BureauEtatCivil {
    +String id
    +String nom
    +String commune
  }

  class RechercheArchive {
    +String anneeInscription
    +String numeroActe
    +rechercher()
    +ajouterResultat()
  }

  class PieceJustificative {
    +String id
    +String typeDocument
    +String nomFichier
    +String etatScan
    +televerser()
    +supprimer()
  }

  class EtapeFormulaire {
    +Integer ordre
    +String libelle
    +String etat
    +activer()
    +marquerComplete()
  }

  class ControleDeclaration {
    +String decision
    +String commentaire
    +verifier()
    +approuver()
    +rejeter()
  }

  class DonneeMarginale {
    +String type
    +Date dateEvenement
    +String description
    +enregistrer()
  }

  AgentEtatCivil --> Declaration : cree / consulte
  Declarant --> Declaration : fournit
  Declaration <|-- DeclarationNaissance
  Declaration <|-- DeclarationDeces
  Personne <|-- Enfant
  Personne <|-- Defunt
  Personne <|-- Parent

  Declaration "1" o-- "1" Declarant
  Declaration "1" o-- "0..*" PieceJustificative
  Declaration "1" o-- "1..*" EtapeFormulaire
  Declaration "0..*" --> "1" BureauEtatCivil
  Declaration "0..*" --> ControleDeclaration
  Declaration "0..*" --> DonneeMarginale

  DeclarationNaissance "1" o-- "1..*" Enfant : nouveau-ne
  DeclarationNaissance "1" o-- "0..2" Parent : parents
  DeclarationDeces "1" o-- "1" Defunt : personne decedee
  DeclarationDeces "1" o-- "0..2" Parent : filiation

  RechercheArchive --> BureauEtatCivil : filtre par
  RechercheArchive --> Personne : retrouve
```

## 3. Diagramme de flux / activite

```mermaid
flowchart TD
  start([Debut])
  home[Ouvrir index.html]
  choose{Choisir un module}

  birth[Ouvrir le formulaire naissance]
  death[Ouvrir le formulaire deces]

  b1[Naissance - informations generales]
  b2[Naissance - informations de la mere]
  b3[Naissance - informations du pere]
  b4[Naissance - informations du nouveau-ne]
  b5[Naissance - pieces justificatives]
  b6[Naissance - synthese et confirmation]

  d1[Deces - donnees du certificat]
  d2[Deces - donnees du defunt]
  d3[Deces - donnees du pere]
  d4[Deces - donnees de la mere]
  d5[Deces - informations generales]
  d6[Deces - pieces justificatives]
  d7[Deces - synthese et confirmation]

  unknownBirth{Pere inconnu ?}
  disableBirth[Desactiver les champs du pere]
  archiveBirth{Recherche archive naissance ?}
  archiveSearchBirth[Saisir bureau, annee et numero d'acte]
  docsBirth[Choisir type de document et fichier]
  galleryBirth[Afficher la galerie des documents]

  unknownDeath{Defunt ou parent inconnu ?}
  disableDeath[Desactiver les champs concernes]
  archiveDeath{Recherche archive deces ?}
  archiveSearchDeath[Saisir bureau, annee et numero d'acte]
  docsDeath[Choisir type de document et fichier]
  galleryDeath[Afficher la galerie des documents]

  review[Verifier les donnees dans la synthese]
  valid{Donnees correctes ?}
  correction[Retourner a l'etape precedente et corriger]
  submit[Confirmer et envoyer la declaration]
  endNode([Fin])

  start --> home --> choose
  choose -- Naissance --> birth --> b1 --> b2 --> b3 --> unknownBirth
  unknownBirth -- Oui --> disableBirth --> b4
  unknownBirth -- Non --> b4
  b4 --> archiveBirth
  archiveBirth -- Oui --> archiveSearchBirth --> b5
  archiveBirth -- Non --> b5
  b5 --> docsBirth --> galleryBirth --> b6 --> review

  choose -- Deces --> death --> d1 --> d2 --> unknownDeath
  unknownDeath -- Oui --> disableDeath --> d3
  unknownDeath -- Non --> d3
  d3 --> d4 --> d5 --> archiveDeath
  archiveDeath -- Oui --> archiveSearchDeath --> d6
  archiveDeath -- Non --> d6
  d6 --> docsDeath --> galleryDeath --> d7 --> review

  review --> valid
  valid -- Non --> correction --> review
  valid -- Oui --> submit --> endNode
```

## Notes

- Le diagramme de flux est un **diagramme d'activite**: il represente le parcours utilisateur et les decisions principales.
- Le diagramme de classes est conceptuel: le projet actuel est en HTML/CSS/JS statique, donc les classes representent le modele metier attendu plutot que des classes JavaScript existantes.
