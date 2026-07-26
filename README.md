# Referee Simulator

Premier vertical slice d'un jeu de simulation d'arbitrage au football, réalisé avec **Godot 4.7.1** et **GDScript**.

Le but de ce dépôt est double :

1. valider une boucle de jeu centrée sur le positionnement et la décision arbitrale ;
2. servir de projet d'apprentissage lisible pour découvrir les bases de Godot.

## Ce qui est déjà jouable

- déplacement de l'arbitre avec `ZQSD` ;
- menu principal présentant le contexte et lançant une partie solo ;
- match accéléré de trois minutes avec deux équipes de 11 joueurs ;
- IA simplifiée : formations, possession, passes, pressing, interceptions, tirs et buts ;
- plusieurs fenêtres de décision arbitrale limitées dans le temps ;
- coup de sifflet avec `Espace` ;
- choix de la décision technique et disciplinaire ;
- note détaillée sur la décision, la discipline, le positionnement et le délai ;
- possibilité de rejouer immédiatement.

Le jeu utilise uniquement des formes dessinées par Godot. Aucun asset externe n'est nécessaire.

## Prérequis

- [Godot 4.7.1 standard](https://godotengine.org/download/windows/) — la version .NET n'est pas nécessaire ;
- Git, de préférence accompagné de GitHub Desktop si tu débutes.

## Lancer le projet

1. Ouvre Godot.
2. Clique sur **Importer**.
3. Sélectionne le fichier `project.godot`.
4. Ouvre le projet puis appuie sur `F6` ou sur le bouton **Exécuter le projet**.

En ligne de commande :

```powershell
godot --path . --editor
```

Validation sans interface :

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/smoke_test.gd
```

## Structure

```text
gameplay/
├── ball/          # Ballon visuel qui suit le porteur
├── evaluation/    # Calcul pur et testable du résultat
├── field/         # Terrain et lignes
├── incidents/     # Données des situations + orchestration
├── match/         # Scène principale et boucle de partie
├── players/       # Joueurs de démonstration
├── referee/       # Contrôle du personnage arbitre
├── simulation/    # Décisions autonomes du match
└── teams/         # Effectifs, rôles et formations
ui/                # HUD, décision et écran de résultats
tests/             # Tests headless très légers
docs/              # Architecture, apprentissage et décisions
```

Les dossiers suivent les recommandations Godot : fichiers et dossiers en `snake_case`, nœuds en `PascalCase`, et ressources proches des scènes qui les utilisent.

## Parcours de lecture conseillé

1. [`core/app.tscn`](core/app.tscn) — point d'entrée et changement d'écran ;
2. [`ui/main_menu/main_menu.tscn`](ui/main_menu/main_menu.tscn) — menu et contexte joueur ;
3. [`gameplay/match/match.tscn`](gameplay/match/match.tscn) — composition du match ;
4. [`gameplay/match/match.gd`](gameplay/match/match.gd) — machine à états de la partie ;
5. [`gameplay/referee/referee.gd`](gameplay/referee/referee.gd) — entrées et mouvement ;
6. [`gameplay/incidents/incident_data.gd`](gameplay/incidents/incident_data.gd) — séparation entre données et comportement ;
7. [`gameplay/evaluation/evaluation_service.gd`](gameplay/evaluation/evaluation_service.gd) — logique sans dépendance à une scène ;
8. [`docs/architecture.md`](docs/architecture.md) — explication complète des responsabilités.

## Philosophie du prototype

Ce socle propose un match complet accéléré, mais son IA reste volontairement
lisible et simplifiée. Elle permet de tester le cœur du jeu sans prétendre
reproduire toutes les tactiques du football professionnel :

```text
suivre l'action
→ se positionner
→ observer un incident
→ siffler ou laisser jouer
→ prendre une décision
→ comprendre son évaluation
```

## Qualité

Le workflow GitHub Actions importe le projet et exécute le test headless à chaque push et pull request. Le projet ne dépend d'aucun plugin communautaire pour rester facile à comprendre.

## Documentation produit

La vision, le MVP, les situations et la roadmap sont maintenus dans l'espace Confluence **Referee Simulator**. Le dépôt documente l'implémentation et la manière de lancer le jeu.
