# Architecture du prototype

## Objectif

L'architecture optimise d'abord la compréhension et la capacité à modifier une petite partie sans casser les autres. Elle prend en charge un match 11 contre 11 simplifié sans anticiper une simulation de football professionnelle.

## Les briques Godot utilisées

### Nœud

Un nœud possède une responsabilité dans l'arbre de scène. Par exemple, `Referee` gère le déplacement et `IncidentDirector` gère la durée de la fenêtre de décision.

### Scène

Une scène est un arbre de nœuds réutilisable. Le terrain, l'arbitre, les joueurs et chaque panneau d'interface sont des scènes séparées, assemblées par `match.tscn`.

### Script

Un script donne un comportement à un nœud. Les scripts ne recherchent pas arbitrairement des nœuds éloignés : le parent coordonne ses enfants ou écoute leurs signaux.

### Signal

Un signal annonce un événement sans imposer au composant qui l'émet de connaître le destinataire.

Exemple :

```text
Referee
  émet whistle_requested
        ↓
Match
  décide si un incident est actif
        ↓
DecisionPanel
  affiche les options
```

### Resource

`IncidentData` contient les données éditables d'une situation d'arbitrage. Le fichier `.tres` de SIT-001 peut être dupliqué plus tard sans recopier le code qui gère le temps ou le score.

## Responsabilités

| Élément | Responsabilité | Ne doit pas faire |
| --- | --- | --- |
| `app.gd` | Afficher le menu ou le match et gérer leur cycle de vie | Contenir la logique du match |
| `main_menu.gd` | Présenter le contexte et émettre les intentions du joueur | Charger directement la scène de match |
| `match.gd` | Orchestrer les phases et connecter les composants | Connaître les détails du dessin des acteurs |
| `football_team.gd` | Créer 11 joueurs, conserver leur rôle et déplacer le bloc | Décider des passes et des tirs |
| `match_simulation.gd` | Gérer possession, passes, pression, tirs, buts et fautes | Afficher le HUD ou noter l’arbitre |
| `referee.gd` | Lire les entrées et déplacer l'arbitre | Calculer la note |
| `incident_director.gd` | Ouvrir et fermer la fenêtre de décision | Afficher l'interface |
| `incident_data.gd` | Définir les données et libellés d'une situation | Piloter la partie |
| `evaluation_service.gd` | Produire un résultat déterministe | Modifier la scène |
| scripts UI | Présenter l'information et émettre les choix | Décider de ce qui est correct |

## Machine à états

```text
MENU PRINCIPAL
  ↓ partie solo
PRE_MATCH
  ↓
PLAYING ←─────────────────────────────┐
  ├─ passe / tir / but → PLAYING      │
  ├─ temps écoulé → RESULTS           │
  └─ faute → INCIDENT_WINDOW          │
                 ├─ expiration ─┐     │
                 └─ sifflet → DECISION
                                  ↓   │
                              FEEDBACK┘

RESULTS
  ├─ rejouer → PRE_MATCH
  └─ menu → MENU PRINCIPAL
```

Une machine à états explicite évite de multiplier des booléens difficiles à combiner comme `is_started`, `is_paused`, `has_incident` et `showing_results`.

## Simulation 11 contre 11

Chaque équipe instancie dynamiquement 11 fois la même scène de joueur puis lui
attribue un numéro, un rôle et une position de référence dans un 4-3-3.

`MatchSimulation` maintient une source de vérité unique pour :

- l’équipe en possession et le porteur ;
- les déplacements collectifs autour du ballon ;
- le choix entre progression, passe et tir ;
- le pressing du défenseur le plus proche ;
- les interceptions et changements de possession ;
- le score et les remises en jeu ;
- le déclenchement périodique d’incidents arbitrables.

Cette IA est une machine de simulation destinée au gameplay de l’arbitre. Elle
ne modélise pas encore la tactique individuelle, les statistiques des joueurs,
les hors-jeu, les coups de pied arrêtés détaillés ou la physique réelle du ballon.

## Évolution attendue

Quand le prototype sera validé :

1. ajouter d'autres ressources `IncidentData` ;
2. distinguer plusieurs familles de fautes produites par la simulation ;
3. ajouter hors-jeu, sorties de balle et coups de pied arrêtés ;
4. tester et calibrer les décisions de passes, tirs et pressing ;
5. introduire des profils de joueurs et des styles d’équipe si le gameplay le justifie.

## Choix volontairement absents

- autoload global ;
- bus d'événements global ;
- framework de dependency injection ;
- plugin de tests ;
- architecture ECS ;
- sauvegarde persistante ;
- réseau.

Ces outils peuvent être utiles, mais ajouteraient des concepts avant qu'un besoin du prototype ne les justifie.
