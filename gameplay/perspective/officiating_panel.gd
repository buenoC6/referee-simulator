extends CanvasLayer
class_name OfficiatingPanel

signal decision_submitted(decision: Dictionary)
signal var_review_requested

const SIMPLE_ACTIONS: Array[Dictionary] = [
	{
		"id": "fouls",
		"label": "FAUTE",
		"offence_id": "careless_tackle",
		"restart_id": "direct_free_kick",
	},
	{
		"id": "offside",
		"label": "HORS-JEU",
		"offence_id": "offside_interfering_play",
		"restart_id": "indirect_free_kick",
	},
	{
		"id": "goal",
		"category_id": "restarts",
		"label": "BUT ACCORDÉ",
		"offence_id": "goal_scored",
		"restart_id": "kick_off",
	},
	{
		"id": "no_offence",
		"category_id": "match_control",
		"label": "AUCUNE INFRACTION",
		"offence_id": "no_offence",
		"restart_id": "dropped_ball",
	},
]

@onready var context_label: Label = %ContextLabel
@onready var evidence_label: Label = %EvidenceLabel
@onready var action_label: Label = %ActionLabel
@onready var decision_card: PanelContainer = $DecisionCard
@onready var target_label: Label = %TargetLabel
@onready var identified_label: Label = %IdentifiedLabel
@onready var var_label: Label = %VarLabel
@onready var hint_label: Label = %HintLabel
@onready var foul_choice: PanelContainer = %FoulChoice
@onready var offside_choice: PanelContainer = %OffsideChoice
@onready var goal_choice: PanelContainer = %GoalChoice
@onready var no_offence_choice: PanelContainer = %NoOffenceChoice
@onready var var_choice: PanelContainer = %VarChoice
@onready var foul_choice_label: Label = %FoulChoiceLabel
@onready var offside_choice_label: Label = %OffsideChoiceLabel
@onready var goal_choice_label: Label = %GoalChoiceLabel
@onready var no_offence_choice_label: Label = %NoOffenceChoiceLabel
@onready var var_choice_label: Label = %VarChoiceLabel
@onready var foul_details: VBoxContainer = %FoulDetails
@onready var free_kick_choice: PanelContainer = %FreeKickChoice
@onready var penalty_choice: PanelContainer = %PenaltyChoice
@onready var no_card_choice: PanelContainer = %NoCardChoice
@onready var warning_choice: PanelContainer = %WarningChoice
@onready var yellow_choice: PanelContainer = %YellowChoice
@onready var red_choice: PanelContainer = %RedChoice
@onready var home_team_choice: PanelContainer = %HomeTeamChoice
@onready var away_team_choice: PanelContainer = %AwayTeamChoice
@onready var free_kick_choice_label: Label = %FreeKickChoiceLabel
@onready var penalty_choice_label: Label = %PenaltyChoiceLabel
@onready var no_card_choice_label: Label = %NoCardChoiceLabel
@onready var warning_choice_label: Label = %WarningChoiceLabel
@onready var yellow_choice_label: Label = %YellowChoiceLabel
@onready var red_choice_label: Label = %RedChoiceLabel
@onready var home_team_choice_label: Label = %HomeTeamChoiceLabel
@onready var away_team_choice_label: Label = %AwayTeamChoiceLabel
@onready var location_label: Label = %LocationLabel

var candidate_players: Array[PerspectivePlayer3D] = []
var looked_at_player: PerspectivePlayer3D
var identified_player: PerspectivePlayer3D
var suggested_offender: PerspectivePlayer3D
var suggested_affected: PerspectivePlayer3D
var selected_action_id: String = ""
var selected_restart_id: String = "direct_free_kick"
var selected_discipline_id: String = "none"
var awarded_team_id: int = -1
var award_team_manually_selected: bool = false


func _ready() -> void:
	visible = false
	foul_choice.gui_input.connect(_on_choice_input.bind("fouls"))
	offside_choice.gui_input.connect(_on_choice_input.bind("offside"))
	goal_choice.gui_input.connect(_on_choice_input.bind("goal"))
	no_offence_choice.gui_input.connect(_on_choice_input.bind("no_offence"))
	var_choice.gui_input.connect(_on_choice_input.bind("var"))
	free_kick_choice.gui_input.connect(
		_on_detail_choice_input.bind("restart", "direct_free_kick")
	)
	penalty_choice.gui_input.connect(
		_on_detail_choice_input.bind("restart", "penalty_kick")
	)
	no_card_choice.gui_input.connect(
		_on_detail_choice_input.bind("discipline", "none")
	)
	warning_choice.gui_input.connect(
		_on_detail_choice_input.bind("discipline", "verbal_warning")
	)
	yellow_choice.gui_input.connect(
		_on_detail_choice_input.bind("discipline", "yellow_card")
	)
	red_choice.gui_input.connect(
		_on_detail_choice_input.bind("discipline", "red_card")
	)
	home_team_choice.gui_input.connect(
		_on_detail_choice_input.bind("team", "0")
	)
	away_team_choice.gui_input.connect(
		_on_detail_choice_input.bind("team", "1")
	)


func show_for(
	context: Dictionary,
	candidates: Array[PerspectivePlayer3D],
	next_suggested_offender: PerspectivePlayer3D = null,
	next_suggested_affected: PerspectivePlayer3D = null
) -> void:
	candidate_players = candidates
	suggested_offender = next_suggested_offender
	suggested_affected = next_suggested_affected
	looked_at_player = null
	identified_player = null
	selected_action_id = ""
	selected_restart_id = "direct_free_kick"
	selected_discipline_id = "none"
	awarded_team_id = int(context.get("default_awarded_team_id", -1))
	award_team_manually_selected = false
	home_team_choice_label.text = str(context.get("home_team_name", "Domicile"))
	away_team_choice_label.text = str(context.get("away_team_name", "Visiteurs"))
	location_label.text = str(
		context.get("location_label", "Lieu mémorisé au moment du sifflet")
	)
	context_label.text = _sentence_case(str(context.get(
		"headline",
		"Le jeu est arrêté. Inspecte l’action."
	)))
	evidence_label.text = context.get(
		"evidence",
		"Approche-toi des joueurs pour les identifier."
	)
	action_label.text = "FAUTE HORS-JEU BUT AUCUNE INFRACTION VAR"
	target_label.text = "Aucun joueur dans le viseur"
	identified_label.text = ""
	var_label.text = ""
	hint_label.text = (
		"Tu peux encore te déplacer · E pour identifier · Entrée pour confirmer"
	)
	_refresh_choices()
	_refresh_foul_details()
	visible = true


func hide_panel() -> void:
	visible = false
	looked_at_player = null
	identified_player = null
	suggested_offender = null


func set_look_target(player: PerspectivePlayer3D) -> void:
	looked_at_player = player
	target_label.text = (
		"Dans le viseur · %s · E pour retenir" % _player_label(player)
		if player != null
		else "Aucun joueur dans le viseur"
	)


func selected_player() -> PerspectivePlayer3D:
	return identified_player


func show_var_message(message: String) -> void:
	var_label.text = "VAR · %s" % message
	hint_label.text = "La VAR conseille. La décision reste la tienne."


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if _event_matches(key_event, KEY_1, KEY_KP_1):
		_select_action("fouls")
	elif _event_matches(key_event, KEY_2, KEY_KP_2):
		_select_action("offside")
	elif _event_matches(key_event, KEY_3, KEY_KP_3):
		_request_var_review()
	elif _event_matches(key_event, KEY_G):
		_select_action("goal")
	elif _event_matches(key_event, KEY_N):
		_select_action("no_offence")
	elif _event_matches(key_event, KEY_4, KEY_KP_4):
		_select_restart("direct_free_kick")
	elif _event_matches(key_event, KEY_5, KEY_KP_5):
		_select_restart("penalty_kick")
	elif _event_matches(key_event, KEY_6, KEY_KP_6):
		_select_discipline("none")
	elif _event_matches(key_event, KEY_7, KEY_KP_7):
		_select_discipline("verbal_warning")
	elif _event_matches(key_event, KEY_8, KEY_KP_8):
		_select_discipline("yellow_card")
	elif _event_matches(key_event, KEY_9, KEY_KP_9):
		_select_discipline("red_card")
	elif _event_matches(key_event, KEY_T):
		_toggle_awarded_team()
	elif _event_matches(key_event, KEY_E):
		_lock_target()
	elif _event_matches(key_event, KEY_ENTER, KEY_KP_ENTER):
		_submit()
	elif _event_matches(key_event, KEY_BACKSPACE):
		identified_player = null
		identified_label.text = ""
		hint_label.text = "Identification annulée. Vise un joueur puis appuie sur E."
	else:
		return
	get_viewport().set_input_as_handled()


func _event_matches(
	event: InputEventKey,
	key: Key,
	alternate: Key = KEY_NONE
) -> bool:
	return (
		event.keycode == key
		or event.physical_keycode == key
		or (
			alternate != KEY_NONE
			and (
				event.keycode == alternate
				or event.physical_keycode == alternate
			)
		)
	)


func _on_choice_input(event: InputEvent, action_id: String) -> void:
	if not visible or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if (
		not mouse_event.pressed
		or mouse_event.button_index != MOUSE_BUTTON_LEFT
	):
		return
	if action_id == "var":
		_request_var_review()
	else:
		_select_action(action_id)
	get_viewport().set_input_as_handled()


func _on_detail_choice_input(
	event: InputEvent,
	choice_type: String,
	value: String
) -> void:
	if not visible or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if (
		not mouse_event.pressed
		or mouse_event.button_index != MOUSE_BUTTON_LEFT
	):
		return
	match choice_type:
		"restart":
			_select_restart(value)
		"discipline":
			_select_discipline(value)
		"team":
			_select_awarded_team(int(value), true)
	get_viewport().set_input_as_handled()


func _request_var_review() -> void:
	var_label.text = "VAR · Check en cours…"
	hint_label.text = "Analyse en cours. Tu peux continuer à inspecter."
	_refresh_choices(true)
	var_review_requested.emit()


func _select_action(action_id: String) -> void:
	selected_action_id = action_id
	var action := _action(action_id)
	action_label.text = "DÉCISION · %s" % action["label"]
	match action_id:
		"fouls":
			selected_restart_id = "direct_free_kick"
			hint_label.text = (
				"Choisis la reprise et la sanction, puis identifie le fautif."
			)
		"offside":
			selected_restart_id = "indirect_free_kick"
			selected_discipline_id = "none"
			award_team_manually_selected = false
			if identified_player != null:
				awarded_team_id = 1 - identified_player.team_id
			hint_label.text = "Identifie le joueur hors-jeu, puis confirme."
		"goal":
			selected_restart_id = "kick_off"
			selected_discipline_id = "none"
			award_team_manually_selected = false
			if suggested_offender != null:
				awarded_team_id = 1 - suggested_offender.team_id
			hint_label.text = (
				"Le but sera ajouté au score après confirmation."
			)
		"no_offence":
			selected_restart_id = "dropped_ball"
			selected_discipline_id = "none"
			awarded_team_id = -1
			award_team_manually_selected = false
			hint_label.text = (
				"Aucune infraction : confirme pour reprendre par balle à terre."
			)
	_refresh_choices()
	_refresh_foul_details()


func _select_restart(restart_id: String) -> void:
	if selected_action_id != "fouls":
		hint_label.text = "Choisis d’abord Faute pour préciser la reprise."
		return
	selected_restart_id = restart_id
	hint_label.text = (
		"Penalty sélectionné · confirme le fautif et l’équipe bénéficiaire."
		if restart_id == "penalty_kick"
		else "Coup franc au lieu mémorisé · choisis maintenant la sanction."
	)
	_refresh_foul_details()


func _select_discipline(discipline_id: String) -> void:
	if selected_action_id != "fouls":
		hint_label.text = "Choisis d’abord Faute pour préciser la sanction."
		return
	selected_discipline_id = discipline_id
	hint_label.text = "Sanction retenue · identifie le fautif puis confirme."
	_refresh_foul_details()


func _select_awarded_team(team_id: int, manual: bool) -> void:
	awarded_team_id = clampi(team_id, 0, 1)
	award_team_manually_selected = manual
	hint_label.text = "Équipe bénéficiaire choisie · Entrée pour confirmer."
	_refresh_foul_details()


func _toggle_awarded_team() -> void:
	_select_awarded_team(0 if awarded_team_id == 1 else 1, true)


func _lock_target() -> void:
	if selected_action_id == "no_offence":
		hint_label.text = (
			"Aucun joueur ne doit être identifié pour cette décision."
		)
		return
	if looked_at_player == null or not looked_at_player.active:
		hint_label.text = "Aucun joueur dans le viseur. Approche-toi et regarde-le."
		return
	identified_player = looked_at_player
	if (
		not award_team_manually_selected
		and selected_action_id in ["fouls", "offside", "goal"]
	):
		awarded_team_id = 1 - identified_player.team_id
	identified_label.text = "Retenu · %s" % _player_label(
		identified_player
	)
	hint_label.text = (
		"Vérifie reprise, sanction et bénéficiaire, puis confirme."
		if selected_action_id == "fouls"
		else "Joueur retenu · confirme avec Entrée."
	)
	_refresh_foul_details()


func _submit() -> void:
	if selected_action_id.is_empty():
		hint_label.text = (
			"Choisis une décision : Faute, Hors-jeu, But ou Aucune infraction."
		)
		return
	if (
		_requires_identified_player(selected_action_id)
		and (identified_player == null or not identified_player.active)
	):
		hint_label.text = "Identifie le joueur concerné avec E avant de confirmer."
		return
	var action := _action(selected_action_id)
	var offender := identified_player
	if selected_action_id == "goal" and offender == null:
		offender = suggested_offender
	elif selected_action_id == "no_offence":
		offender = null
	if awarded_team_id < 0 and offender != null:
		awarded_team_id = 1 - offender.team_id
	var affected := (
		suggested_affected
		if selected_action_id == "fouls"
		else null
	)
	if affected == offender:
		affected = null
	decision_submitted.emit({
		"category_id": action.get("category_id", action["id"]),
		"offence_id": action["offence_id"],
		"offence_label": action["label"],
		"offender": offender,
		"affected": affected,
		"restart_id": (
			selected_restart_id
			if selected_action_id == "fouls"
			else action["restart_id"]
		),
		"discipline_id": (
			selected_discipline_id
			if selected_action_id == "fouls"
			else "none"
		),
		"awarded_team_id": awarded_team_id,
		"secondary_discipline_id": "none",
		"simplified": true,
		"discipline_explicit": selected_action_id == "fouls",
	})


func _requires_identified_player(action_id: String) -> bool:
	return action_id in ["fouls", "offside"]


func _action(action_id: String) -> Dictionary:
	for action in SIMPLE_ACTIONS:
		if action["id"] == action_id:
			return action
	return SIMPLE_ACTIONS[0]


func _player_label(player: PerspectivePlayer3D) -> String:
	if player == null:
		return "aucun"
	return "%s %d" % [
		"Bleu" if player.team_id == 0 else "Rouge",
		player.shirt_number,
	]


func _refresh_choices(var_pending: bool = false) -> void:
	_style_choice(
		foul_choice,
		foul_choice_label,
		selected_action_id == "fouls"
	)
	_style_choice(
		offside_choice,
		offside_choice_label,
		selected_action_id == "offside"
	)
	_style_choice(
		goal_choice,
		goal_choice_label,
		selected_action_id == "goal"
	)
	_style_choice(
		no_offence_choice,
		no_offence_choice_label,
		selected_action_id == "no_offence"
	)
	_style_choice(var_choice, var_choice_label, var_pending)


func _refresh_foul_details() -> void:
	var expanded := selected_action_id == "fouls"
	foul_details.visible = expanded
	decision_card.offset_top = -414.0 if expanded else -284.0
	if not expanded:
		return
	_style_choice(
		free_kick_choice,
		free_kick_choice_label,
		selected_restart_id == "direct_free_kick"
	)
	_style_choice(
		penalty_choice,
		penalty_choice_label,
		selected_restart_id == "penalty_kick"
	)
	_style_choice(
		no_card_choice,
		no_card_choice_label,
		selected_discipline_id == "none"
	)
	_style_choice(
		warning_choice,
		warning_choice_label,
		selected_discipline_id == "verbal_warning"
	)
	_style_choice(
		yellow_choice,
		yellow_choice_label,
		selected_discipline_id == "yellow_card"
	)
	_style_choice(
		red_choice,
		red_choice_label,
		selected_discipline_id == "red_card"
	)
	_style_choice(
		home_team_choice,
		home_team_choice_label,
		awarded_team_id == 0
	)
	_style_choice(
		away_team_choice,
		away_team_choice_label,
		awarded_team_id == 1
	)


func _style_choice(
	panel: PanelContainer,
	label: Label,
	selected: bool
) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color("#e9d799")
		if selected
		else Color(0.105, 0.116, 0.098, 0.94)
	)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	label.add_theme_color_override(
		"font_color",
		Color("#11130f") if selected else Color("#e7e4d6")
	)


func _sentence_case(text: String) -> String:
	var clean := text.strip_edges().to_lower()
	if clean.is_empty():
		return clean
	var result := clean.left(1).to_upper() + clean.substr(1)
	if result.begins_with("Var"):
		result = "VAR" + result.substr(3)
	return result
