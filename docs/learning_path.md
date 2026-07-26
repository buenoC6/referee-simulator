# Parcours d'apprentissage

Le meilleur moyen d'apprendre ce projet est de faire de petites modifications visibles.

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

