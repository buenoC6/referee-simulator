extends Node3D
class_name RefereePerspectiveMatch

signal main_menu_requested

enum Phase {
	PRE_MATCH,
	PLAYING,
	HALF_TIME,
	STOPPED_FOR_DECISION,
	RESULTS,
}

const PLAYER_SCRIPT := preload(
	"res://gameplay/perspective/perspective_player_3d.gd"
)
const ASSISTANT_SCRIPT := preload(
	"res://gameplay/perspective/assistant_referee_3d.gd"
)
const STADIUM_CATALOG := preload(
	"res://gameplay/perspective/stadium_catalog.gd"
)
const FOOTBALL_LAWS := preload(
	"res://gameplay/perspective/football_laws_3d.gd"
)
const MATCH_REAL_DURATION := 180.0
const HALF_REAL_DURATION := MATCH_REAL_DURATION * 0.5
const EVENT_VALIDITY_SECONDS := 6.0
const REFEREE_START := Vector3(0.0, 0.0, 20.0)
const BALL_RADIUS := 0.22

@onready var world_root: Node3D = $World
@onready var actors_root: Node3D = $Actors
@onready var referee: RefereeController3D = $Referee
@onready var ball: MeshInstance3D = $Ball
@onready var hud: PerspectiveHud = $PerspectiveHud
@onready var officiating_panel: OfficiatingPanel = $OfficiatingPanel
@onready var results_panel: ResultsPanel = $ResultsPanel

var phase := Phase.PRE_MATCH
var phase_elapsed: float = 0.0
var match_elapsed: float = 0.0
var second_half: bool = false
var blue_score: int = 0
var red_score: int = 0
var blue_team: Array[PerspectivePlayer3D] = []
var red_team: Array[PerspectivePlayer3D] = []
var perspective_players: Array[PerspectivePlayer3D] = []
var assistants: Array[AssistantReferee3D] = []
var possession_team_id: int = 0
var possessor: PerspectivePlayer3D
var pending_receiver: PerspectivePlayer3D
var pending_shooter: PerspectivePlayer3D
var pending_action: String = ""
var pending_offside: bool = false
var pending_shot_scores: bool = false
var ball_in_flight: bool = false
var ball_flight_elapsed: float = 0.0
var ball_flight_duration: float = 1.0
var ball_flight_start := Vector3.ZERO
var ball_flight_target := Vector3.ZERO
var ball_flight_loft: float = 0.5
var ball_flight_curve: float = 0.0
var ball_previous_position := Vector3.ZERO
var ball_shadow: MeshInstance3D
var action_timer: float = 1.6
var shape_timer: float = 0.0
var foul_timer: float = 11.0
var event_feedback_timer: float = 0.0
var current_truth: Dictionary = {}
var whistle_observation: Dictionary = {}
var whistle_position := Vector3.ZERO
var decisions: Array[Dictionary] = []
var missed_events: int = 0
var ball_marker: Label3D
var restart_marker: MeshInstance3D
var restart_marker_label: Label3D
var match_importance_id: String = "group_stage"
var match_profile: Dictionary = MatchIntensityModel.profile(match_importance_id)
var stadium_id: String = STADIUM_CATALOG.DEFAULT_ID
var stadium_profile: Dictionary = STADIUM_CATALOG.profile(stadium_id)
var blue_tension: float = 0.0
var red_tension: float = 0.0
var blue_peak_tension: float = 0.0
var red_peak_tension: float = 0.0
var protest_timer: float = 0.0
var protesting_team_id: int = -1
var protest_players: Array[PerspectivePlayer3D] = []
var unmanageable_timer: float = 0.0
var match_end_reason: String = ""
var inspection_target: PerspectivePlayer3D
var var_referred_player: PerspectivePlayer3D
var random := RandomNumberGenerator.new()


func configure_match(
	importance_id: String,
	selected_stadium_id: String = STADIUM_CATALOG.DEFAULT_ID
) -> void:
	match_importance_id = importance_id
	match_profile = MatchIntensityModel.profile(importance_id)
	stadium_id = selected_stadium_id
	stadium_profile = STADIUM_CATALOG.profile(stadium_id)


func _ready() -> void:
	random.randomize()
	_build_environment()
	_build_pitch()
	_build_teams()
	_build_assistants()
	_build_ball()
	_build_restart_marker()
	hud.configure_minimap(
		perspective_players,
		ball,
		referee,
		referee.camera,
		Color(stadium_profile["primary_color"]),
		Color(stadium_profile["away_color"])
	)
	referee.whistle_requested.connect(_on_whistle_requested)
	referee.advantage_requested.connect(_on_advantage_requested)
	officiating_panel.decision_submitted.connect(_on_decision_submitted)
	officiating_panel.var_review_requested.connect(_on_var_review_requested)
	results_panel.replay_requested.connect(_start_match)
	results_panel.main_menu_requested.connect(_request_main_menu)
	_start_match()


func _process(delta: float) -> void:
	phase_elapsed += delta
	if event_feedback_timer > 0.0:
		event_feedback_timer -= delta
		if event_feedback_timer <= 0.0:
			hud.hide_incident()

	match phase:
		Phase.PRE_MATCH:
			_update_live_reading()
		Phase.PLAYING:
			match_elapsed += delta
			_update_clock()
			if not second_half and match_elapsed >= HALF_REAL_DURATION:
				_begin_half_time()
				return
			_update_tension(delta)
			if phase != Phase.PLAYING:
				return
			_update_ground_truth(delta)
			_update_assistants()
			_process_simulation(delta)
			_update_live_reading()
			if phase == Phase.PLAYING and match_elapsed >= MATCH_REAL_DURATION:
				_finish_match()
		Phase.HALF_TIME:
			_update_live_reading()
		Phase.STOPPED_FOR_DECISION:
			_update_inspection_target()


func _start_match() -> void:
	phase = Phase.PRE_MATCH
	phase_elapsed = 0.0
	match_elapsed = 0.0
	second_half = false
	blue_score = 0
	red_score = 0
	possession_team_id = 0
	decisions.clear()
	current_truth.clear()
	whistle_observation.clear()
	missed_events = 0
	match_profile = MatchIntensityModel.profile(match_importance_id)
	blue_tension = float(match_profile["baseline_tension"])
	red_tension = float(match_profile["baseline_tension"])
	blue_peak_tension = blue_tension
	red_peak_tension = red_tension
	protest_timer = 0.0
	protesting_team_id = -1
	protest_players.clear()
	unmanageable_timer = 0.0
	match_end_reason = ""
	inspection_target = null
	var_referred_player = null
	action_timer = 1.6
	shape_timer = 0.0
	foul_timer = random.randf_range(9.0, 14.0)
	event_feedback_timer = 0.0
	ball_in_flight = false
	pending_receiver = null
	pending_shooter = null
	pending_action = ""

	for player in perspective_players:
		player.reset_for_match()
		var first_half_home: Vector3 = player.get_meta(
			"first_half_home_position"
		)
		player.set_meta("home_position", first_half_home)
		player.global_position = first_half_home
		player.rotation = Vector3.ZERO
		player.freeze_actor()
	for assistant in assistants:
		assistant.clear_signal()
		assistant.global_position.z = 0.0
		assistant.set_process(true)

	referee.reset_to(REFEREE_START)
	referee.set_input_enabled(true)
	officiating_panel.hide_panel()
	results_panel.hide_panel()
	hud.set_decision_mode(false)
	hud.hide_incident()
	hud.hide_assistant_signal()
	_hide_restart_marker()
	hud.set_venue(
		stadium_profile["stadium_name"],
		stadium_profile["city"]
	)
	hud.set_team_identity(
		stadium_profile["short_name"],
		Color(stadium_profile["primary_color"]),
		"VISITEURS",
		Color(stadium_profile["away_color"])
	)
	hud.set_phase("PRÊT POUR LE COUP D’ENVOI")
	hud.set_objective(
		"%s au %s : place-toi, puis siffle le début du match."
		% [match_profile["label"], stadium_profile["stadium_name"]]
	)
	hud.set_controls(
		"ZQSD : se placer · Souris : regarder · Espace : donner le coup d’envoi"
	)
	_prepare_kickoff(0)
	_update_clock()
	_refresh_tension_hud()


func _begin_play() -> void:
	phase = Phase.PLAYING
	phase_elapsed = 0.0
	hud.set_phase("MATCH EN COURS")
	hud.set_objective(
		"Le jeu continue jusqu’à ton sifflet. Une mauvaise décision nourrit la colère de l’équipe lésée."
	)
	hud.set_controls(
		"ZQSD : courir · Espace : siffler · V : avantage"
	)
	_take_prepared_kickoff()
	_update_team_shapes()


func _begin_half_time() -> void:
	phase = Phase.HALF_TIME
	phase_elapsed = 0.0
	for player in perspective_players:
		player.freeze_actor()
		player.set_physics_process(false)
	for assistant in assistants:
		assistant.clear_signal()
		assistant.set_process(false)
	ball_in_flight = false
	pending_action = ""
	pending_receiver = null
	pending_shooter = null
	current_truth.clear()
	_clear_var_signal()
	hud.hide_assistant_signal()
	hud.hide_incident()
	referee.set_input_enabled(true)
	hud.set_phase("MI-TEMPS · CHANGEMENT DE CAMP")
	hud.set_objective(
		"Les équipes changent de côté. Appuie sur Espace pour donner le coup d’envoi de la seconde période."
	)
	hud.set_controls(
		"ZQSD : se placer · Souris : regarder · Espace : lancer la seconde période"
	)


func _start_second_half() -> void:
	second_half = true
	_switch_team_ends()
	_prepare_kickoff(1)
	for player in perspective_players:
		player.set_physics_process(true)
	for assistant in assistants:
		assistant.set_process(true)
	phase = Phase.PLAYING
	phase_elapsed = 0.0
	hud.set_phase("SECONDE PÉRIODE")
	hud.set_objective(
		"Les équipes ont changé de camp ; le jeu reprend à ton signal."
	)
	hud.set_controls(
		"ZQSD : courir · Espace : siffler · V : avantage"
	)
	_take_prepared_kickoff()
	_update_team_shapes()


func _switch_team_ends() -> void:
	for player in perspective_players:
		var first_half_home: Vector3 = player.get_meta(
			"first_half_home_position"
		)
		var second_half_home := Vector3(
			first_half_home.x,
			first_half_home.y,
			-first_half_home.z
		)
		player.set_meta("home_position", second_half_home)
		player.global_position = second_half_home
		player.rotation.y += PI
		player.freeze_actor()
	referee.reset_to(Vector3(0.0, 0.0, -REFEREE_START.z), 180.0)


func _process_simulation(delta: float) -> void:
	var tempo := MatchIntensityModel.tempo_multiplier(
		blue_tension,
		red_tension
	)
	shape_timer -= delta * tempo
	action_timer -= delta * tempo
	foul_timer -= delta * tempo
	if protest_timer > 0.0:
		protest_timer -= delta
		_update_protesters()
		if protest_timer <= 0.0:
			protest_players.clear()
			protesting_team_id = -1
	if shape_timer <= 0.0:
		_update_team_shapes()
		shape_timer = 0.34

	if ball_in_flight:
		_update_ball_flight(delta)
		return
	if possessor == null or not is_instance_valid(possessor) or not possessor.active:
		_set_possession(possession_team_id, _first_active_player(possession_team_id))
		if possessor == null:
			return

	var attack_direction := _attack_direction(possession_team_id)
	var dribble_phase := match_elapsed * 11.0
	var touch_offset := 0.58 + (sin(dribble_phase) * 0.5 + 0.5) * 0.14
	var carrier_target := Vector3(
		clampf(possessor.global_position.x * 0.78, -25.0, 25.0),
		0.0,
		clampf(
			possessor.global_position.z + attack_direction * 6.0,
			-47.0,
			47.0
		)
	)
	possessor.move_to(carrier_target, 3.7 * tempo)
	ball.global_position = possessor.global_position + Vector3(
		0.0,
		BALL_RADIUS + maxf(0.0, sin(dribble_phase)) * 0.055,
		attack_direction * touch_offset
	)
	_roll_ball(Vector3(0.0, 0.0, attack_direction * delta * 3.7 * tempo))
	_update_ball_shadow()

	if foul_timer <= 0.0 and current_truth.is_empty():
		_generate_foul_event()
		return
	if action_timer <= 0.0:
		_choose_action()


func _choose_action() -> void:
	if possessor == null:
		return
	var progress := absf(possessor.global_position.z) / 52.5
	if progress >= 0.72 and random.randf() < 0.43:
		_start_shot()
		return
	var turnover_chance := 0.16 + maxf(
		blue_tension,
		red_tension
	) * 0.0012
	if random.randf() < turnover_chance:
		var opponent := _nearest_active_opponent(
			possession_team_id,
			possessor.global_position
		)
		if opponent != null and opponent.global_position.distance_to(
			possessor.global_position
		) <= 4.8:
			_set_possession(1 - possession_team_id, opponent)
			hud.set_phase("Ballon récupéré par %s" % opponent.name)
			action_timer = random.randf_range(1.1, 1.8)
			return
	_start_pass()


func _start_pass() -> void:
	var candidates: Array[PerspectivePlayer3D] = []
	for player in _active_team(possession_team_id):
		if player != possessor and not bool(player.get_meta("goalkeeper", false)):
			candidates.append(player)
	if candidates.is_empty():
		action_timer = 1.0
		return

	var attack_direction := _attack_direction(possession_team_id)
	candidates.sort_custom(
		func(a: PerspectivePlayer3D, b: PerspectivePlayer3D) -> bool:
			return a.global_position.z * attack_direction > b.global_position.z * attack_direction
	)
	pending_receiver = candidates[
		random.randi_range(0, mini(candidates.size() - 1, 4))
	]
	var offside_line := _offside_line_for(possession_team_id)
	if (
		current_truth.is_empty()
		and random.randf() < 0.24
		and absf(offside_line) > 8.0
	):
		pending_receiver.global_position.z = offside_line + attack_direction * 2.4

	pending_offside = _is_offside(
		pending_receiver,
		possession_team_id,
		offside_line
	)
	var passer_name := possessor.name
	var destination := pending_receiver.global_position + Vector3(
		0.0,
		BALL_RADIUS,
		attack_direction * 1.8
	)
	possessor.freeze_actor()
	possessor = null
	pending_shooter = null
	pending_action = "pass"
	_start_ball_flight(
		destination,
		random.randf_range(0.72, 1.2),
		random.randf_range(0.24, 0.58)
	)
	hud.set_phase("Passe de %s" % passer_name)


func _start_shot() -> void:
	var shooting_team := possession_team_id
	var attack_direction := _attack_direction(shooting_team)
	var goal_z := attack_direction * 53.2
	var shooter_name := possessor.name
	pending_shooter = possessor
	pending_shot_scores = random.randf() < 0.34
	var target_x := random.randf_range(-3.1, 3.1)
	if not pending_shot_scores:
		target_x = random.randf_range(5.0, 9.0) * (
			-1.0 if random.randf() < 0.5 else 1.0
		)
	possessor.freeze_actor()
	possessor = null
	pending_receiver = null
	pending_action = "shot"
	_start_ball_flight(
		Vector3(target_x, 0.55, goal_z),
		random.randf_range(0.62, 0.88),
		random.randf_range(0.9, 1.85),
		random.randf_range(-0.75, 0.75)
	)
	hud.set_phase("Frappe de %s !" % shooter_name)


func _start_ball_flight(
	target: Vector3,
	duration: float,
	loft: float = 0.5,
	curve: float = 0.0
) -> void:
	ball_in_flight = true
	ball_flight_elapsed = 0.0
	ball_flight_duration = duration / MatchIntensityModel.tempo_multiplier(
		blue_tension,
		red_tension
	)
	ball_flight_start = ball.global_position
	ball_flight_target = target
	ball_flight_target.y = maxf(ball_flight_target.y, BALL_RADIUS)
	ball_flight_loft = loft
	ball_flight_curve = curve
	ball_previous_position = ball.global_position


func _update_ball_flight(delta: float) -> void:
	ball_flight_elapsed += delta
	var progress := clampf(
		ball_flight_elapsed / maxf(ball_flight_duration, 0.01),
		0.0,
		1.0
	)
	var next_position := ball_flight_start.lerp(ball_flight_target, progress)
	next_position.y += 4.0 * ball_flight_loft * progress * (1.0 - progress)
	var flat_path := ball_flight_target - ball_flight_start
	flat_path.y = 0.0
	if not flat_path.is_zero_approx():
		var curve_direction := Vector3.UP.cross(flat_path.normalized())
		next_position += curve_direction * (
			sin(progress * PI) * ball_flight_curve
		)
	ball.global_position = next_position
	_roll_ball(ball.global_position - ball_previous_position)
	ball_previous_position = ball.global_position
	_update_ball_shadow()
	if progress >= 1.0:
		_resolve_ball_flight()


func _resolve_ball_flight() -> void:
	ball_in_flight = false
	if pending_action == "pass":
		if pending_receiver == null or not pending_receiver.active:
			_set_possession(possession_team_id, _first_active_player(possession_team_id))
		elif pending_offside:
			_set_possession(possession_team_id, pending_receiver)
			_register_offside_event(pending_receiver)
		else:
			_set_possession(possession_team_id, pending_receiver)
		pending_receiver = null
		pending_offside = false
		action_timer = random.randf_range(1.0, 1.9)
		return

	if pending_action == "shot":
		var shooting_team := possession_team_id
		if pending_shot_scores:
			if shooting_team == 0:
				blue_score += 1
			else:
				red_score += 1
			_register_truth({
				"category_id": "restarts",
				"offence_id": "goal_scored",
				"restart_id": "kick_off",
				"discipline_id": "none",
				"offender": pending_shooter,
				"affected": null,
				"position": ball.global_position,
				"headline": "Le ballon semble avoir franchi la ligne de but.",
				"var_reviewable": true,
			})
			hud.set_phase("But ! Le jeu attend ton éventuelle confirmation.")
			pending_shooter = null
			pending_action = ""
			_kickoff_for(1 - shooting_team)
		else:
			pending_shooter = null
			pending_action = ""
			_goal_kick_for(1 - shooting_team)
	action_timer = random.randf_range(1.1, 1.8)
	_update_clock()


func _generate_foul_event() -> void:
	if possessor == null:
		foul_timer = 3.0
		return
	var offender := _nearest_active_opponent(
		possession_team_id,
		possessor.global_position
	)
	if offender == null:
		foul_timer = 4.0
		return

	var victim := possessor
	var offset := Vector3(
		random.randf_range(-0.7, 0.7),
		0.0,
		random.randf_range(-0.7, 0.7)
	)
	if offset.length_squared() < 0.1:
		offset = Vector3(0.65, 0.0, 0.28)
	offset = offset.normalized() * random.randf_range(0.72, 0.92)
	offender.global_position = victim.global_position + offset
	offender.perform_tackle(victim.global_position - offender.global_position)
	victim.stumble(
		random.randf_range(1.65, 1.95),
		-72.0 if random.randf() < 0.5 else 72.0
	)
	var restart := (
		"penalty_kick"
		if _is_penalty_area(victim.global_position, offender.team_id)
		else "direct_free_kick"
	)
	_register_truth({
		"category_id": "fouls",
		"offence_id": "reckless_tackle",
		"restart_id": restart,
		"discipline_id": "yellow_card",
		"offender": offender,
		"affected": victim,
		"position": victim.global_position,
		"headline": "Un duel appuyé vient d’avoir lieu près du ballon.",
		"advantage_available": true,
		"var_reviewable": (
			restart == "penalty_kick"
			or random.randf() < 0.45
		),
	})
	hud.set_phase("Duel appuyé — le jeu continue tant que tu ne siffles pas")
	foul_timer = random.randf_range(14.0, 22.0) * (
		MatchIntensityModel.foul_interval_multiplier(
			blue_tension,
			red_tension
		)
	)
	action_timer = 0.9


func _register_offside_event(receiver: PerspectivePlayer3D) -> void:
	if not current_truth.is_empty():
		return
	var side_index := 0 if receiver.global_position.x < 0.0 else 1
	assistants[side_index].signal_offside()
	hud.show_assistant_signal(
		"Assistant %s : drapeau levé pour hors-jeu"
		% ("gauche" if side_index == 0 else "droit")
	)
	_register_truth({
		"category_id": "offside",
		"offence_id": "offside_interfering_play",
		"restart_id": "indirect_free_kick",
		"discipline_id": "none",
		"offender": receiver,
		"affected": null,
		"position": receiver.global_position,
		"headline": "Un assistant a levé son drapeau, mais le jeu continue.",
		"var_reviewable": true,
	})


func _register_truth(event: Dictionary) -> void:
	if not current_truth.is_empty():
		return
	current_truth = event.duplicate()
	current_truth["age"] = 0.0
	current_truth["var_alerted"] = false
	var event_position: Vector3 = event["position"]
	var event_offender := event.get("offender") as PerspectivePlayer3D
	var event_affected := event.get("affected") as PerspectivePlayer3D
	current_truth["observation_at_event"] = _capture_observation(
		event_position,
		event_offender,
		event_affected
	)


func _update_ground_truth(delta: float) -> void:
	if current_truth.is_empty():
		return
	current_truth["age"] = float(current_truth["age"]) + delta
	if (
		current_truth.get("var_reviewable", false)
		and not current_truth.get("var_alerted", false)
		and float(current_truth["age"]) >= 2.4
	):
		current_truth["var_alerted"] = true
		_announce_var_review(current_truth)
	var validity := (
		10.0
		if current_truth.get("var_alerted", false)
		else EVENT_VALIDITY_SECONDS
	)
	if current_truth["age"] > validity:
		missed_events += 1
		var affected_team_id := _team_id_for(
			current_truth.get("affected") as PerspectivePlayer3D
		)
		if affected_team_id < 0:
			var offender_team_id := _team_id_for(
				current_truth.get("offender") as PerspectivePlayer3D
			)
			if offender_team_id >= 0:
				affected_team_id = 1 - offender_team_id
		var reaction := MatchIntensityModel.missed_event_reaction(
			affected_team_id,
			match_importance_id
		)
		_apply_tension_delta(
			float(reaction["blue_delta"]),
			float(reaction["red_delta"])
		)
		hud.show_incident(
			"L’ACTION N’A PAS ÉTÉ TRAITÉE",
			"Le jeu continue, mais l’équipe lésée n’oublie pas."
		)
		event_feedback_timer = 2.2
		_clear_var_signal()
		current_truth.clear()
		hud.hide_assistant_signal()


func _on_var_review_requested() -> void:
	if phase != Phase.STOPPED_FOR_DECISION:
		return
	if current_truth.is_empty():
		var checked_player := (
			officiating_panel.selected_player()
			if officiating_panel.selected_player() != null
			else inspection_target
		)
		officiating_panel.show_var_message(
			(
				"Check terminé : aucune erreur claire concernant %s."
				% _player_display_name(checked_player)
			)
			if checked_player != null
			else "Check terminé : aucune action décisive identifiable."
		)
		return

	current_truth["var_alerted"] = true
	_announce_var_review(current_truth)
	officiating_panel.show_var_message(
		"Revue recommandée : reviens sur l’action de %s."
		% _player_display_name(var_referred_player)
	)


func _announce_var_review(event: Dictionary) -> void:
	_clear_var_signal()
	var_referred_player = event.get("offender") as PerspectivePlayer3D
	if var_referred_player == null:
		var_referred_player = event.get("affected") as PerspectivePlayer3D
	if var_referred_player != null:
		var_referred_player.set_var_review_signal(true)
	var player_name := _player_display_name(var_referred_player)
	hud.show_incident(
		"VAR · RETOUR SUR L’ACTION",
		(
			"Revue recommandée pour %s · siffle puis reviens identifier le joueur."
			% player_name
		)
	)
	event_feedback_timer = 4.2


func _on_advantage_requested() -> void:
	if phase != Phase.PLAYING:
		return
	if (
		current_truth.is_empty()
		or current_truth.get("category_id", "") != "fouls"
		or not bool(current_truth.get("advantage_available", false))
	):
		hud.show_incident(
			"Avantage",
			"Aucune faute récente à laisser jouer."
		)
		event_feedback_timer = 1.8
		return

	var offender := current_truth.get("offender") as PerspectivePlayer3D
	var affected := current_truth.get("affected") as PerspectivePlayer3D
	var awarded_team := (
		affected.team_id
		if affected != null
		else possession_team_id
	)
	var decision: Dictionary = {
		"category_id": "fouls",
		"offence_id": current_truth.get("offence_id", "careless_tackle"),
		"offence_label": "AVANTAGE",
		"offender": offender,
		"affected": affected,
		"restart_id": "play_on",
		"discipline_id": "none",
		"secondary_discipline_id": "none",
		"awarded_team_id": awarded_team,
		"simplified": true,
	}
	var expected := _expected_decision()
	expected["restart_id"] = "play_on"
	expected["discipline_id"] = "none"
	var evaluated := decision.duplicate()
	evaluated["offender_team_id"] = _team_id_for(offender)
	evaluated["offender_instance_id"] = (
		offender.get_instance_id()
		if offender != null
		else 0
	)
	var record := _evaluate_decision(evaluated, expected)
	decisions.append(record)
	_apply_tension_delta(
		float(record["blue_delta"]),
		float(record["red_delta"])
	)
	_clear_var_signal()
	current_truth.clear()
	_start_team_reaction(record)
	hud.set_phase("AVANTAGE · LE JEU CONTINUE")
	hud.set_objective("L’équipe victime conserve le ballon.")
	hud.show_incident(
		"Avantage",
		"Décision signalée sans interrompre le jeu."
	)
	event_feedback_timer = 2.4
	action_timer = maxf(action_timer, 0.8)
	foul_timer = maxf(foul_timer, 6.0)


func _clear_var_signal() -> void:
	if var_referred_player != null and is_instance_valid(var_referred_player):
		var_referred_player.set_var_review_signal(false)
	var_referred_player = null


func _player_display_name(player: PerspectivePlayer3D) -> String:
	if player == null:
		return "un joueur non identifié"
	return "%s %d" % [
		stadium_profile["short_name"] if player.team_id == 0 else "Visiteur",
		player.shirt_number,
	]


func _on_whistle_requested() -> void:
	if phase == Phase.PRE_MATCH:
		_begin_play()
		hud.show_incident(
			"COUP D’ENVOI",
			"Le match commence à ton signal."
		)
		event_feedback_timer = 1.8
		return
	if phase == Phase.HALF_TIME:
		_start_second_half()
		hud.show_incident(
			"COUP D’ENVOI · 2E PÉRIODE",
			"Les équipes ont changé de camp."
		)
		event_feedback_timer = 1.8
		return
	if phase != Phase.PLAYING:
		hud.set_controls("Le coup de sifflet sera disponible dès la reprise du jeu.")
		return

	phase = Phase.STOPPED_FOR_DECISION
	phase_elapsed = 0.0
	whistle_position = FOOTBALL_LAWS.clamp_inside_pitch(
		Vector3(ball.global_position.x, 0.0, ball.global_position.z)
	)
	_show_restart_marker(whistle_position)
	for player in perspective_players:
		player.freeze_actor()
		player.set_physics_process(false)
	for assistant in assistants:
		assistant.set_process(false)
	referee.set_inspection_enabled()
	var target_position: Vector3 = whistle_position
	var truth_offender: PerspectivePlayer3D
	var truth_affected: PerspectivePlayer3D
	if not current_truth.is_empty():
		target_position = current_truth["position"]
		truth_offender = current_truth.get("offender") as PerspectivePlayer3D
		truth_affected = current_truth.get("affected") as PerspectivePlayer3D
	whistle_observation = _capture_observation(
		target_position,
		truth_offender,
		truth_affected
	)
	var candidates: Array[PerspectivePlayer3D] = _players_near_ball(
		perspective_players.size()
	)
	var suggested_offender: PerspectivePlayer3D = (
		truth_offender
		if not current_truth.is_empty()
		else (candidates[0] if not candidates.is_empty() else null)
	)
	var suggested_affected: PerspectivePlayer3D = (
		truth_affected
		if not current_truth.is_empty()
		else null
	)
	var assistant_signal: bool = assistants.any(
		func(assistant: AssistantReferee3D) -> bool:
			return assistant.is_flag_raised()
	)
	var context: Dictionary = {
		"headline": (
			current_truth.get("headline", "Tu as arrêté le jeu sans événement évident.")
			if not current_truth.is_empty()
			else "Tu as choisi d’arrêter le jeu."
		),
		"evidence": _observation_summary(whistle_observation, assistant_signal),
		"suggested_category": "offside" if assistant_signal else "fouls",
		"suggested_offence": (
			"offside_interfering_play"
			if assistant_signal
			else "careless_tackle"
		),
		"default_awarded_team_id": (
			truth_affected.team_id
			if truth_affected != null
			else possession_team_id
		),
		"home_team_name": stadium_profile["short_name"],
		"away_team_name": "Visiteurs",
		"location_label": _restart_location_label(whistle_position),
	}
	hud.set_phase("COUP DE SIFFLET — LE CHRONOMÈTRE EST ARRÊTÉ")
	hud.set_objective(
		"Le jeu est figé, mais tu peux encore marcher autour de l’action et identifier le joueur."
	)
	hud.set_controls(
		"Inspecte librement · 1 Faute · 2 Hors-jeu · E identifier · Entrée confirmer"
	)
	hud.hide_incident()
	hud.set_decision_mode(true)
	officiating_panel.show_for(
		context,
		candidates,
		suggested_offender,
		suggested_affected
	)
	_update_inspection_target()


func _on_decision_submitted(decision: Dictionary) -> void:
	decision = decision.duplicate()
	var simple_offender := decision["offender"] as PerspectivePlayer3D
	var expected := _expected_decision()
	var evaluated_decision := decision.duplicate()
	evaluated_decision["offender_team_id"] = _team_id_for(
		decision["offender"] as PerspectivePlayer3D
	)
	evaluated_decision["offender_instance_id"] = (
		simple_offender.get_instance_id()
		if simple_offender != null
		else 0
	)
	var record: Dictionary = _evaluate_decision(
		evaluated_decision,
		expected
	)
	decisions.append(record)
	var discipline_feedback: String = "Aucune sanction"
	var offender := decision["offender"] as PerspectivePlayer3D
	if offender != null and offender.active:
		discipline_feedback = offender.apply_discipline(
			decision["discipline_id"]
		)
	var affected := decision["affected"] as PerspectivePlayer3D
	var secondary_discipline_id: String = decision.get(
		"secondary_discipline_id",
		"none"
	)
	if (
		affected != null
		and affected.active
		and secondary_discipline_id != "none"
	):
		discipline_feedback += " · %s" % affected.apply_discipline(
			secondary_discipline_id
		)
	_apply_restart(decision)
	_hide_restart_marker()
	_apply_tension_delta(
		float(record["blue_delta"]),
		float(record["red_delta"])
	)
	_clear_var_signal()
	current_truth.clear()
	for assistant in assistants:
		assistant.clear_signal()
		assistant.set_process(true)
	for player in perspective_players:
		player.set_physics_process(true)
	hud.hide_assistant_signal()
	officiating_panel.hide_panel()
	hud.set_decision_mode(false)
	phase = Phase.PLAYING
	phase_elapsed = 0.0
	referee.set_input_enabled(true)
	_clear_inspection_highlights()
	_start_team_reaction(record)
	hud.set_phase(
		"%s · %s" % [
			decision["offence_label"],
			OfficiatingCatalog.label_for(
				OfficiatingCatalog.restarts(),
				decision["restart_id"]
			),
		]
	)
	hud.set_objective(
		"%s · %s" % [record["reaction_detail"], discipline_feedback]
	)
	hud.set_controls(
		"ZQSD : courir · Espace : siffler · V : avantage"
	)
	hud.show_incident(
		record["reaction_title"],
		record["short_feedback"]
	)
	event_feedback_timer = 3.2
	action_timer = 1.1
	foul_timer = maxf(foul_timer, 5.0)


func _expected_decision() -> Dictionary:
	var expected: Dictionary = (
		current_truth.duplicate()
		if not current_truth.is_empty()
		else {
			"category_id": "match_control",
			"offence_id": "no_offence",
			"restart_id": "dropped_ball",
			"discipline_id": "none",
			"offender": null,
			"affected": null,
			"age": EVENT_VALIDITY_SECONDS,
		}
	)
	expected["offender_team_id"] = _team_id_for(
		expected.get("offender") as PerspectivePlayer3D
	)
	expected["affected_team_id"] = _team_id_for(
		expected.get("affected") as PerspectivePlayer3D
	)
	expected["awarded_team_id"] = (
		expected["affected_team_id"]
		if int(expected["affected_team_id"]) >= 0
		else 1 - int(expected["offender_team_id"])
		if int(expected["offender_team_id"]) >= 0
		else -1
	)
	var expected_offender := expected.get("offender") as PerspectivePlayer3D
	expected["offender_instance_id"] = (
		expected_offender.get_instance_id()
		if expected_offender != null
		else 0
	)
	return expected


func _evaluate_decision(
	decision: Dictionary,
	expected: Dictionary
) -> Dictionary:
	var reaction := MatchIntensityModel.evaluate_reaction(
		expected,
		decision,
		match_importance_id
	)
	var blue_delta: float = reaction["blue_delta"]
	var red_delta: float = reaction["red_delta"]
	var strongest_delta := maxf(blue_delta, red_delta)
	var reaction_title := "LES ÉQUIPES ACCEPTENT LA DÉCISION"
	var home_label: String = stadium_profile["short_name"]
	if strongest_delta >= 18.0:
		reaction_title = (
			"%s EXPLOSE" % home_label
			if blue_delta > red_delta
			else "LES VISITEURS EXPLOSENT"
		)
	elif strongest_delta >= 7.0:
		reaction_title = (
			"%s CONTESTE" % home_label
			if blue_delta > red_delta
			else "LES VISITEURS CONTESTENT"
		)
	elif minf(blue_delta, red_delta) < -1.0:
		reaction_title = "LA PRESSION RETOMBE"

	return {
		"quality": reaction["quality"],
		"blue_delta": blue_delta,
		"red_delta": red_delta,
		"reaction_title": reaction_title,
		"reaction_detail": "Tension : %s %s · Visiteurs %s" % [
			home_label,
			_format_delta(blue_delta),
			_format_delta(red_delta),
		],
		"short_feedback": (
			"Attendu : %s · %s"
			% [
				OfficiatingCatalog.offence(expected["offence_id"])["label"],
				OfficiatingCatalog.label_for(
					OfficiatingCatalog.restarts(),
					expected["restart_id"]
				),
			]
		),
		}


func _update_tension(delta: float) -> void:
	var baseline: float = match_profile["baseline_tension"]
	var recovery: float = match_profile["recovery_per_second"]
	blue_tension = move_toward(blue_tension, baseline, recovery * delta)
	red_tension = move_toward(red_tension, baseline, recovery * delta)
	_refresh_tension_hud()

	if maxf(blue_tension, red_tension) >= 98.0:
		unmanageable_timer += delta
		if unmanageable_timer >= 7.0:
			_finish_match(
				"Le match a dû être interrompu : les joueurs ne répondent plus aux consignes."
			)
	else:
		unmanageable_timer = maxf(0.0, unmanageable_timer - delta * 2.0)


func _apply_tension_delta(blue_delta: float, red_delta: float) -> void:
	blue_tension = clampf(blue_tension + blue_delta, 0.0, 100.0)
	red_tension = clampf(red_tension + red_delta, 0.0, 100.0)
	blue_peak_tension = maxf(blue_peak_tension, blue_tension)
	red_peak_tension = maxf(red_peak_tension, red_tension)
	_refresh_tension_hud()


func _refresh_tension_hud() -> void:
	hud.set_match_tension(
		blue_tension,
		red_tension,
		MatchIntensityModel.control_state(blue_tension, red_tension),
		match_profile["label"]
	)


func _start_team_reaction(record: Dictionary) -> void:
	var blue_delta: float = record["blue_delta"]
	var red_delta: float = record["red_delta"]
	var dominant_delta := maxf(blue_delta, red_delta)
	protesting_team_id = 0 if blue_delta > red_delta else 1
	var team_tension := (
		blue_tension if protesting_team_id == 0 else red_tension
	)
	if dominant_delta < 7.0 and team_tension < 45.0:
		protest_players.clear()
		protesting_team_id = -1
		return

	var candidates := _active_team(protesting_team_id)
	candidates.sort_custom(
		func(a: PerspectivePlayer3D, b: PerspectivePlayer3D) -> bool:
			return (
				a.global_position.distance_squared_to(referee.global_position)
				< b.global_position.distance_squared_to(referee.global_position)
			)
	)
	protest_players.clear()
	var protest_count := clampi(2 + floori(team_tension / 25.0), 2, 6)
	for player in candidates:
		if player == possessor:
			continue
		protest_players.append(player)
		if protest_players.size() >= protest_count:
			break
	protest_timer = 2.0 + team_tension * 0.035


func _update_protesters() -> void:
	for index in range(protest_players.size()):
		var player := protest_players[index]
		if not is_instance_valid(player) or not player.active:
			continue
		var angle := TAU * float(index) / maxf(
			float(protest_players.size()),
			1.0
		)
		var target := referee.global_position + Vector3(
			cos(angle) * 2.2,
			0.0,
			sin(angle) * 2.2
		)
		player.move_to(target, 4.2)


func _team_id_for(player: PerspectivePlayer3D) -> int:
	return player.team_id if player != null else -1


func _format_delta(value: float) -> String:
	if absf(value) < 0.5:
		return "stable"
	return "%+d" % roundi(value)


func _apply_restart(decision: Dictionary) -> void:
	var offender := decision["offender"] as PerspectivePlayer3D
	var affected := decision["affected"] as PerspectivePlayer3D
	var restart_id: String = decision["restart_id"]
	if restart_id == "play_on":
		if possessor == null or not possessor.active:
			_set_possession(possession_team_id, _first_active_player(possession_team_id))
		return

	var awarded_team: int = int(decision.get("awarded_team_id", -1))
	if awarded_team not in [0, 1]:
		awarded_team = possession_team_id
		if affected != null and affected.active:
			awarded_team = affected.team_id
		elif offender != null:
			awarded_team = 1 - offender.team_id
	if restart_id == "kick_off":
		awarded_team = 1 - possession_team_id
		_kickoff_for(awarded_team)
		return
	if restart_id == "penalty_kick":
		_penalty_for(awarded_team, affected)
		return
	var restart_player: PerspectivePlayer3D = (
		affected
		if affected != null and affected.active and affected.team_id == awarded_team
		else _nearest_active_teammate(awarded_team, whistle_position)
	)
	if restart_player == null:
		restart_player = _first_active_player(awarded_team)
	if restart_player != null:
		var restart_position := FOOTBALL_LAWS.clamp_inside_pitch(
			Vector3(whistle_position.x, 0.0, whistle_position.z)
		)
		restart_player.global_position = restart_position
		_enforce_restart_distance(
			awarded_team,
			restart_position,
			FOOTBALL_LAWS.CENTER_CIRCLE_RADIUS
		)
		_set_possession(awarded_team, restart_player)
		ball.global_position = restart_position + Vector3(
			0.0,
			BALL_RADIUS,
			0.0
		)
		_update_ball_shadow()


func _kickoff_for(team_id: int) -> void:
	_prepare_kickoff(team_id)
	_take_prepared_kickoff()


func _prepare_kickoff(team_id: int) -> void:
	for assistant in assistants:
		assistant.clear_signal()
	hud.hide_assistant_signal()
	for player in perspective_players:
		if not player.active:
			continue
		var home: Vector3 = player.get_meta("home_position")
		player.global_position = home
		player.freeze_actor()
	var kickoff_player := _find_player(team_id, 9)
	if kickoff_player == null or not kickoff_player.active:
		kickoff_player = _first_active_player(team_id)
	if kickoff_player == null:
		return
	var own_sign := FOOTBALL_LAWS.own_half_sign(team_id, second_half)
	kickoff_player.global_position = Vector3(
		0.0,
		0.0,
		own_sign * 0.82
	)
	_enforce_kickoff_positions(team_id)
	_set_possession(team_id, kickoff_player)
	ball.global_position = Vector3(0.0, BALL_RADIUS, 0.0)
	_update_ball_shadow()
	ball_in_flight = false
	pending_action = ""
	pending_receiver = null
	pending_offside = false


func _take_prepared_kickoff() -> void:
	if possessor == null or not possessor.active:
		return
	var kicking_team := possession_team_id
	var kicker := possessor
	var receiver := _find_player(kicking_team, 10)
	if receiver == null or not receiver.active or receiver == kicker:
		for candidate in _active_team(kicking_team):
			if candidate != kicker and not bool(
				candidate.get_meta("goalkeeper", false)
			):
				receiver = candidate
				break
	if receiver == null:
		return
	kicker.freeze_actor()
	pending_receiver = receiver
	pending_shooter = null
	pending_offside = false
	pending_action = "pass"
	possessor = null
	_start_ball_flight(
		receiver.global_position + Vector3(0.0, BALL_RADIUS, 0.0),
		0.68,
		0.16,
		0.0
	)


func _goal_kick_for(defending_team_id: int) -> void:
	var goalkeeper := _find_player(defending_team_id, 1)
	if goalkeeper == null or not goalkeeper.active:
		goalkeeper = _first_active_player(defending_team_id)
	if goalkeeper == null:
		return
	var own_sign := FOOTBALL_LAWS.own_half_sign(
		defending_team_id,
		second_half
	)
	goalkeeper.global_position = Vector3(0.0, 0.0, own_sign * 47.0)
	_enforce_opponents_outside_penalty_area(defending_team_id)
	_set_possession(defending_team_id, goalkeeper)
	ball.global_position = goalkeeper.global_position + Vector3(
		0.0,
		BALL_RADIUS,
		0.0
	)
	_update_ball_shadow()
	var receiver := _find_player(defending_team_id, 3)
	if receiver != null and receiver.active and receiver != goalkeeper:
		goalkeeper.freeze_actor()
		pending_receiver = receiver
		pending_shooter = null
		pending_offside = false
		pending_action = "pass"
		possessor = null
		_start_ball_flight(
			receiver.global_position + Vector3(0.0, BALL_RADIUS, 0.0),
			0.78,
			0.28,
			0.0
		)
	hud.set_phase("Coup de pied de but")


func _penalty_for(
	awarded_team_id: int,
	preferred_taker: PerspectivePlayer3D
) -> void:
	var defending_team_id := 1 - awarded_team_id
	var defending_sign := FOOTBALL_LAWS.own_half_sign(
		defending_team_id,
		second_half
	)
	var penalty_mark := Vector3(0.0, 0.0, defending_sign * 41.5)
	var taker := preferred_taker
	if taker == null or not taker.active or taker.team_id != awarded_team_id:
		taker = _find_player(awarded_team_id, 9)
	if taker == null or not taker.active:
		taker = _first_active_player(awarded_team_id)
	if taker == null:
		return
	var goalkeeper := _find_player(defending_team_id, 1)
	if goalkeeper != null and goalkeeper.active:
		goalkeeper.global_position = Vector3(
			0.0,
			0.0,
			defending_sign * 52.25
		)
	for player in perspective_players:
		if not player.active or player == taker or player == goalkeeper:
			continue
		var safe_z := defending_sign * 31.8
		if player.global_position.z * defending_sign > 31.8:
			player.global_position.z = safe_z
		if player.global_position.distance_to(penalty_mark) < 9.15:
			player.global_position.x = (
				-10.0 if player.shirt_number % 2 == 0 else 10.0
			)
			player.global_position.z = safe_z
	taker.global_position = penalty_mark - Vector3(
		0.0,
		0.0,
		_attack_direction(awarded_team_id) * 0.8
	)
	_set_possession(awarded_team_id, taker)
	ball.global_position = penalty_mark + Vector3(0.0, BALL_RADIUS, 0.0)
	_update_ball_shadow()
	_start_shot()
	hud.set_phase("Penalty frappé · joueurs hors de la surface")


func _enforce_kickoff_positions(kicking_team_id: int) -> void:
	for player in perspective_players:
		if not player.active:
			continue
		if player.team_id == kicking_team_id:
			continue
		var flat := Vector2(
			player.global_position.x,
			player.global_position.z
		)
		if flat.length() < FOOTBALL_LAWS.CENTER_CIRCLE_RADIUS + 0.25:
			var direction := flat.normalized()
			if direction.is_zero_approx():
				direction = Vector2(
					0.0,
					FOOTBALL_LAWS.own_half_sign(
						player.team_id,
						second_half
					)
				)
			var legal_position := direction * (
				FOOTBALL_LAWS.CENTER_CIRCLE_RADIUS + 0.25
			)
			player.global_position.x = legal_position.x
			player.global_position.z = legal_position.y


func _enforce_restart_distance(
	awarded_team_id: int,
	restart_position: Vector3,
	minimum_distance: float
) -> void:
	for opponent in _active_team(1 - awarded_team_id):
		var offset := opponent.global_position - restart_position
		offset.y = 0.0
		if offset.length() >= minimum_distance:
			continue
		if offset.is_zero_approx():
			offset = Vector3(1.0, 0.0, 0.0)
		var legal_position := restart_position + (
			offset.normalized() * (minimum_distance + 0.2)
		)
		opponent.global_position = FOOTBALL_LAWS.clamp_inside_pitch(
			Vector3(legal_position.x, 0.0, legal_position.z)
		)


func _enforce_opponents_outside_penalty_area(
	defending_team_id: int
) -> void:
	var own_sign := FOOTBALL_LAWS.own_half_sign(
		defending_team_id,
		second_half
	)
	for opponent in _active_team(1 - defending_team_id):
		if FOOTBALL_LAWS.is_penalty_area(
			opponent.global_position,
			defending_team_id,
			second_half
		):
			opponent.global_position.z = own_sign * 35.7


func _set_possession(team_id: int, player: PerspectivePlayer3D) -> void:
	if player == null:
		return
	possession_team_id = team_id
	possessor = player
	ball_in_flight = false
	pending_action = ""


func _update_team_shapes() -> void:
	var ball_reference: Vector3 = (
		ball.global_position
		if ball_in_flight or possessor == null
		else possessor.global_position
	)
	for player in perspective_players:
		if (
			not player.active
			or player == possessor
			or player == pending_receiver
			or protest_timer > 0.0 and player in protest_players
		):
			continue
		var home: Vector3 = player.get_meta("home_position")
		var team_has_ball: bool = player.team_id == possession_team_id
		var z_influence: float = ball_reference.z * (0.23 if team_has_ball else 0.17)
		var x_influence: float = ball_reference.x * 0.12
		var target: Vector3 = Vector3(
			clampf(home.x + x_influence, -29.0, 29.0),
			0.0,
			clampf(home.z + z_influence, -48.0, 48.0)
		)
		player.move_to(target, 2.25 if team_has_ball else 2.65)


func _update_assistants() -> void:
	var line_z: float = _offside_line_for(possession_team_id)
	for assistant in assistants:
		assistant.follow_offside_line(line_z)
	if not assistants.any(
		func(assistant: AssistantReferee3D) -> bool:
			return assistant.is_flag_raised()
	):
		hud.hide_assistant_signal()


func _offside_line_for(attacking_team_id: int) -> float:
	var defenders: Array[PerspectivePlayer3D] = _active_team(1 - attacking_team_id)
	if defenders.size() < 2:
		return 0.0
	var attack_direction := _attack_direction(attacking_team_id)
	defenders.sort_custom(
		func(a: PerspectivePlayer3D, b: PerspectivePlayer3D) -> bool:
			return (
				a.global_position.z * attack_direction
				> b.global_position.z * attack_direction
			)
	)
	return defenders[1].global_position.z


func _is_offside(
	receiver: PerspectivePlayer3D,
	attacking_team_id: int,
	line_z: float
) -> bool:
	return FOOTBALL_LAWS.is_offside_position(
		receiver.global_position,
		ball.global_position,
		line_z,
		attacking_team_id,
		second_half
	)


func _capture_observation(
	target_position: Vector3,
	offender: PerspectivePlayer3D = null,
	affected: PerspectivePlayer3D = null
) -> Dictionary:
	var target: Vector3 = target_position + Vector3(0.0, 0.48, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		referee.camera_position(),
		target,
		2
	)
	var exclusions: Array[RID] = []
	if offender != null:
		exclusions.append(offender.get_rid())
	if affected != null:
		exclusions.append(affected.get_rid())
	query.exclude = exclusions
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var occluded: bool = (
		not hit.is_empty()
		and hit["collider"] is PerspectivePlayer3D
	)
	return PerspectiveObservationModel.evaluate(
		referee.camera_position(),
		referee.camera_forward(),
		target,
		occluded
	)


func _observation_summary(observation: Dictionary, assistant_signal: bool) -> String:
	var signal_line: String = (
		"\nUn assistant est visible avec le drapeau levé."
		if assistant_signal
		else ""
	)
	return (
		"%s · action à %.0f m · %.0f° hors axe%s.%s"
		% [
			observation["label"],
			observation["distance_meters"],
			observation["view_angle_degrees"],
			" · joueurs dans la ligne de vue" if observation["is_occluded"] else "",
			signal_line,
		]
	)


func _players_near_ball(limit: int) -> Array[PerspectivePlayer3D]:
	var candidates: Array[PerspectivePlayer3D] = []
	for player in perspective_players:
		if player.active:
			candidates.append(player)
	candidates.sort_custom(
		func(a: PerspectivePlayer3D, b: PerspectivePlayer3D) -> bool:
			return (
				a.global_position.distance_squared_to(ball.global_position)
				< b.global_position.distance_squared_to(ball.global_position)
			)
	)
	var result: Array[PerspectivePlayer3D] = []
	for index in range(mini(limit, candidates.size())):
		result.append(candidates[index])
	return result


func _nearest_active_opponent(
	team_id: int,
	position: Vector3
) -> PerspectivePlayer3D:
	var nearest: PerspectivePlayer3D
	var nearest_distance: float = INF
	for player in _active_team(1 - team_id):
		var distance: float = player.global_position.distance_squared_to(position)
		if distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	return nearest


func _nearest_active_teammate(
	team_id: int,
	position: Vector3
) -> PerspectivePlayer3D:
	var nearest: PerspectivePlayer3D
	var nearest_distance: float = INF
	for player in _active_team(team_id):
		var distance: float = player.global_position.distance_squared_to(position)
		if distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	return nearest


func _active_team(team_id: int) -> Array[PerspectivePlayer3D]:
	var team: Array[PerspectivePlayer3D] = blue_team if team_id == 0 else red_team
	var active: Array[PerspectivePlayer3D] = []
	for player in team:
		if player.active:
			active.append(player)
	return active


func _first_active_player(team_id: int) -> PerspectivePlayer3D:
	var active: Array[PerspectivePlayer3D] = _active_team(team_id)
	return active[0] if not active.is_empty() else null


func _find_player(team_id: int, number: int) -> PerspectivePlayer3D:
	var team: Array[PerspectivePlayer3D] = blue_team if team_id == 0 else red_team
	for player in team:
		if player.shirt_number == number:
			return player
	return null


func _attack_direction(team_id: int) -> float:
	return FOOTBALL_LAWS.attack_direction(team_id, second_half)


func _is_penalty_area(position: Vector3, defending_team_id: int) -> bool:
	return FOOTBALL_LAWS.is_penalty_area(
		position,
		defending_team_id,
		second_half
	)


func _update_live_reading() -> void:
	if phase == Phase.STOPPED_FOR_DECISION or phase == Phase.RESULTS:
		return
	var offset := ball.global_position - referee.camera_position()
	var flat_offset := Vector3(offset.x, 0.0, offset.z)
	if flat_offset.is_zero_approx():
		return
	var flat_forward := Vector3(
		referee.camera_forward().x,
		0.0,
		referee.camera_forward().z
	).normalized()
	var angle := rad_to_deg(
		acos(clampf(flat_forward.dot(flat_offset.normalized()), -1.0, 1.0))
	)
	var signed_angle := rad_to_deg(
		flat_forward.signed_angle_to(
			flat_offset.normalized(),
			Vector3.UP
		)
	)
	hud.set_live_reading(offset.length(), angle, angle <= 38.0)
	hud.set_ball_direction(offset.length(), signed_angle)
	if ball_marker != null:
		ball_marker.global_position = ball.global_position + Vector3(
			0.0,
			1.05 + sin(match_elapsed * 5.0) * 0.08,
			0.0
		)


func _update_inspection_target() -> void:
	if phase != Phase.STOPPED_FOR_DECISION:
		return
	var camera_position := referee.camera_position()
	var camera_forward := referee.camera_forward().normalized()
	var query := PhysicsRayQueryParameters3D.create(
		camera_position,
		camera_position + camera_forward * 42.0,
		2
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var next_target := (
		hit.get("collider") as PerspectivePlayer3D
		if not hit.is_empty()
		else null
	)
	if next_target == null:
		var best_score := -INF
		for player in perspective_players:
			if not player.active:
				continue
			var player_center := player.global_position + Vector3(0.0, 1.15, 0.0)
			var offset := player_center - camera_position
			var distance := offset.length()
			if distance > 32.0 or distance <= 0.01:
				continue
			var alignment := camera_forward.dot(offset / distance)
			if alignment < 0.965:
				continue
			var score := alignment - distance * 0.0015
			if score > best_score:
				best_score = score
				next_target = player

	inspection_target = next_target
	var identified := officiating_panel.selected_player()
	for player in perspective_players:
		player.set_inspection_highlight(
			player == inspection_target,
			player == identified
		)
	officiating_panel.set_look_target(inspection_target)


func _clear_inspection_highlights() -> void:
	inspection_target = null
	for player in perspective_players:
		player.set_inspection_highlight(false, false)


func _update_clock() -> void:
	var minute := floori(match_elapsed / MATCH_REAL_DURATION * 90.0)
	hud.set_match_state(minute, blue_score, red_score)


func _finish_match(reason: String = "") -> void:
	if phase == Phase.RESULTS:
		return
	phase = Phase.RESULTS
	phase_elapsed = 0.0
	match_end_reason = reason
	for player in perspective_players:
		player.freeze_actor()
		player.set_physics_process(false)
	for assistant in assistants:
		assistant.set_process(false)
	_clear_inspection_highlights()
	_clear_var_signal()
	referee.set_input_enabled(false)
	officiating_panel.hide_panel()
	hud.hide_assistant_signal()
	hud.hide_incident()
	hud.set_phase("COUP DE SIFFLET FINAL")
	hud.set_objective(
		reason
		if not reason.is_empty()
		else "Le rapport résume l’état émotionnel du match, pas une note d’arbitrage."
	)
	results_panel.show_result(_aggregate_match_result())


func _aggregate_match_result() -> Dictionary:
	var final_state := MatchIntensityModel.control_state(
		blue_tension,
		red_tension
	)
	var peak_state := MatchIntensityModel.control_state(
		blue_peak_tension,
		red_peak_tension
	)
	var outcome := "MATCH MAÎTRISÉ"
	if peak_state["id"] in ["heated", "hostile"]:
		outcome = "MATCH SOUS PRESSION"
	elif peak_state["id"] == "chaos":
		outcome = "MATCH HORS DE CONTRÔLE"
	if not match_end_reason.is_empty():
		outcome = "MATCH INTERROMPU"

	return {
		"tension_mode": true,
		"outcome": outcome,
		"blue_tension": roundi(blue_tension),
		"red_tension": roundi(red_tension),
		"blue_peak_tension": roundi(blue_peak_tension),
		"red_peak_tension": roundi(red_peak_tension),
		"importance_label": match_profile["label"],
		"feedback": PackedStringArray([
			"%d décision(s) appliquée(s)." % decisions.size(),
			"%d événement(s) pertinent(s) non traité(s)." % missed_events,
			"Score sportif : %s %d — %d Visiteurs." % [
				stadium_profile["short_name"],
				blue_score,
				red_score,
			],
			(
				match_end_reason
				if not match_end_reason.is_empty()
				else "État final : %s." % final_state["description"]
			),
		]),
		"explanation": (
			"Les mauvaises décisions, les sanctions incohérentes et les actions ignorées "
			+ "font monter la tension. L’enjeu choisi amplifie les réactions et ralentit "
			+ "le retour au calme."
		),
	}


func _request_main_menu() -> void:
	referee.set_input_enabled(false)
	main_menu_requested.emit()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "StadiumEnvironment"
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(stadium_profile["sky_top"])
	sky_material.sky_horizon_color = Color(stadium_profile["sky_horizon"])
	sky_material.ground_horizon_color = Color(
		stadium_profile["ground_horizon"]
	)
	sky_material.ground_bottom_color = Color(stadium_profile["ground_bottom"])
	sky_material.sun_angle_max = 12.0
	sky_material.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(stadium_profile["ambient_color"])
	environment.ambient_light_energy = float(
		stadium_profile["ambient_energy"]
	)
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.9
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.03
	environment.adjustment_saturation = 0.96
	world_environment.environment = environment
	world_root.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "MatchSun"
	sun.rotation_degrees = stadium_profile["sun_rotation"]
	sun.light_color = Color(stadium_profile["sun_color"])
	sun.light_energy = float(stadium_profile["sun_energy"])
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 135.0
	world_root.add_child(sun)


func _build_pitch() -> void:
	var pitch_color := Color(stadium_profile["grass_base"])
	var stripe_color := Color(stadium_profile["grass_light"])
	var line_color := Color("#f7f8ee")
	_add_box(
		world_root,
		"Runoff",
		Vector3(82.0, 0.16, 119.0),
		Vector3(0.0, -0.18, 0.0),
		Color(stadium_profile["runoff_color"])
	)
	_add_box(world_root, "Pitch", Vector3(68.0, 0.18, 105.0),
		Vector3(0.0, -0.1, 0.0), pitch_color)
	for stripe_index in range(20):
		var stripe_tint := (
			stripe_color
			if stripe_index % 2 == 0
			else pitch_color.darkened(0.035)
		)
		_add_box(
			world_root,
			"MowingStripe%d" % stripe_index,
			Vector3(67.78, 0.012, 5.22),
			Vector3(
				0.0,
				-0.004,
				-52.5 + 2.625 + float(stripe_index) * 5.25
			),
			stripe_tint
		)
	_add_box(world_root, "TouchlineLeft", Vector3(0.13, 0.045, 105.0),
		Vector3(-34.0, 0.021, 0.0), line_color)
	_add_box(world_root, "TouchlineRight", Vector3(0.13, 0.045, 105.0),
		Vector3(34.0, 0.021, 0.0), line_color)
	_add_box(world_root, "GoalLineNorth", Vector3(68.0, 0.045, 0.13),
		Vector3(0.0, 0.021, -52.5), line_color)
	_add_box(world_root, "GoalLineSouth", Vector3(68.0, 0.045, 0.13),
		Vector3(0.0, 0.021, 52.5), line_color)
	_add_box(world_root, "HalfwayLine", Vector3(68.0, 0.045, 0.13),
		Vector3(0.0, 0.023, 0.0), line_color)
	_add_penalty_area(-1.0, line_color)
	_add_penalty_area(1.0, line_color)
	_add_goal(-1.0, line_color)
	_add_goal(1.0, line_color)
	_add_pitch_spot(Vector3(0.0, 0.0, 0.0), line_color, 0.15)
	_add_pitch_spot(Vector3(0.0, 0.0, -41.5), line_color, 0.13)
	_add_pitch_spot(Vector3(0.0, 0.0, 41.5), line_color, 0.13)

	var center_circle := MeshInstance3D.new()
	var circle_mesh := TorusMesh.new()
	circle_mesh.inner_radius = 9.05
	circle_mesh.outer_radius = 9.18
	circle_mesh.rings = 8
	circle_mesh.ring_segments = 96
	center_circle.mesh = circle_mesh
	center_circle.position.y = 0.04
	center_circle.material_override = _material(line_color, 0.58)
	world_root.add_child(center_circle)

	_build_pitch_arcs(line_color)
	_build_stadium_bowl()
	_build_corner_flags()
	_build_crowd_bands()


func _build_pitch_arcs(line_color: Color) -> void:
	_add_arc_segments(
		"PenaltyArcNorth",
		Vector3(0.0, 0.0, -41.5),
		9.15,
		37.0,
		143.0,
		18,
		line_color
	)
	_add_arc_segments(
		"PenaltyArcSouth",
		Vector3(0.0, 0.0, 41.5),
		9.15,
		217.0,
		323.0,
		18,
		line_color
	)
	var corner_data := [
		[Vector3(-34.0, 0.0, -52.5), 0.0, 90.0],
		[Vector3(34.0, 0.0, -52.5), 90.0, 180.0],
		[Vector3(34.0, 0.0, 52.5), 180.0, 270.0],
		[Vector3(-34.0, 0.0, 52.5), 270.0, 360.0],
	]
	for index in range(corner_data.size()):
		var data: Array = corner_data[index]
		_add_arc_segments(
			"CornerArc%d" % index,
			data[0],
			1.0,
			data[1],
			data[2],
			7,
			line_color
		)


func _add_arc_segments(
	arc_name: String,
	center: Vector3,
	radius: float,
	start_degrees: float,
	end_degrees: float,
	segment_count: int,
	color: Color
) -> void:
	for segment_index in range(segment_count):
		var start_angle := deg_to_rad(
			lerpf(
				start_degrees,
				end_degrees,
				float(segment_index) / float(segment_count)
			)
		)
		var end_angle := deg_to_rad(
			lerpf(
				start_degrees,
				end_degrees,
				float(segment_index + 1) / float(segment_count)
			)
		)
		var start_point := center + Vector3(
			cos(start_angle) * radius,
			0.0,
			sin(start_angle) * radius
		)
		var end_point := center + Vector3(
			cos(end_angle) * radius,
			0.0,
			sin(end_angle) * radius
		)
		var direction := end_point - start_point
		var segment := _add_box(
			world_root,
			"%s_%02d" % [arc_name, segment_index],
			Vector3(0.13, 0.04, direction.length() + 0.025),
			(start_point + end_point) * 0.5 + Vector3(0.0, 0.025, 0.0),
			color
		)
		segment.rotation.y = atan2(direction.x, direction.z)


func _build_stadium_bowl() -> void:
	var primary := Color(stadium_profile["primary_color"])
	var secondary := Color(stadium_profile["secondary_color"])
	var stand_color := Color(stadium_profile["stand_color"])
	var seat_color := Color(stadium_profile["seat_color"])
	for side in [-1.0, 1.0]:
		_build_side_stand(side, stand_color, seat_color, primary)
		_add_box(
			world_root,
			"AdvertisingBoardSide",
			Vector3(0.22, 0.92, 108.0),
			Vector3(side * 35.65, 0.46, 0.0),
			secondary if side < 0.0 else primary.lightened(0.12)
		)
	for end_sign in [-1.0, 1.0]:
		_build_end_stand(end_sign, stand_color, seat_color, primary)
		_add_box(
			world_root,
			"AdvertisingBoardEnd",
			Vector3(70.0, 0.92, 0.22),
			Vector3(0.0, 0.46, end_sign * 54.92),
			primary.lightened(0.08)
		)
	_build_stadium_lights(primary, secondary)
	_build_stadium_identity(primary, secondary)


func _build_side_stand(
	side: float,
	stand_color: Color,
	seat_color: Color,
	accent_color: Color
) -> void:
	var side_name := "East" if side > 0.0 else "West"
	for tier in range(8):
		var tier_height := 0.32 + float(tier) * 0.62
		var tier_x := side * (37.35 + float(tier) * 0.88)
		_add_box(
			world_root,
			"StandTierSide_%s_%02d" % [side_name, tier],
			Vector3(1.76, 0.56, 115.0),
			Vector3(tier_x, tier_height, 0.0),
			stand_color.lightened(float(tier) * 0.012)
		)
		_add_box(
			world_root,
			"SeatRowSide_%s_%02d" % [side_name, tier],
			Vector3(1.68, 0.12, 113.8),
			Vector3(
				tier_x - side * 0.06,
				tier_height + 0.34,
				0.0
			),
			seat_color.lightened(0.045 * float(tier % 3))
		)
	_add_box(
		world_root,
		"StandBackWallSide_%s" % side_name,
		Vector3(0.65, 7.2, 118.0),
		Vector3(side * 44.2, 3.45, 0.0),
		stand_color.darkened(0.16)
	)
	_add_box(
		world_root,
		"RoofSide_%s" % side_name,
		Vector3(9.6, 0.38, 119.0),
		Vector3(side * 41.0, 8.35, 0.0),
		stand_color.lightened(0.08)
	)
	_add_box(
		world_root,
		"RoofFasciaSide_%s" % side_name,
		Vector3(0.32, 1.05, 119.0),
		Vector3(side * 36.35, 7.98, 0.0),
		accent_color
	)
	for support_index in range(7):
		var support_z := -51.0 + float(support_index) * 17.0
		_add_box(
			world_root,
			"RoofSupportSide_%s_%02d" % [side_name, support_index],
			Vector3(0.28, 8.0, 0.28),
			Vector3(side * 44.0, 4.0, support_z),
			Color("#74808d")
		)


func _build_end_stand(
	end_sign: float,
	stand_color: Color,
	seat_color: Color,
	accent_color: Color
) -> void:
	var end_name := "South" if end_sign > 0.0 else "North"
	for tier in range(7):
		var tier_height := 0.32 + float(tier) * 0.62
		var tier_z := end_sign * (56.25 + float(tier) * 0.88)
		_add_box(
			world_root,
			"StandTierEnd_%s_%02d" % [end_name, tier],
			Vector3(75.0, 0.56, 1.76),
			Vector3(0.0, tier_height, tier_z),
			stand_color.lightened(float(tier) * 0.012)
		)
		_add_box(
			world_root,
			"SeatRowEnd_%s_%02d" % [end_name, tier],
			Vector3(73.8, 0.12, 1.68),
			Vector3(
				0.0,
				tier_height + 0.34,
				tier_z - end_sign * 0.06
			),
			seat_color.lightened(0.045 * float(tier % 3))
		)
	_add_box(
		world_root,
		"StandBackWallEnd_%s" % end_name,
		Vector3(78.0, 6.6, 0.65),
		Vector3(0.0, 3.15, end_sign * 62.0),
		stand_color.darkened(0.16)
	)
	_add_box(
		world_root,
		"RoofEnd_%s" % end_name,
		Vector3(79.0, 0.38, 8.8),
		Vector3(0.0, 7.75, end_sign * 58.5),
		stand_color.lightened(0.08)
	)
	_add_box(
		world_root,
		"RoofFasciaEnd_%s" % end_name,
		Vector3(79.0, 1.0, 0.32),
		Vector3(0.0, 7.42, end_sign * 54.25),
		accent_color.darkened(0.06)
	)


func _build_stadium_lights(primary: Color, secondary: Color) -> void:
	var floodlight_energy := float(stadium_profile["floodlight_energy"])
	var steel_material := _material(Color("#65717f"), 0.5)
	var lamp_material := _emissive_material(
		Color("#fff7dc"),
		2.8 + floodlight_energy
	)
	var light_index := 0
	for x in [-45.5, 45.5]:
		for z in [-60.5, 60.5]:
			_add_cylinder(
				world_root,
				"FloodlightTower_%02d" % light_index,
				0.22,
				18.0,
				Vector3(x, 9.0, z),
				steel_material
			)
			_add_box_with_material(
				world_root,
				"FloodlightLamp_%02d" % light_index,
				Vector3(4.6, 2.0, 0.35),
				Vector3(x, 17.3, z),
				lamp_material
			)
			if floodlight_energy > 0.1:
				var light := OmniLight3D.new()
				light.name = "StadiumFloodlight_%02d" % light_index
				light.position = Vector3(x, 16.2, z)
				light.light_color = (
					Color("#fff3d6")
					if x * z > 0.0
					else Color("#eaf2ff")
				)
				light.light_energy = floodlight_energy
				light.omni_range = 72.0
				light.shadow_enabled = false
				world_root.add_child(light)
			light_index += 1
	var ribbon_color := primary.lerp(secondary, 0.3)
	_add_box(
		world_root,
		"StadiumAccentRibbon",
		Vector3(82.0, 0.32, 0.36),
		Vector3(0.0, 6.75, -62.25),
		ribbon_color
	)


func _build_stadium_identity(primary: Color, secondary: Color) -> void:
	var scoreboard_back := _add_box(
		world_root,
		"StadiumScoreboard",
		Vector3(16.0, 5.2, 0.45),
		Vector3(0.0, 10.7, -62.5),
		Color("#07111f")
	)
	scoreboard_back.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	var stadium_label := Label3D.new()
	stadium_label.name = "StadiumIdentity"
	stadium_label.text = "%s\n%s" % [
		stadium_profile["home_team"].to_upper(),
		stadium_profile["stadium_name"].to_upper(),
	]
	stadium_label.font_size = 44
	stadium_label.outline_size = 8
	stadium_label.modulate = secondary
	stadium_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	stadium_label.fixed_size = false
	stadium_label.pixel_size = 0.045
	stadium_label.position = Vector3(0.0, 10.7, -62.2)
	world_root.add_child(stadium_label)
	for side in [-1.0, 1.0]:
		_add_box(
			world_root,
			"ClubBanner",
			Vector3(0.3, 2.8, 22.0),
			Vector3(side * 36.15, 5.6, 0.0),
			primary if side < 0.0 else secondary
		)


func _add_penalty_area(end_sign: float, color: Color) -> void:
	var z_goal := end_sign * 52.5
	var z_inner := end_sign * 36.0
	_add_box(world_root, "PenaltyAreaFront", Vector3(40.3, 0.035, 0.13),
		Vector3(0.0, 0.02, z_inner), color)
	for x in [-20.15, 20.15]:
		_add_box(world_root, "PenaltyAreaSide", Vector3(0.13, 0.035, 16.5),
			Vector3(x, 0.02, (z_goal + z_inner) * 0.5), color)
	var goal_area_inner := end_sign * 47.0
	_add_box(
		world_root,
		"GoalAreaFront",
		Vector3(18.32, 0.035, 0.13),
		Vector3(0.0, 0.02, goal_area_inner),
		color
	)
	for x in [-9.16, 9.16]:
		_add_box(
			world_root,
			"GoalAreaSide",
			Vector3(0.13, 0.035, 5.5),
			Vector3(x, 0.02, (z_goal + goal_area_inner) * 0.5),
			color
		)


func _add_goal(end_sign: float, color: Color) -> void:
	var goal_z := end_sign * 53.1
	var net_depth := 2.15
	var back_z := goal_z + end_sign * net_depth
	for x in [-3.66, 3.66]:
		_add_box(world_root, "GoalPost", Vector3(0.13, 2.44, 0.13),
			Vector3(x, 1.22, goal_z), color)
		_add_box(world_root, "GoalBackPost", Vector3(0.07, 2.1, 0.07),
			Vector3(x, 1.05, back_z), Color("#cad7df"))
		_add_box(
			world_root,
			"GoalRoofSupport",
			Vector3(0.07, 0.07, net_depth),
			Vector3(x, 2.42, (goal_z + back_z) * 0.5),
			Color("#cad7df")
		)
	_add_box(world_root, "GoalCrossbar", Vector3(7.45, 0.13, 0.13),
		Vector3(0.0, 2.44, goal_z), color)
	var net_material := _transparent_material(Color(0.86, 0.92, 0.95, 0.52))
	for x_index in range(7):
		var x := -3.66 + float(x_index) * 1.22
		_add_box_with_material(
			world_root,
			"GoalNetVertical_%s_%d" % [
				"South" if end_sign > 0.0 else "North",
				x_index,
			],
			Vector3(0.025, 2.3, 0.025),
			Vector3(x, 1.15, back_z),
			net_material
		)
	for y_index in range(6):
		var y := float(y_index) * 0.44
		_add_box_with_material(
			world_root,
			"GoalNetHorizontal_%s_%d" % [
				"South" if end_sign > 0.0 else "North",
				y_index,
			],
			Vector3(7.32, 0.025, 0.025),
			Vector3(0.0, y, back_z),
			net_material
		)
	for depth_index in range(5):
		var z := lerpf(goal_z, back_z, float(depth_index) / 4.0)
		_add_box_with_material(
			world_root,
			"GoalRoofNet_%s_%d" % [
				"South" if end_sign > 0.0 else "North",
				depth_index,
			],
			Vector3(7.32, 0.025, 0.025),
			Vector3(0.0, 2.42, z),
			net_material
		)


func _add_pitch_spot(
	spot_position: Vector3,
	color: Color,
	radius: float
) -> void:
	var spot := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.025
	spot.mesh = mesh
	spot.position = Vector3(spot_position.x, 0.025, spot_position.z)
	spot.material_override = _material(color, 0.72)
	world_root.add_child(spot)


func _build_corner_flags() -> void:
	var pole_material := _material(Color("#f5f5f4"), 0.55)
	var flag_material := _material(Color("#f97316"), 0.64)
	for x in [-34.0, 34.0]:
		for z in [-52.5, 52.5]:
			_add_cylinder(
				world_root,
				"CornerPole",
				0.035,
				1.45,
				Vector3(x, 0.725, z),
				pole_material
			)
			_add_box_with_material(
				world_root,
				"CornerFlag",
				Vector3(0.48, 0.3, 0.025),
				Vector3(x + (0.24 if x < 0.0 else -0.24), 1.25, z),
				flag_material
			)


func _build_crowd_bands() -> void:
	var primary := Color(stadium_profile["primary_color"])
	var secondary := Color(stadium_profile["secondary_color"])
	var colors := [
		primary.lightened(0.26),
		secondary,
		Color("#e9eef5"),
		primary.lightened(0.08),
		secondary.darkened(0.12),
		Color("#b9c4d0"),
		primary.lightened(0.18),
	]
	for row in range(7):
		var y := 0.78 + float(row) * 0.62
		var row_color: Color = colors[row]
		for side in [-1.0, 1.0]:
			_add_box(
				world_root,
				"CrowdBand",
				Vector3(0.2, 0.3, 105.0),
				Vector3(side * (37.0 + float(row) * 0.88), y, 0.0),
				row_color.darkened(0.06 * float(row % 2))
			)
		for end in [-1.0, 1.0]:
			_add_box(
				world_root,
				"CrowdBand",
				Vector3(67.0, 0.3, 0.2),
				Vector3(0.0, y, end * (56.0 + float(row) * 0.88)),
				row_color.darkened(0.06 * float((row + 1) % 2))
			)


func _build_teams() -> void:
	var home_color := Color(stadium_profile["primary_color"])
	var away_color := Color(stadium_profile["away_color"])
	var blue_positions := [
		[1, "Gardien bleu", Vector3(0.0, 0.0, 47.0), true],
		[2, "Bleu 2", Vector3(-24.0, 0.0, 31.0), false],
		[3, "Bleu 3", Vector3(-8.0, 0.0, 33.0), false],
		[4, "Bleu 4", Vector3(8.0, 0.0, 33.0), false],
		[5, "Bleu 5", Vector3(24.0, 0.0, 31.0), false],
		[6, "Bleu 6", Vector3(-13.0, 0.0, 14.0), false],
		[8, "Bleu 8", Vector3(12.0, 0.0, 13.0), false],
		[10, "Bleu 10", Vector3(0.0, 0.0, 7.0), false],
		[7, "Bleu 7", Vector3(-22.0, 0.0, 8.0), false],
		[9, "Bleu 9", Vector3(0.0, 0.0, 3.5), false],
		[11, "Bleu 11", Vector3(22.0, 0.0, 8.0), false],
	]
	var red_positions := [
		[1, "Gardien rouge", Vector3(0.0, 0.0, -47.0), true],
		[2, "Rouge 2", Vector3(24.0, 0.0, -31.0), false],
		[3, "Rouge 3", Vector3(8.0, 0.0, -33.0), false],
		[4, "Rouge 4", Vector3(-8.0, 0.0, -33.0), false],
		[5, "Rouge 5", Vector3(-24.0, 0.0, -31.0), false],
		[6, "Rouge 6", Vector3(13.0, 0.0, -14.0), false],
		[8, "Rouge 8", Vector3(-12.0, 0.0, -13.0), false],
		[10, "Rouge 10", Vector3(0.0, 0.0, -7.0), false],
		[7, "Rouge 7", Vector3(22.0, 0.0, -8.0), false],
		[9, "Rouge 9", Vector3(0.0, 0.0, -3.5), false],
		[11, "Rouge 11", Vector3(-22.0, 0.0, -8.0), false],
	]
	for data in blue_positions:
		blue_team.append(_spawn_player(
			data[1], home_color, data[0], 0, data[2], data[3]
		))
	for data in red_positions:
		red_team.append(_spawn_player(
			data[1], away_color, data[0], 1, data[2], data[3]
		))


func _spawn_player(
	player_name: String,
	color: Color,
	number: int,
	team_id: int,
	start_position: Vector3,
	is_goalkeeper: bool
) -> PerspectivePlayer3D:
	var player := PLAYER_SCRIPT.new() as PerspectivePlayer3D
	actors_root.add_child(player)
	player.setup(player_name, color, number, team_id, is_goalkeeper)
	player.global_position = start_position
	player.set_meta("home_position", start_position)
	player.set_meta("first_half_home_position", start_position)
	player.set_meta(
		"team_label",
		stadium_profile["short_name"] if team_id == 0 else "VISITEURS"
	)
	player.set_meta("goalkeeper", is_goalkeeper)
	perspective_players.append(player)
	return player


func _build_assistants() -> void:
	for side in [-1.0, 1.0]:
		var assistant := ASSISTANT_SCRIPT.new() as AssistantReferee3D
		world_root.add_child(assistant)
		assistant.setup(side)
		assistants.append(assistant)


func _build_ball() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	sphere.radial_segments = 24
	sphere.rings = 16
	ball.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#f8fafc")
	material.metallic = 0.05
	material.roughness = 0.72
	ball.material_override = material
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var patch_material := _material(Color("#172033"), 0.66)
	for patch_direction in [
		Vector3.RIGHT,
		Vector3.LEFT,
		Vector3.UP,
		Vector3.DOWN,
		Vector3.FORWARD,
		Vector3.BACK,
	]:
		var patch := MeshInstance3D.new()
		var patch_mesh := SphereMesh.new()
		patch_mesh.radius = 0.045
		patch_mesh.height = 0.09
		patch.mesh = patch_mesh
		patch.position = patch_direction * (BALL_RADIUS - 0.012)
		patch.material_override = patch_material
		ball.add_child(patch)

	ball_shadow = MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.27
	shadow_mesh.bottom_radius = 0.27
	shadow_mesh.height = 0.012
	ball_shadow.mesh = shadow_mesh
	ball_shadow.material_override = _transparent_material(
		Color(0.02, 0.04, 0.03, 0.34)
	)
	world_root.add_child(ball_shadow)
	ball_marker = Label3D.new()
	ball_marker.text = "BALLON"
	ball_marker.font_size = 18
	ball_marker.outline_size = 5
	ball_marker.modulate = Color("#facc15")
	ball_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ball_marker.no_depth_test = true
	ball_marker.fixed_size = true
	ball_marker.pixel_size = 0.0014
	add_child(ball_marker)
	_update_ball_shadow()


func _build_restart_marker() -> void:
	restart_marker = MeshInstance3D.new()
	restart_marker.name = "RestartLocationMarker"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.52
	ring.outer_radius = 0.66
	ring.rings = 40
	ring.ring_segments = 10
	restart_marker.mesh = ring
	restart_marker.material_override = _transparent_material(
		Color(0.96, 0.78, 0.3, 0.86)
	)
	restart_marker.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	world_root.add_child(restart_marker)

	restart_marker_label = Label3D.new()
	restart_marker_label.text = "REPRISE"
	restart_marker_label.font_size = 17
	restart_marker_label.outline_size = 5
	restart_marker_label.modulate = Color("#f4d78f")
	restart_marker_label.position = Vector3(0.0, 0.46, 0.0)
	restart_marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	restart_marker_label.no_depth_test = true
	restart_marker_label.fixed_size = true
	restart_marker_label.pixel_size = 0.00135
	restart_marker.add_child(restart_marker_label)
	_hide_restart_marker()


func _show_restart_marker(position: Vector3) -> void:
	if restart_marker == null:
		return
	restart_marker.global_position = Vector3(position.x, 0.035, position.z)
	restart_marker.visible = true


func _hide_restart_marker() -> void:
	if restart_marker != null:
		restart_marker.visible = false


func _restart_location_label(position: Vector3) -> String:
	var lane := (
		"couloir gauche"
		if position.x < -9.0
		else "couloir droit"
		if position.x > 9.0
		else "axe"
	)
	return "Lieu mémorisé · %s · %.0f m du centre" % [
		lane,
		Vector2(position.x, position.z).length(),
	]


func _roll_ball(displacement: Vector3) -> void:
	var flat_displacement := Vector3(displacement.x, 0.0, displacement.z)
	var distance := flat_displacement.length()
	if distance <= 0.0001:
		return
	var axis := Vector3.UP.cross(flat_displacement.normalized())
	ball.rotate(axis, distance / BALL_RADIUS)


func _update_ball_shadow() -> void:
	if ball_shadow == null:
		return
	ball_shadow.global_position = Vector3(
		ball.global_position.x,
		0.018,
		ball.global_position.z
	)
	var height_scale := clampf(
		1.0 + (ball.global_position.y - BALL_RADIUS) * 0.12,
		1.0,
		1.55
	)
	ball_shadow.scale = Vector3(height_scale, 1.0, height_scale)


func _add_box(
	parent: Node3D,
	box_name: String,
	size: Vector3,
	box_position: Vector3,
	color: Color
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.name = box_name
	mesh_instance.mesh = mesh
	mesh_instance.position = box_position
	mesh_instance.material_override = _material(color, 0.82)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_box_with_material(
	parent: Node3D,
	box_name: String,
	size: Vector3,
	box_position: Vector3,
	material: Material
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.name = box_name
	mesh_instance.mesh = mesh
	mesh_instance.position = box_position
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_cylinder(
	parent: Node3D,
	cylinder_name: String,
	radius: float,
	height: float,
	cylinder_position: Vector3,
	material: Material
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.name = cylinder_name
	mesh_instance.mesh = mesh
	mesh_instance.position = cylinder_position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _emissive_material(
	color: Color,
	energy_multiplier: float
) -> StandardMaterial3D:
	var material := _material(color, 0.32)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy_multiplier
	return material


func _transparent_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
