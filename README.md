# Referee Simulator

Tranche verticale 3D d'un jeu de simulation d'arbitrage au football, réalisée avec **Godot 4.7.1** et **GDScript**.

Le but de ce dépôt est double :

1. valider une boucle de jeu centrée sur le positionnement et la décision arbitrale ;
2. servir de projet d'apprentissage lisible pour découvrir les bases de Godot.

## Ce qui est déjà jouable

- match 11 contre 11 continu et accéléré sur un terrain 3D ;
- trois clubs à domicile et trois enceintes sélectionnables, avec palettes,
  tribunes, toiture, écran de stade, panneaux et lumière propres ;
- terrain enrichi avec vingt bandes de tonte, lignes plus nettes, arcs de
  réparation et de corner, surfaces et zones de but complètes, points
  réglementaires, filets et poteaux de corner ;
- joueurs stylisés articulés avec bras, jambes, chaussures, variations visuelles,
  ombres et animation de course ;
- balle à panneaux contrastés avec dribble animé, ombre projetée, rotation,
  trajectoires paraboliques variables et effet latéral sur les frappes ;
- caméra arbitre légèrement rehaussée pour mieux lire le jeu tout en conservant
  une perspective terrestre limitée, déplacement `ZQSD` et regard souris ;
- repère 3D au-dessus du ballon et indicateur HUD gauche/droite/arrière avec
  distance, afin de retrouver immédiatement le jeu sans caméra automatique ;
- mini-carte 2D en direct avec les 22 joueurs, le ballon, la position de
  l'arbitre et un cône représentant sa direction de regard ;
- séquences de possession, soutien en triangles, passes évaluées, pressing,
  interceptions, tirs, buts et duels sans arrêt automatique ;
- coup de sifflet libre avec `Espace`, à n'importe quel moment du jeu ;
- coup d'envoi déclenché par le premier coup de sifflet du joueur, sans départ
  automatique, avec ballon au centre, chaque joueur dans son camp et adversaires
  maintenus à 9,15 m ;
- deux périodes de 45 minutes accélérées, arrêt à la mi-temps, changement de
  camp et second coup d'envoi donné par l'arbitre ;
- arrêt complet du chronomètre, du ballon, des joueurs et des assistants pendant
  le choix de la décision ;
- choix de l'enjeu avant le match : amical, poules, qualificatif, élimination
  directe, finale ou derby ;
- trois modes solo accessibles directement depuis le menu : partie rapide,
  tournoi mondial fictif et carrière internationale ;
- tournoi et carrière composés de cinq affectations successives, avec enjeu
  croissant, rapport intermédiaire et bouton vers le match suivant ;
- menu pause avec `Échap` : reprendre, recommencer l'affectation avec la même
  graine ou revenir au menu principal ;
- graine de match visible et configurable depuis le menu : rejouer avec la même
  graine réinitialise les choix aléatoires dans le même ordre ;
- outils de test optionnels depuis le menu : `F1` force une faute, `F2` un
  hors-jeu, `F3` un but potentiel et `F4` une action sans infraction ;
- ambiance sonore procédurale sans asset externe : rumeur stéréo du stade dont
  le niveau suit la tension, réactions distinctes aux buts et aux décisions,
  cris de protestation, contacts, frappes de balle et séquences de sifflet ;
- touche `M` pour couper ou rétablir immédiatement toute l'ambiance du match ;
- tension indépendante des deux équipes : les décisions contestables et les
  actions ignorées font monter leur colère, tandis qu'une intervention juste
  peut calmer l'équipe lésée ;
- difficulté dynamique : rythme, pertes de balle, fautes, contestataires autour
  de l'arbitre et risque d'interruption augmentent avec la tension ;
- qualité de preuve calculée selon la distance, l'angle de regard et
  l'occultation : elle détermine la fenêtre de réaction et les points de
  placement du rapport ;
- décisions principales `Faute`, `Hors-jeu`, `But` et `Aucune infraction`,
  puis détail progressif de la reprise, de la sanction et de l'équipe
  bénéficiaire ;
- après le sifflet, le match reste figé mais l'arbitre peut marcher autour de
  l'action, viser un joueur, l'identifier avec `E`, puis confirmer ;
- lieu de reprise mémorisé automatiquement à la position du ballon au sifflet,
  matérialisé sur la pelouse et utilisé pour replacer le coup franc ;
- avantage signalé avec `V` pendant que le jeu continue, avant tout coup de
  sifflet, avec sanction mémorisée jusqu'au prochain arrêt ;
- demande de check VAR avec `3` pendant un arrêt ;
- annonces VAR spontanées sur les actions révisables, avec équipe, numéro et
  marqueur violet conservé au-dessus du joueur concerné ;
- coup franc ou penalty, aucune sanction, avertissement verbal, jaune ou rouge,
  avec choix explicite de l'équipe qui reprend le jeu ;
- deux assistants qui suivent la ligne de hors-jeu et lèvent visiblement leur
  drapeau sans arrêter eux-mêmes le match ;
- hors-jeu évalué par rapport au ballon et à l'avant-dernier défenseur, coups de
  pied de but joués depuis la zone de but et distances de reprise appliquées ;
- rapport final centré sur la tension finale, les pics de colère et le contrôle
  du match, sans note chiffrée d'arbitrage.

Le jeu utilise uniquement des formes et matériaux dessinés par Godot. Aucun
asset externe n'est nécessaire.

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
├── modes/         # Catalogue des modes et calendriers d'affectations
├── perspective/   # Match 3D, caméra arbitre, assistants et catalogue de décisions
├── incidents/     # Données réglementaires historiques réutilisées
├── evaluation/    # Calculs purs du prototype 2D conservé
├── match/         # Ancienne boucle 2D conservée comme référence
└── rules/         # Calculs de règles indépendants
ui/                # Menu, thème et rapport de résultat
tests/             # Tests headless très légers
docs/              # Architecture, apprentissage et décisions
```

Les dossiers suivent les recommandations Godot : fichiers et dossiers en `snake_case`, nœuds en `PascalCase`, et ressources proches des scènes qui les utilisent.

## Parcours de lecture conseillé

1. [`core/app.tscn`](core/app.tscn) — point d'entrée, session et changement d'écran ;
2. [`gameplay/modes/game_mode_catalog.gd`](gameplay/modes/game_mode_catalog.gd) — données des trois modes et de leurs affectations ;
3. [`ui/main_menu/main_menu.gd`](ui/main_menu/main_menu.gd) — choix du mode et préparation ;
4. [`gameplay/perspective/referee_perspective_match.gd`](gameplay/perspective/referee_perspective_match.gd) — match continu et orchestration ;
5. [`ui/pause_menu.gd`](ui/pause_menu.gd) — pause globale et intentions de navigation ;
6. [`gameplay/perspective/stadium_catalog.gd`](gameplay/perspective/stadium_catalog.gd) — identités des clubs, stades et lumières ;
7. [`gameplay/perspective/referee_controller_3d.gd`](gameplay/perspective/referee_controller_3d.gd) — caméra et déplacement de l'arbitre ;
8. [`gameplay/perspective/football_team_ai.gd`](gameplay/perspective/football_team_ai.gd) — pression, couloirs et options de passe ;
9. [`gameplay/perspective/perspective_observation_model.gd`](gameplay/perspective/perspective_observation_model.gd) — distance, angle et occultation ;
10. [`gameplay/perspective/perspective_decision_scoring.gd`](gameplay/perspective/perspective_decision_scoring.gd) — score technique, placement et réaction ;
11. [`gameplay/perspective/match_intensity_model.gd`](gameplay/perspective/match_intensity_model.gd) — enjeu, tension et difficulté ;
12. [`gameplay/perspective/match_audio_director.gd`](gameplay/perspective/match_audio_director.gd) — ambiance et bruitages procéduraux ;
13. [`gameplay/perspective/officiating_catalog.gd`](gameplay/perspective/officiating_catalog.gd) — catalogue extensible ;
14. [`gameplay/perspective/officiating_panel.gd`](gameplay/perspective/officiating_panel.gd) — flux de décision ;
15. [`gameplay/perspective/assistant_referee_3d.gd`](gameplay/perspective/assistant_referee_3d.gd) — assistants et drapeaux ;
16. [`docs/architecture.md`](docs/architecture.md) — responsabilités et limites.

## Philosophie du prototype

Ce socle propose un match complet accéléré, mais son IA et son arbitrage restent
volontairement lisibles et simplifiés. Ils permettent de tester le cœur du jeu
sans prétendre reproduire une simulation professionnelle ou l'intégralité des
Lois du Jeu :

```text
suivre l'action
→ se positionner
→ observer un incident
→ siffler ou laisser jouer
→ figer le jeu et prendre une décision
→ gérer la réaction des deux équipes
→ empêcher le match de devenir incontrôlable
```

## Qualité

Le workflow GitHub Actions importe le projet et exécute le test headless à chaque push et pull request. Le projet ne dépend d'aucun plugin communautaire ni asset externe.

Pour reproduire un problème, note la graine affichée dans le menu ou le HUD,
relance une partie avec la même valeur et active les outils de test si tu veux
forcer une famille d'événement précise.

## Documentation produit

La vision, le MVP, les situations et la roadmap sont maintenus dans l'espace Confluence **Referee Simulator**. Le dépôt documente l'implémentation et la manière de lancer le jeu.
