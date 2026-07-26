# Contribuer

Ce projet est actuellement un prototype d'apprentissage. Les règles suivantes favorisent un historique simple et une base facile à relire.

## Avant de modifier

1. Choisir un objectif petit et démontrable.
2. Vérifier qu'il appartient au périmètre MVP.
3. Lire la scène et le script responsables avant d'ajouter un nouveau système.

## Conventions

- fichiers et dossiers Godot : `snake_case` ;
- noms de nœuds : `PascalCase` ;
- classes nommées : `PascalCase` ;
- variables, signaux et fonctions : `snake_case` ;
- une scène réutilisable regroupe son script et ses ressources dans le même dossier ;
- préférer les signaux aux références lointaines entre branches de la scène ;
- préférer une `Resource` pour les données éditables ;
- ne pas ajouter d'autoload tant qu'un besoin global réel n'est pas démontré.

## Definition of Done

- [ ] Le comportement fonctionne dans l'éditeur.
- [ ] Le projet se charge sans erreur en mode headless.
- [ ] Le smoke test passe.
- [ ] Le code reste compréhensible sans connaître toute l'architecture.
- [ ] La documentation est mise à jour si une responsabilité ou un choix change.
- [ ] La licence de chaque asset ajouté est identifiée.

## Vérifications

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/smoke_test.gd
```

