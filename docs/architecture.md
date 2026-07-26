# Architecture du prototype

## Boucle active — perspective arbitre 3D

`core/app.gd` charge désormais
`gameplay/perspective/referee_perspective_match.tscn`. Cette tranche verticale
garde le match en mouvement jusqu'à une intervention volontaire du joueur :

```text
AVANT-MATCH
  └─ Espace : l'arbitre siffle lui-même le coup d'envoi
        ↓
MATCH CONTINU
  ├─ passes / tirs / buts / duels
  ├─ événement pertinent mémorisé, sans pause
  ├─ V : avantage, sans interrompre le jeu
  ├─ assistant lève son drapeau, sans pause
  ├─ 45′ : mi-temps, équipes figées et changement de camp
  └─ Espace : coup de sifflet volontaire
        ↓
ARRÊT DE JEU
  ├─ chronomètre, ballon et acteurs figés
  ├─ arbitre toujours mobile, caméra toujours active
  ├─ première décision : Faute ou Hors-jeu
  ├─ Faute : reprise, sanction et équipe bénéficiaire
  ├─ lieu du sifflet mémorisé et marqué au sol
  ├─ joueur au centre du viseur mis en évidence
  ├─ 3 demande une revue VAR
  └─ E identifie le joueur, Entrée confirme
        ↓
REPRISE ET MATCH CONTINU
  ├─ réaction émotionnelle de chaque équipe
  └─ difficulté ajustée à la tension
```

Le premier coup d'envoi et celui de la seconde période passent par
`_prepare_kickoff` puis `_take_prepared_kickoff`. Tous les joueurs sont replacés
dans leur propre moitié, sauf le botteur autorisé au centre, et les adversaires
sont repoussés hors du rayon de 9,15 m. Le ballon reste sur le point central
jusqu'au sifflet, puis une passe visible le met réellement en jeu.

## Intelligence collective et possession

`FootballTeamAI` fournit les calculs tactiques sans déplacer directement les
acteurs. Pour chaque passe possible, il mesure la longueur, la progression,
l'espace du receveur et surtout la distance des adversaires au segment de passe.
Le match choisit ensuite la meilleure solution avec une petite variation afin
d'éviter des séquences parfaitement répétitives. Le receveur attaque le point de
réception, prend un court temps de contrôle et peut être intercepté sur le
trajet si un défenseur coupe réellement la ligne.

`RefereePerspectiveMatch` joue le rôle de cerveau collectif. En possession,
trois joueurs proches créent une sortie courte, un appui avancé et une solution
de sécurité, tandis que les ailiers conservent la largeur et les attaquants
respectent la ligne de hors-jeu. Sans ballon, le défenseur le plus proche presse,
un second couvre et le reste de l'équipe resserre sa forme au lieu de courir
vers le porteur. Les rôles `GK`, `FB`, `CB`, `DM`, `CM`, `AM`, `W` et `ST`
modulent la profondeur, la largeur et la vitesse de replacement.

La conduite utilise un couloir choisi selon l'espace disponible plutôt qu'une
course rectiligne vers le but. Le ballon rejoint chaque touche par interpolation,
les joueurs accélèrent et tournent progressivement, et une séparation locale
évite qu'ils se superposent. Le HUD affiche la longueur de la séquence en cours,
ce qui rend immédiatement perceptibles les phases de contrôle.

À 45 minutes simulées, le match entre dans `HALF_TIME` : chronomètre et acteurs
s'arrêtent, les positions de référence sont reflétées, les directions d'attaque,
les surfaces défendues et les lignes de hors-jeu changent de côté. L'équipe qui
n'a pas donné le premier coup d'envoi attend le signal du joueur pour lancer la
seconde période.

La caméra est portée par `RefereeController3D`. Au coup de sifflet,
`PerspectiveObservationModel` mesure la distance, l'angle horizontal et une
occultation par lancer de rayon. Ces données expliquent les indices dont
l'arbitre disposait ; elles ne révèlent pas automatiquement la décision correcte.

`OfficiatingCatalog` sépare les données réglementaires de l'interface. Ses
familles conservent plus de 35 motifs pratiques pour les futures itérations,
mais le panneau actif n'en expose volontairement que deux familles.

`OfficiatingPanel` utilise une divulgation progressive. `1` choisit la faute et
ouvre deux rangées compactes : `4`/`5` pour coup franc ou penalty, puis `6` à
`9` pour aucune sanction, avertissement verbal, jaune ou rouge. `T` change
l'équipe bénéficiaire, `E` identifie le joueur visé et `Entrée` confirme. `2`
conserve le flux hors-jeu et `3` demande la VAR. Les choix sont également
cliquables lorsque le pointeur est libéré.

Le ballon au moment du sifflet définit `whistle_position`. Un anneau au sol
rend ce lieu visible durant l'inspection ; un coup franc replace le ballon et
le joueur de l'équipe choisie exactement à cet endroit. Un penalty utilise le
point réglementaire. L'avantage ne figure pas dans le menu après sifflet :
`V` le signale pendant le jeu, puis la simulation mémorise la décision sans
arrêter le chronomètre ni modifier la possession.

`FootballLaws3D` centralise les invariants géométriques de la simulation active :
dimensions du terrain, moitié défendue, direction d'attaque, distance au rond
central, surface de réparation et position de hors-jeu. Cette dernière compare
le receveur à la fois au ballon et à l'avant-dernier adversaire. Une frappe non
cadrée ne provoque plus un faux coup d'envoi : le gardien adverse obtient un
coup de pied de but dans sa zone, après éloignement des adversaires de la
surface. Les coups francs replacent également les adversaires à 9,15 m et un
penalty utilise désormais le point de penalty.

Pendant `STOPPED_FOR_DECISION`, les 22 joueurs, le ballon, les assistants et le
chronomètre sont figés, mais `RefereeController3D` conserve mouvement et regard.
Un rayon part du centre de la caméra ; le premier joueur touché reçoit un
marqueur jaune. `E` verrouille son identité et passe le marqueur au vert. La
comparaison interne vérifie désormais l'individu, pas seulement son équipe.

## Assistance VAR

La VAR reste un conseil et ne soumet jamais une décision à la place du joueur.
Deux chemins utilisent le même mécanisme :

- pendant un arrêt, `3` émet `var_review_requested` depuis
  `OfficiatingPanel` ;
- pendant le jeu, une action marquée `var_reviewable` déclenche automatiquement
  un appel après 2,4 secondes.

L'annonce indique l'équipe et le numéro du joueur à revoir. Celui-ci reçoit un
marqueur violet `VAR · REVUE`, visible lorsque l'arbitre revient vers l'action.
Une alerte VAR prolonge la mémoire de l'incident de six à dix secondes pour
laisser au joueur le temps de siffler. Le marqueur disparaît après la décision,
l'expiration de l'action ou la fin du match.

Le ballon possède un marqueur 3D visible à travers les acteurs. Le HUD complète
ce repère avec sa distance et une flèche gauche, droite ou arrière calculée
depuis l'orientation réelle de la caméra. Cette aide ne révèle aucun élément de
faute : elle facilite seulement le suivi du jeu.

`RefereeMinimap2D` projette les coordonnées X/Z du monde sur un terrain 2D
respectant les proportions 68 × 105. Elle redessine à 20 Hz les joueurs actifs,
le ballon et l'arbitre. Un cône translucide et une flèche utilisent le vecteur
avant horizontal de la caméra pour montrer l'orientation du regard. La carte
reste visible pendant un arrêt : elle aide donc à retrouver le joueur fautif
sans révéler la nature de l'incident.

Deux `AssistantReferee3D` suivent la ligne de hors-jeu le long des touches.
Lorsqu'une passe est détectée hors-jeu, l'assistant concerné lève son drapeau et
le HUD relaie le signal. La simulation continue : seul l'arbitre central décide
de siffler.

## Tension et importance du match

`MatchIntensityModel` contient six profils extensibles : amical, phase de
poules, qualificatif, élimination directe, finale et derby. Chaque profil fixe
une tension de départ, un multiplicateur de réaction et une vitesse de retour
au calme. Il ne modifie pas les règles : il modifie la pression humaine qui
entoure leur application.

Après chaque décision, le modèle compare en interne la famille choisie, la
reprise déduite et l'identité du joueur désigné à l'événement simulé. Le joueur
ne reçoit pas une note : le résultat visible est la réaction des Bleus et des
Rouges. Une équipe lésée s'énerve fortement ; une décision cohérente calme
l'équipe bénéficiaire, même si le fautif peut encore contester.

La tension maximale pilote trois effets immédiatement jouables :

- le tempo et la probabilité de perte de balle augmentent ;
- les duels arbitrables reviennent plus vite ;
- plusieurs joueurs de l'équipe mécontente quittent temporairement leur
  position pour entourer l'arbitre.

À 98 % de tension pendant sept secondes, le match est considéré comme
incontrôlable et peut être interrompu. Le rapport final présente les tensions
finales et maximales, jamais une note d'arbitrage.

Les acteurs, le terrain, les buts, le ballon et les drapeaux utilisent uniquement
des primitives 3D Godot. L'ancienne implémentation 2D reste dans le dépôt comme
référence d'apprentissage mais n'est plus chargée par le menu principal.

## Présentation 3D et balle hybride

Le terrain reste construit en code afin de ne dépendre d'aucun asset. Il assemble
une base et vingt bandes de tonte légèrement superposées, les marquages des zones
de but, surfaces de réparation, arcs de penalty et quarts de cercle de corner,
des buts avec filets maillés et des poteaux de corner. Les éléments décoratifs
n'ont pas de collision et ne perturbent donc pas la simulation arbitrale.

`StadiumCatalog` décrit trois clubs fictifs et leurs enceintes. Le menu choisit
l'équipe à domicile, puis transmet son identifiant au match avec l'importance de
la rencontre. Chaque profil définit le nom du stade, la ville, la capacité, les
couleurs du club, les teintes de pelouse et de tribunes, le ciel, le soleil et la
puissance des projecteurs. La même génération procédurale construit ensuite un
bowl à gradins, des rangées de sièges, une toiture, des bandeaux, quatre pylônes
et un écran d'identité : les enceintes restent cohérentes sans dupliquer de scène.

La caméra de l'arbitre est placée à 2,04 m et légèrement inclinée vers le terrain.
Ce gain de hauteur facilite la lecture du ballon et des lignes sans devenir une
vue aérienne ; la distance, l'angle et les occultations continuent donc de
limiter la preuve disponible.

`PerspectivePlayer3D` possède un petit rig procédural : quatre pivots de membres,
un torse et une racine visuelle. La vitesse pilote une oscillation opposée des
bras et jambes, un balancement du torse et un rebond vertical. La collision reste
une capsule unique, ce qui sépare clairement animation et logique de déplacement.

La balle utilise une physique hybride plutôt qu'un `RigidBody3D` autonome. La
possession et l'arrivée d'une passe restent déterministes pour préserver la
lisibilité du match, tandis que la présentation calcule :

- une parabole de hauteur variable selon le type de passe ou de frappe ;
- une déviation latérale sinusoïdale pour simuler l'effet ;
- une rotation proportionnelle à la distance parcourue ;
- un petit rebond lors de la conduite et une ombre projetée au sol.

Ce compromis évite qu'un rebond aléatoire casse le scénario d'arbitrage, tout en
donnant au ballon une masse et une trajectoire beaucoup plus crédibles.

## Architecture 2D historique

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
