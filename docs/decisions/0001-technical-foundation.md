# ADR-001 — Socle technique du prototype

- Date : 2026-07-26
- Statut : accepté pour le premier prototype

## Contexte

Le projet est le premier jeu vidéo de son auteur. Il doit permettre d'apprendre les concepts fondamentaux sans bloquer la validation de la boucle d'arbitrage.

## Décision

- utiliser Godot 4.7.1 standard ;
- écrire les comportements en GDScript typé ;
- commencer en 2D vue du dessus ;
- cibler d'abord Windows avec le renderer Compatibility ;
- représenter les acteurs avec des formes générées par le moteur ;
- utiliser une action scénarisée avant de construire une IA de football ;
- stocker les paramètres d'incident dans des ressources Godot ;
- utiliser des tests headless sans plugin externe pour le socle.

## Conséquences positives

- installation légère ;
- feedback visuel rapide ;
- moins de concepts et de dépendances ;
- export Web possible plus tard ;
- incidents faciles à dupliquer et ajuster ;
- code lisible et testable.

## Limites acceptées

- le match n'est pas émergent ;
- les graphismes sont temporaires ;
- le smoke test ne remplace pas une future suite de tests ;
- l'architecture devra évoluer si la simulation devient beaucoup plus complexe.

