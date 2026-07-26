extends RefCounted
class_name OfficiatingCatalog

const RESTARTS := [
	{"id": "play_on", "label": "Laisser jouer / avantage"},
	{"id": "direct_free_kick", "label": "Coup franc direct"},
	{"id": "indirect_free_kick", "label": "Coup franc indirect"},
	{"id": "penalty_kick", "label": "Penalty"},
	{"id": "throw_in", "label": "Rentrée de touche"},
	{"id": "goal_kick", "label": "Coup de pied de but"},
	{"id": "corner_kick", "label": "Corner"},
	{"id": "dropped_ball", "label": "Balle à terre"},
	{"id": "kick_off", "label": "Coup d’envoi"},
]

const DISCIPLINES := [
	{"id": "none", "label": "Aucune sanction"},
	{"id": "verbal_warning", "label": "Rappel à l’ordre"},
	{"id": "yellow_card", "label": "Carton jaune"},
	{"id": "second_yellow", "label": "Second jaune + exclusion"},
	{"id": "red_card", "label": "Carton rouge direct"},
]

static var CATEGORIES: Array = [
	{
		"id": "fouls",
		"label": "Fautes avec contact",
		"offences": [
			_item("careless_tackle", "Tacle / charge imprudente", "direct_free_kick", "none",
				"Contact fautif sans sanction disciplinaire obligatoire."),
			_item("reckless_tackle", "Tacle / charge téméraire", "direct_free_kick", "yellow_card",
				"Intervention sans égard pour le danger ou les conséquences."),
			_item("serious_foul_play", "Faute grossière", "direct_free_kick", "red_card",
				"Force excessive ou mise en danger de l’intégrité physique."),
			_item("tripping", "Faire trébucher / tenter de faire trébucher", "direct_free_kick", "none",
				"Contact sur les jambes qui déséquilibre l’adversaire."),
			_item("kicking", "Donner / tenter de donner un coup", "direct_free_kick", "yellow_card",
				"Coup porté ou tenté contre un adversaire."),
			_item("pushing", "Pousser un adversaire", "direct_free_kick", "none",
				"Poussée irrégulière avec les mains ou le corps."),
			_item("holding", "Tenir un adversaire", "direct_free_kick", "none",
				"Retenir le maillot ou le corps et empêcher le déplacement."),
			_item("jumping_at", "Sauter sur un adversaire", "direct_free_kick", "none",
				"Impact aérien irrégulier."),
			_item("striking", "Frapper / tenter de frapper", "direct_free_kick", "red_card",
				"Geste violent hors d’un duel légitime pour le ballon."),
			_item("handball", "Main sanctionnable", "direct_free_kick", "none",
				"Contact bras-main qui doit être sanctionné selon le contexte."),
		],
	},
	{
		"id": "technical",
		"label": "Fautes techniques",
		"offences": [
			_item("dangerous_play", "Jeu dangereux sans contact", "indirect_free_kick", "none",
				"Action dangereuse qui empêche un adversaire de jouer le ballon."),
			_item("impeding", "Faire obstruction sans contact", "indirect_free_kick", "none",
				"Couper la trajectoire sans jouer le ballon et sans contact."),
			_item("goalkeeper_backpass", "Passe volontaire prise à la main par le gardien",
				"indirect_free_kick", "none", "Le gardien prend à la main une passe volontaire du pied."),
			_item("goalkeeper_release", "Gardien conserve le ballon trop longtemps",
				"indirect_free_kick", "none", "Dépassement du délai autorisé avant remise en jeu."),
			_item("double_touch", "Deuxième touche sur une reprise", "indirect_free_kick", "none",
				"Le tireur rejoue le ballon avant qu’un autre joueur ne le touche."),
			_item("penalty_encroachment", "Empiètement sur penalty", "indirect_free_kick", "none",
				"Joueur entré trop tôt dans la surface sur l’exécution."),
		],
	},
	{
		"id": "offside",
		"label": "Hors-jeu",
		"offences": [
			_item("offside_interfering_play", "Hors-jeu — joue le ballon",
				"indirect_free_kick", "none", "Le joueur en position de hors-jeu participe directement."),
			_item("offside_opponent", "Hors-jeu — gêne un adversaire",
				"indirect_free_kick", "none", "Le joueur gêne la vision ou l’action d’un adversaire."),
			_item("offside_advantage", "Hors-jeu — tire avantage d’un rebond",
				"indirect_free_kick", "none", "Le joueur profite d’un rebond après une position illicite."),
			_item("onside", "Position régulière / laisser jouer",
				"play_on", "none", "Aucune infraction de hors-jeu."),
		],
	},
	{
		"id": "misconduct",
		"label": "Comportements et discipline",
		"offences": [
			_item("unsporting_behaviour", "Comportement antisportif", "indirect_free_kick",
				"yellow_card", "Geste ou conduite contraire à l’esprit du jeu."),
			_item("simulation", "Simulation", "indirect_free_kick", "yellow_card",
				"Tentative de tromper l’arbitre en feignant une faute."),
			_item("dissent", "Contestation", "indirect_free_kick", "yellow_card",
				"Protestation manifeste par paroles ou gestes."),
			_item("persistent_offences", "Infractions persistantes", "direct_free_kick",
				"yellow_card", "Répétition de fautes malgré les avertissements."),
			_item("delaying_restart", "Retarder la reprise", "indirect_free_kick",
				"yellow_card", "Empêcher ou ralentir volontairement la reprise."),
			_item("promising_attack", "Anéantir une attaque prometteuse", "direct_free_kick",
				"yellow_card", "Faute tactique interrompant une attaque prometteuse."),
			_item("dogso", "Anéantir une occasion manifeste de but", "direct_free_kick",
				"red_card", "Faute privant l’adversaire d’une occasion manifeste."),
			_item("violent_conduct", "Acte de brutalité", "direct_free_kick", "red_card",
				"Force excessive hors d’un duel pour le ballon."),
			_item("spitting_biting", "Cracher / mordre", "direct_free_kick", "red_card",
				"Conduite entraînant une exclusion directe."),
			_item("illegal_entry", "Entrée sans autorisation", "indirect_free_kick",
				"yellow_card", "Joueur entrant ou revenant sans signal de l’arbitre."),
		],
	},
	{
		"id": "restarts",
		"label": "Sorties et reprises",
		"offences": [
			_item("touchline_out", "Ballon sorti en touche", "throw_in", "none",
				"Rentrée de touche pour l’équipe adverse au dernier toucher."),
			_item("goal_line_attacker", "Sortie de but — dernier toucher attaquant",
				"goal_kick", "none", "Coup de pied de but."),
			_item("goal_line_defender", "Sortie de but — dernier toucher défenseur",
				"corner_kick", "none", "Corner."),
			_item("goal_scored", "But accordé", "kick_off", "none",
				"Le ballon a entièrement franchi la ligne entre les poteaux."),
			_item("dropped_ball", "Interruption neutre / balle à terre", "dropped_ball", "none",
				"Interruption sans faute nécessitant une reprise neutre."),
		],
	},
	{
		"id": "match_control",
		"label": "Gestion du match",
		"offences": [
			_item("no_offence", "Aucune infraction constatée", "dropped_ball", "none",
				"Coup de sifflet sans infraction : reprendre par une balle à terre."),
			_item("advantage", "Appliquer l’avantage", "play_on", "none",
				"L’équipe victime conserve une situation favorable."),
			_item("injury", "Arrêt pour blessure", "dropped_ball", "none",
				"Interruption rendue nécessaire par une blessure sérieuse."),
			_item("substitution", "Autoriser un remplacement", "play_on", "none",
				"Gestion administrative d’un remplacement."),
			_item("verbal_management", "Rappel à l’ordre sans carton", "play_on",
				"verbal_warning", "Intervention préventive de l’arbitre."),
		],
	},
]


static func categories() -> Array:
	return CATEGORIES


static func restarts() -> Array:
	return RESTARTS


static func disciplines() -> Array:
	return DISCIPLINES


static func category(category_id: String) -> Dictionary:
	for entry in CATEGORIES:
		if entry["id"] == category_id:
			return entry
	return CATEGORIES[0]


static func offence(offence_id: String) -> Dictionary:
	for category_entry in CATEGORIES:
		for offence_entry in category_entry["offences"]:
			if offence_entry["id"] == offence_id:
				return offence_entry
	return category("match_control")["offences"][0]


static func label_for(entries: Array, entry_id: String) -> String:
	for entry in entries:
		if entry["id"] == entry_id:
			return entry["label"]
	return entry_id


static func _item(
	item_id: String,
	label: String,
	default_restart: String,
	default_discipline: String,
	description: String
) -> Dictionary:
	return {
		"id": item_id,
		"label": label,
		"default_restart": default_restart,
		"default_discipline": default_discipline,
		"description": description,
	}
