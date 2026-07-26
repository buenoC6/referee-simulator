# Parcours d'apprentissage

Le meilleur moyen d'apprendre ce projet est de faire de petites modifications visibles.

## Étape 0 — Le point d’entrée

Ouvre `core/app.tscn`, puis `core/app.gd`.

À retenir :

- `App` est la première scène chargée ;
- elle instancie soit le menu, soit le match ;
- le menu demande une partie avec un signal sans connaître le fichier du match ;
- cette séparation évite que les écrans deviennent dépendants les uns des autres.

## Étape 1 — Scènes et nœuds

Ouvre `match.tscn` et repère les instances de `FootballPitch`, `Referee`, `DemoPlayer`, `MatchBall` et les panneaux UI.

Exercice :

- change la position initiale d'un joueur ;
- lance la scène ;
- observe la différence ;
- annule puis recommence depuis l'inspecteur.

## Étape 2 — Variables exportées

Ouvre `referee.tscn`, sélectionne le nœud racine et trouve `Speed` dans l'inspecteur.

Exercice :

- passe la vitesse de 290 à 450 ;
- rejoue ;
- restaure une valeur qui te semble agréable.

## Étape 3 — Entrées et mouvement

Lis `_physics_process()` dans `referee.gd`.

À retenir :

- la physique évolue à intervalle fixe ;
- `Input.get_vector()` combine quatre actions ;
- `velocity` décrit le mouvement ;
- `move_and_slide()` applique ce mouvement.

## Étape 4 — Signaux

Cherche `whistle_requested`.

Exercice :

- ajoute un message dans la console lorsque le signal est reçu ;
- vérifie qu'il ne s'affiche qu'à la pression sur `Espace`.

## Étape 5 — Données

Ouvre `sit_001_reckless_tackle.tres` dans l'inspecteur.

Exercice :

- modifie la durée maximale de décision ;
- change la distance d'observation idéale ;
- constate que le comportement change sans modifier de script.

## Étape 6 — Logique testable

Lis `evaluation_service.gd`, puis `tests/smoke_test.gd`.

Exercice :

- change temporairement le poids de la discipline ;
- adapte le test ;
- lance le test en mode headless ;
- restaure les valeurs documentées.

## Étape 7 — Première extension

Duplique la ressource SIT-001 pour préparer SIT-002. Ne l'intègre pas immédiatement au match : commence par écrire la vérité de la situation, les choix corrects et le feedback.

## Étape 8 — Comprendre les équipes et l’IA

Ouvre `football_team.gd`, puis `match_simulation.gd`.

Observe la séparation :

- `PlayerProfile` contient l'identité, le statut et les cartons ;
- `TeamTactics` contient les consignes communes ;
- chaque joueur calcule sa cible à partir de son rôle et de ces consignes ;
- l’équipe sait quels profils elle possède et quels joueurs sont sur le terrain ;
- la simulation sait qui possède le ballon et choisit la prochaine action ;
- le moteur de règles décide des reprises et du hors-jeu ;
- le match orchestre l’arbitrage, sans décider des passes.

Exercice :

- modifie une position du tableau 4-3-3 ;
- change l’intervalle des incidents ;
- augmente légèrement la probabilité de but ;
- vérifie chaque changement séparément.

## Étape 9 — Effectif et règles

Ouvre `player_profile.gd`, `football_rules_engine.gd`, puis
`ui/roster/roster_panel.gd`.

Exercice :

- ajoute un sixième remplaçant fictif aux deux listes ;
- adapte le test qui attend actuellement 16 profils ;
- ajoute un test de hors-jeu pour une attaque vers la gauche ;
- lance les smoke tests avant de modifier la simulation.

## Étape 10 — Placement arbitral

Ouvre `positioning_model.gd`, puis cherche `_update_positioning()` dans
`match.gd`.

Observe la séparation :

- le modèle calcule une qualité à partir de deux positions ;
- le HUD traduit une valeur numérique en retour compréhensible ;
- le match cumule la qualité et mémorise la position au moment du contact.

Exercice :

- change `CLEAR_VIEW_DISTANCE` de 230 à 180 ;
- observe quand l'indicateur passe de « nette » à « correcte » ;
- adapte ensuite `LOST_VIEW_DISTANCE` ;
- vérifie que les tests de placement continuent à passer.
