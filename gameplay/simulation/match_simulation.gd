extends Node
class_name MatchSimulation

signal score_changed(blue_score: int, red_score: int)
signal event_announced(text: String)
signal foul_committed(
	position: Vector2,
	fouled_team_id: int,
	offender: DemoPlayer
)

@onready var blue_team: FootballTeam = $"../BlueTeam"
@onready var red_team: FootballTeam = $"../RedTeam"
@onready var ball: MatchBall = $"../MatchBall"
@onready var rules: FootballRulesEngine = $"../FootballRulesEngine"

var blue_score: int = 0
var red_score: int = 0
var is_running: bool = false
var possession_team: FootballTeam
var possessor: DemoPlayer
var last_touch_team: FootballTeam
var last_fouled_team: FootballTeam
var last_offender: DemoPlayer

var action_timer: float = 0.0
var shape_timer: float = 0.0
var tackle_cooldown: float = 0.0
var incident_timer: float = 0.0
var pending_shot: bool = false
var shot_will_score: bool = false
var pending_offside: bool = false
var pending_receiver: DemoPlayer

var random := RandomNumberGenerator.new()


func _ready() -> void:
	random.randomize()
	ball.travel_finished.connect(_on_ball_travel_finished)


func reset_match() -> void:
	is_running = false
	blue_score = 0
	red_score = 0
	blue_team.prepare_new_match()
	red_team.prepare_new_match()
	ball.reset_to(Vector2(640.0, 360.0))
	_set_possession(blue_team, blue_team.get_player_by_number(9))
	action_timer = 1.5
	shape_timer = 0.0
	tackle_cooldown = 1.5
	incident_timer = random.randf_range(18.0, 25.0)
	pending_shot = false
	pending_offside = false
	last_offender = null
	score_changed.emit(blue_score, red_score)


func start_match() -> void:
	is_running = true
	event_announced.emit("Coup d'envoi")


func pause_for_incident() -> void:
	is_running = false
	blue_team.stop_all()
	red_team.stop_all()


func resume_after_incident(foul_awarded: bool) -> void:
	if foul_awarded and last_fouled_team != null:
		_award_restart(
			FootballRulesEngine.RestartType.DIRECT_FREE_KICK,
			last_fouled_team,
			ball.global_position
		)
	else:
		if is_instance_valid(possessor):
			_set_possession(possession_team, possessor)
		event_announced.emit("Le jeu se poursuit")

	incident_timer = random.randf_range(24.0, 36.0)
	action_timer = 1.2
	tackle_cooldown = 2.0
	is_running = true


func apply_referee_discipline(
	discipline_choice: IncidentData.DisciplineDecision
) -> void:
	if not is_instance_valid(last_offender):
		return
	var offender_team := blue_team if last_offender.team_id == blue_team.team_id else red_team
	match discipline_choice:
		IncidentData.DisciplineDecision.YELLOW_CARD:
			var sent_off := offender_team.apply_yellow_card(last_offender)
			event_announced.emit(
				"Second avertissement : exclusion"
				if sent_off
				else "Carton jaune pour %s" % last_offender.display_name()
			)
		IncidentData.DisciplineDecision.RED_CARD:
			var offender_name := last_offender.display_name()
			offender_team.apply_red_card(last_offender)
			event_announced.emit("Carton rouge pour %s" % offender_name)


func make_automatic_substitutions() -> void:
	for team in [blue_team, red_team]:
		var excluded := possessor if possession_team == team else null
		if (
			excluded == null
			and is_instance_valid(pending_receiver)
			and pending_receiver.team_id == team.team_id
		):
			excluded = pending_receiver
		var change: Dictionary = team.make_automatic_substitution(excluded)
		if not change.is_empty():
			event_announced.emit(
				"%s : %s remplace %s" % [
					team.display_name,
					change["in"],
					change["out"],
				]
			)


func stop_match() -> void:
	pause_for_incident()
	ball.freeze_at(ball.global_position)


func scoreline() -> String:
	return "%s %d – %d %s" % [
		blue_team.display_name,
		blue_score,
		red_score,
		red_team.display_name,
	]


func _process(delta: float) -> void:
	if not is_running:
		return

	action_timer -= delta
	shape_timer -= delta
	tackle_cooldown -= delta
	incident_timer -= delta

	if shape_timer <= 0.0:
		_update_team_shapes()
		shape_timer = 0.24

	if possessor == null or not is_instance_valid(possessor) or ball.is_in_flight:
		return

	_move_ball_carrier()

	if _try_trigger_incident():
		return
	if _try_turnover():
		return
	if action_timer <= 0.0:
		_choose_next_action()


func _update_team_shapes() -> void:
	var defending_team := _opponent_of(possession_team)
	var pressing_player: DemoPlayer
	if is_instance_valid(possessor):
		pressing_player = defending_team.get_nearest_player(
			possessor.global_position,
			false
		)
	blue_team.publish_tactical_context(
		ball.global_position,
		possession_team == blue_team,
		possessor,
		pressing_player if defending_team == blue_team else null
	)
	red_team.publish_tactical_context(
		ball.global_position,
		possession_team == red_team,
		possessor,
		pressing_player if defending_team == red_team else null
	)


func _move_ball_carrier() -> void:
	var attack_direction := 1.0 if possession_team.attacks_right else -1.0
	var lane_y := lerpf(possessor.home_position.y, 360.0, 0.28)
	var destination := Vector2(
		clampf(possessor.global_position.x + attack_direction * 150.0, 90.0, 1190.0),
		clampf(lane_y, 105.0, 615.0)
	)
	possessor.move_to(destination, 108.0)


func _try_trigger_incident() -> bool:
	if incident_timer > 0.0:
		return false

	var defending_team := _opponent_of(possession_team)
	var pressing_player := defending_team.get_nearest_player(
		possessor.global_position,
		false
	)
	if (
		pressing_player == null
		or pressing_player.global_position.distance_to(possessor.global_position) > 72.0
	):
		return false

	last_fouled_team = possession_team
	last_offender = pressing_player
	pressing_player.global_position = possessor.global_position + Vector2(
		-18.0 if possession_team.attacks_right else 18.0,
		8.0
	)
	ball.freeze_at(possessor.global_position + Vector2(10.0, 7.0))
	pause_for_incident()
	event_announced.emit("Contact : %s intervient en retard" % pressing_player.display_name())
	foul_committed.emit(
		possessor.global_position,
		possession_team.team_id,
		pressing_player
	)
	return true


func _try_turnover() -> bool:
	if tackle_cooldown > 0.0:
		return false

	var defending_team := _opponent_of(possession_team)
	var pressing_player := defending_team.get_nearest_player(
		possessor.global_position,
		false
	)
	if (
		pressing_player == null
		or pressing_player.global_position.distance_to(possessor.global_position) > 29.0
	):
		return false

	tackle_cooldown = random.randf_range(2.5, 4.0)
	if random.randf() > 0.34:
		return false

	_set_possession(defending_team, pressing_player)
	action_timer = random.randf_range(0.9, 1.5)
	event_announced.emit(
		"Ballon récupéré par %s (%s)" % [
			defending_team.display_name,
			pressing_player.display_name(),
		]
	)
	return true


func _choose_next_action() -> void:
	var progress := _attacking_progress(possessor.global_position.x, possession_team)
	if progress >= 0.80 and random.randf() < 0.62:
		_shoot()
	else:
		_pass_ball()


func _pass_ball() -> void:
	var candidates: Array[DemoPlayer] = []
	var attack_direction := 1.0 if possession_team.attacks_right else -1.0

	for teammate in possession_team.players:
		if teammate == possessor or teammate.is_goalkeeper:
			continue
		var distance := teammate.global_position.distance_to(possessor.global_position)
		var progress_delta := (
			teammate.global_position.x - possessor.global_position.x
		) * attack_direction
		if distance >= 75.0 and distance <= 430.0 and progress_delta >= -85.0:
			candidates.append(teammate)

	if candidates.is_empty():
		for teammate in possession_team.players:
			if teammate != possessor:
				candidates.append(teammate)
	if candidates.is_empty():
		return

	candidates.sort_custom(
		func(a: DemoPlayer, b: DemoPlayer) -> bool:
			return (
				a.global_position.x * attack_direction
				> b.global_position.x * attack_direction
			)
	)
	var selection_limit := mini(candidates.size(), 4)
	var receiver := candidates[random.randi_range(0, selection_limit - 1)]
	var passer_name := possessor.display_name()

	pending_offside = rules.is_offside_position(
		receiver,
		possession_team,
		_opponent_of(possession_team),
		ball.global_position
	)
	pending_receiver = receiver
	last_touch_team = possession_team
	possessor.set_has_ball(false)
	possessor = null

	var destination := receiver.global_position + receiver.velocity * 0.28
	if random.randf() < 0.08:
		destination.y = 46.0 if random.randi_range(0, 1) == 0 else 674.0
	var duration := clampf(
		ball.global_position.distance_to(destination) / 430.0,
		0.45,
		1.15
	)
	ball.kick_to(destination, duration, receiver)
	event_announced.emit("Passe de %s" % passer_name)


func _shoot() -> void:
	var shooting_team := possession_team
	var attack_direction := 1.0 if shooting_team.attacks_right else -1.0
	var goal_x := 1224.0 if shooting_team.attacks_right else 56.0
	var distance_to_goal := absf(goal_x - possessor.global_position.x)
	var scoring_probability := clampf(0.58 - distance_to_goal / 720.0, 0.14, 0.52)
	shot_will_score = random.randf() < scoring_probability
	pending_shot = true
	last_touch_team = shooting_team

	var target_y := random.randf_range(320.0, 400.0)
	if not shot_will_score:
		target_y = 270.0 if random.randi_range(0, 1) == 0 else 450.0

	var shooter_name := possessor.display_name()
	possessor.set_has_ball(false)
	possessor = null
	ball.kick_to(Vector2(goal_x + attack_direction * 8.0, target_y), 0.62)
	event_announced.emit("Frappe de %s !" % shooter_name)


func _on_ball_travel_finished(intended_receiver: DemoPlayer) -> void:
	if pending_shot:
		pending_receiver = null
		_resolve_shot()
		return

	if rules.is_ball_out(ball.global_position):
		pending_offside = false
		pending_receiver = null
		var restart := rules.classify_ball_out(ball.global_position, last_touch_team)
		_award_restart(restart["type"], restart["team"], restart["position"])
		return

	if pending_offside:
		pending_offside = false
		var defending_team := _opponent_of(possession_team)
		var offence_position := (
			pending_receiver.global_position
			if is_instance_valid(pending_receiver)
			else ball.global_position
		)
		_award_restart(
			FootballRulesEngine.RestartType.INDIRECT_FREE_KICK,
			defending_team,
			offence_position
		)
		pending_receiver = null
		event_announced.emit("Hors-jeu : coup franc indirect")
		return

	if intended_receiver == null or not is_instance_valid(intended_receiver):
		pending_receiver = null
		return

	var opponent_team := _opponent_of(possession_team)
	var interceptor := opponent_team.get_nearest_player(ball.global_position, false)
	if (
		interceptor != null
		and interceptor.global_position.distance_to(ball.global_position) < 34.0
		and random.randf() < 0.46
	):
		_set_possession(opponent_team, interceptor)
		event_announced.emit("Passe interceptée par %s" % interceptor.display_name())
	else:
		_set_possession(possession_team, intended_receiver)
	pending_receiver = null
	action_timer = random.randf_range(0.8, 1.6)


func _resolve_shot() -> void:
	pending_shot = false
	var shooting_team := possession_team
	var defending_team := _opponent_of(shooting_team)

	if shot_will_score:
		if shooting_team == blue_team:
			blue_score += 1
		else:
			red_score += 1
		score_changed.emit(blue_score, red_score)
		event_announced.emit("BUT POUR %s !" % shooting_team.display_name.to_upper())
		blue_team.reset_formation()
		red_team.reset_formation()
		ball.reset_to(Vector2(640.0, 360.0))
		_set_possession(defending_team, defending_team.get_player_by_number(9))
		action_timer = 2.4
	else:
		_award_restart(
			FootballRulesEngine.RestartType.GOAL_KICK,
			defending_team,
			Vector2(112.0 if defending_team.attacks_right else 1168.0, 360.0)
		)


func _award_restart(
	restart_type: FootballRulesEngine.RestartType,
	team: FootballTeam,
	position: Vector2
) -> void:
	if team == null:
		return
	ball.freeze_at(position)
	var taker := (
		team.get_goalkeeper()
		if restart_type == FootballRulesEngine.RestartType.GOAL_KICK
		else team.get_nearest_player(position, false)
	)
	if taker == null:
		taker = team.get_nearest_player(position)
	_set_possession(team, taker)
	event_announced.emit("%s pour %s" % [
		rules.restart_label(restart_type),
		team.display_name,
	])
	action_timer = 1.4
	tackle_cooldown = 1.5


func _set_possession(team: FootballTeam, player: DemoPlayer) -> void:
	for football_player in blue_team.players + red_team.players:
		football_player.set_has_ball(false)

	possession_team = team
	possessor = player
	last_touch_team = team
	if is_instance_valid(possessor):
		possessor.set_has_ball(true)
		ball.follow(
			possessor,
			Vector2(18.0 if team.attacks_right else -18.0, 7.0)
		)


func _opponent_of(team: FootballTeam) -> FootballTeam:
	return red_team if team == blue_team else blue_team


func _attacking_progress(x_position: float, team: FootballTeam) -> float:
	if team.attacks_right:
		return inverse_lerp(90.0, 1190.0, x_position)
	return inverse_lerp(1190.0, 90.0, x_position)
