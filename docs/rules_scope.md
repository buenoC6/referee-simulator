# Périmètre réglementaire du prototype 0.7

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

### Lois 7 et 8 — Durée et coups d'envoi

- deux périodes égales de 45 minutes simulées ;
- arrêt du jeu à la mi-temps et reprise au sifflet du joueur ;
- changement de camp et inversion des directions d'attaque ;
- ballon immobile sur le point central avant le signal ;
- tous les joueurs dans leur propre moitié, à l'exception du botteur ;
- adversaires à au moins 9,15 m jusqu'à la mise en jeu ;
- équipe adverse au coup d'envoi après un but et équipe opposée au début de la
  seconde période.

Le temps additionnel et l'intervalle de quinze minutes en temps réel ne sont pas
reproduits dans ce match volontairement accéléré.

### Loi 9 — Ballon en jeu et hors du jeu

Le ballon est considéré sorti uniquement lorsque son disque visuel a entièrement
franchi une ligne. Une sortie déclenche automatiquement la reprise appropriée.

### Lois 15, 16 et 17 — Reprises

- rentrée de touche après une sortie latérale ;
- coup de pied de but après une sortie sur la ligne de but touchée en dernier
  par l'équipe attaquante ;
- corner après une sortie sur la ligne de but touchée en dernier par l'équipe
  qui défend.

Les adversaires sont replacés à 9,15 m sur coup franc. Sur coup de pied de but,
ils quittent la surface avant que le gardien remette le ballon en jeu. Le
penalty place le ballon au point réglementaire, le gardien sur sa ligne et les
autres joueurs hors de la surface et à distance. Les gestes complets de rentrée
de touche et de corner ne sont pas encore animés.

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
- coup franc ou penalty choisi explicitement par l'arbitre ;
- équipe bénéficiaire choisie, avec présélection de l'adversaire du fautif ;
- lieu du coup franc mémorisé au sifflet et matérialisé au sol ;
- avantage signalable avant le sifflet sans arrêter le jeu ;
- carton choisi attaché au joueur concerné ;
- rouge direct ou second jaune entraînant l'exclusion.

## Prochaines règles à introduire

1. mémorisation d'un carton après avantage pour le montrer au prochain arrêt ;
2. plusieurs types de fautes avec imprudence, témérité et force excessive ;
3. main, fautes indirectes et comportement antisportif ;
4. gestes complets de touche et de corner, avec infractions de procédure ;
5. détections de but et de hors-jeu plus proches de la géométrie réelle ;
6. temps additionnel, blessures et procédures de remplacement ;
7. temps additionnel calculé séparément pour chaque période.

Chaque ajout devrait commencer par des cas de test dans `tests/smoke_test.gd`,
puis être branché à la simulation. Cette approche garde la règle indépendante
de l'animation et de l'interface.
