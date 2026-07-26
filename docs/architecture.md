# Architecture du prototype

## Objectif

L'architecture optimise d'abord la compréhension et la capacité à modifier une petite partie sans casser les autres. Elle prend en charge un match 11 contre 11 simplifié, des effectifs de 16 joueurs et un premier sous-ensemble des Lois du Jeu sans anticiper une simulation professionnelle.

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
| `player_profile.gd` | Conserver identité, statut d'effectif et sanctions | Déplacer le personnage |
| `demo_player.gd` | Déplacer un joueur et calculer sa cible selon son rôle | Choisir les reprises ou afficher l'UI |
| `team_tactics.gd` | Définir pressing, compacité, largeur et intention | Contrôler directement un joueur |
| `football_team.gd` | Gérer 16 profils, les joueurs en jeu et les remplacements | Décider des passes et des tirs |
| `match_simulation.gd` | Gérer possession, actions, score et rythme du match | Afficher le HUD ou définir les lois |
| `football_rules_engine.gd` | Détecter sorties, reprises et position de hors-jeu | Déplacer les joueurs ou noter l’arbitre |
| `referee.gd` | Lire les entrées et déplacer l'arbitre | Calculer la note |
| `positioning_model.gd` | Convertir la distance à l'action en qualité de vue et en temps de réaction | Dessiner une cible ou piloter les entrées |
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

Chaque équipe construit 16 `PlayerProfile`, puis instancie la même scène
`DemoPlayer` pour les onze titulaires d'un 4-3-3. Un profil reste une donnée :
le nœud représente uniquement le joueur actuellement présent sur le terrain.

La tactique fonctionne en deux étages :

1. `FootballTeam` publie le contexte commun : possession, ballon, porteur,
   joueur chargé du pressing et paramètres de `TeamTactics` ;
2. chaque `DemoPlayer` calcule sa propre cible selon son rôle, sa position de
   référence, sa fatigue et un léger biais individuel déterministe.

Les états `HOLD_SHAPE`, `SUPPORT`, `PRESS`, `CARRY` et `RECOVER` permettent de
lire immédiatement l'intention d'un joueur dans le débogueur.

`MatchSimulation` maintient une source de vérité unique pour :

- l’équipe en possession et le porteur ;
- le choix entre progression, passe et tir ;
- les interceptions et changements de possession ;
- le score et la demande de remise en jeu ;
- le déclenchement périodique d’incidents arbitrables.

`FootballRulesEngine` détermine séparément si le ballon est sorti, à quelle
équipe revient une touche, un corner ou un coup de pied de but et si le
destinataire d'une passe se trouvait en position de hors-jeu. Le périmètre exact
et ses limites sont documentés dans `docs/rules_scope.md`.

## Effectif et sanctions

`PlayerProfile.status` distingue titulaire, remplaçant, remplacé et exclu. La
feuille de match ne maintient donc aucune copie de cette information : elle lit
les profils et se reconstruit à chaque signal `roster_changed`.

```text
Décision disciplinaire
  → MatchSimulation
    → FootballTeam
      → PlayerProfile
        → roster_changed
          → RosterPanel
```

Un premier carton jaune reste attaché au profil. Un second jaune ou un rouge
retire le nœud correspondant de `FootballTeam.players` : l'équipe continue
réellement avec un joueur de moins.

## Placement de l'arbitre

`PositioningModel` mesure directement la distance entre l'arbitre et le ballon.
Jusqu'à environ 21 mètres, la vue est considérée nette. Au-delà, sa qualité
diminue progressivement jusqu'à considérer l'action comme perdue.

Pendant `PLAYING`, `Match` échantillonne cette proximité. La moyenne représente
la moitié des points de placement du rapport ;
l'autre moitié vient de la position exacte lors des contacts.

```text
Distance arbitre ↔ ballon
  → PositioningModel.proximity_quality
    ├─ MatchHud indique nette / correcte / lointaine / perdue
    └─ Match accumule la qualité dans le temps

Contact
  → position de l'arbitre mémorisée immédiatement
    → déplacements bloqués pendant l'observation
      ├─ fenêtre de décision raccourcie si la vue était mauvaise
      ├─ identité du fautif masquée à grande distance
      └─ marqueur de contact moins visible
```

Il n'existe aucun point précis à poursuivre : le joueur regarde le ballon et les
duels, puis choisit lui-même comment rester suffisamment proche.

## Évolution attendue

Quand le prototype sera validé :

1. ajouter d'autres ressources `IncidentData` ;
2. distinguer plusieurs familles de fautes produites par la simulation ;
3. rendre les reprises visibles avant que le jeu reparte ;
4. tester et calibrer les décisions de passes, tirs et pressing ;
5. ajouter les fenêtres de remplacement et les changements tactiques.

## Choix volontairement absents

- autoload global ;
- bus d'événements global ;
- framework de dependency injection ;
- plugin de tests ;
- architecture ECS ;
- sauvegarde persistante ;
- réseau.

Ces outils peuvent être utiles, mais ajouteraient des concepts avant qu'un besoin du prototype ne les justifie.
