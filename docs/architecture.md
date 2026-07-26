# Architecture du prototype

## Objectif

L'architecture optimise d'abord la compréhension et la capacité à modifier une petite partie sans casser les autres. Elle n'anticipe pas une simulation complète de football.

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
| `referee.gd` | Lire les entrées et déplacer l'arbitre | Calculer la note |
| `incident_director.gd` | Ouvrir et fermer la fenêtre de décision | Afficher l'interface |
| `incident_data.gd` | Définir les données et libellés d'une situation | Piloter la partie |
| `evaluation_service.gd` | Produire un résultat déterministe | Modifier la scène |
| scripts UI | Présenter l'information et émettre les choix | Décider de ce qui est correct |

## Machine à états

```text
MENU PRINCIPAL
  ↓ partie solo
INTRO
  ↓
BUILDUP
  ↓
INCIDENT_WINDOW ── expiration ──┐
  ↓ coup de sifflet             │
DECISION                        │
  ↓ validation                  │
RESULTS ←───────────────────────┘
  ├─ rejouer → INTRO
  └─ menu → MENU PRINCIPAL
```

Une machine à états explicite évite de multiplier des booléens difficiles à combiner comme `is_started`, `is_paused`, `has_incident` et `showing_results`.

## Évolution attendue

Quand le prototype sera validé :

1. ajouter d'autres ressources `IncidentData` ;
2. extraire les actions scénarisées dans des ressources ou scènes dédiées ;
3. introduire un sélecteur de situations ;
4. ajouter des tests ciblés sur le scoring ;
5. seulement ensuite étudier une IA de match plus autonome.

## Choix volontairement absents

- autoload global ;
- bus d'événements global ;
- framework de dependency injection ;
- plugin de tests ;
- architecture ECS ;
- sauvegarde persistante ;
- réseau.

Ces outils peuvent être utiles, mais ajouteraient des concepts avant qu'un besoin du prototype ne les justifie.
