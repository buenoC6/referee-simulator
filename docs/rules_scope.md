# Périmètre réglementaire du prototype 0.3

Ce document évite une promesse trompeuse : le prototype s'appuie sur les Lois
du Jeu, mais ne prétend pas encore toutes les reproduire. Les références sont
les [Lois du Jeu 2026/27 de l'IFAB](https://www.theifab.com/laws/latest/).

## Ce qui est simulé

### Loi 3 — Joueurs

- onze titulaires par équipe, dont un gardien ;
- cinq remplaçants nommés pour la compétition fictive du prototype ;
- un remplacement automatique par équipe à la 60e minute ;
- une exclusion retire réellement le joueur et l'équipe continue à dix ;
- un second avertissement entraîne une exclusion.

Le maximum de cinq remplacements est présent dans le modèle, mais les trois
fenêtres de remplacement et les procédures complètes ne sont pas encore
simulées.

### Loi 9 — Ballon en jeu et hors du jeu

Le ballon est considéré sorti uniquement lorsque son disque visuel a entièrement
franchi une ligne. Une sortie déclenche automatiquement la reprise appropriée.

### Lois 15, 16 et 17 — Reprises

- rentrée de touche après une sortie latérale ;
- coup de pied de but après une sortie sur la ligne de but touchée en dernier
  par l'équipe attaquante ;
- corner après une sortie sur la ligne de but touchée en dernier par l'équipe
  qui défend.

Les gestes, distances réglementaires et infractions pendant la reprise ne sont
pas encore animés.

### Loi 11 — Hors-jeu

La position est évaluée au départ d'une passe avec le ballon et l'avant-dernier
adversaire comme lignes de référence. L'infraction est sifflée uniquement pour
le destinataire prévu, donc lorsqu'il participe directement à l'action.

Le prototype n'évalue pas encore les interférences complexes avec un adversaire,
les déviations délibérées ou les sauvetages.

### Loi 12 — Fautes et incorrections

La situation actuelle représente une intervention téméraire :

- coup franc direct ;
- penalty si la faute a lieu dans la surface du défenseur ;
- avertissement attendu ;
- carton choisi attaché au joueur concerné ;
- rouge direct ou second jaune entraînant l'exclusion.

## Prochaines règles à introduire

1. avantage réellement mémorisé et retour disciplinaire au prochain arrêt ;
2. plusieurs types de fautes avec imprudence, témérité et force excessive ;
3. main, fautes indirectes et comportement antisportif ;
4. reprises visibles avec délai, placement et distance des adversaires ;
5. détections de but et de hors-jeu plus proches de la géométrie réelle ;
6. temps additionnel, blessures et procédures de remplacement ;
7. changements de côté à la mi-temps.

Chaque ajout devrait commencer par des cas de test dans `tests/smoke_test.gd`,
puis être branché à la simulation. Cette approche garde la règle indépendante
de l'animation et de l'interface.
