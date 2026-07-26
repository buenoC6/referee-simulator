extends Node
class_name MatchSimulation

signal score_changed(blue_score: int, red_score: int)
signal event_announced(text: String)
signal foul_committed(position: Vector2, fouled_team_id: int)

@onready var blue_team: FootballTeam = $"../BlueTeam"
@onready var red_team: FootballTeam = $"../RedTeam"
@onready var ball: MatchBall = $"../MatchBall"

var blue_score: int = 0
var red_score: int = 0
var is_running: bool = false
var possession_team: FootballTeam
var possessor: DemoPlayer
var last_fouled_team: FootballTeam

var action_timer: float = 0.0
var shape_timer: float = 0.0
var tackle_cooldown: float = 0.0
var incident_timer: float = 0.0
var pending_shot: bool = false
var shot_will_score: bool = false

var random := RandomNumberGenerator.new()


func _ready() -> void:
	random.randomize()
	ball.travel_finished.connect(_on_ball_travel_finished)


func reset_match() -> void:
	is_running = false
	blue_score = 0
	red_score = 0
	blue_team.reset_formation()
	red_team.reset_formation()
	ball.reset_to(Vector2(640.0, 360.0))
	_set_possession(blue_team, blue_team.get_player_by_number(9))
	action_timer = 1.5
	shape_timer = 0.0
	tackle_cooldown = 1.5
	incident_timer = random.randf_range(18.0, 25.0)
	pending_shot = false
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
		var restart_player := last_fouled_team.get_nearest_player(
			ball.global_position,
			false
		)
		_set_possession(last_fouled_team, restart_player)
		event_announced.emit("Reprise sur coup franc")
	else:
		event_announced.emit("Le jeu se poursuit")

	incident_timer = random.randf_range(24.0, 36.0)
	action_timer = 1.2
	tackle_cooldown = 2.0
	is_running = true


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

	if possessor == null or ball.is_in_flight:
		return

	_move_ball_carrier()
	_apply_defensive_pressure()

	if _try_trigger_incident():
		return

	if _try_turnover():
		return

	if action_timer <= 0.0:
		_choose_next_action()


func _update_team_shapes() -> void:
	var carrier := possessor
	blue_team.update_shape(ball.global_position, possession_team == blue_team, carrier)
	red_team.update_shape(ball.global_position, possession_team == red_team, carrier)


func _move_ball_carrier() -> void:
	if possessor == null:
		return
	var attack_direction := 1.0 if possession_team.attacks_right else -1.0
	var lane_y := lerpf(possessor.home_position.y, 360.0, 0.28)
	var destination := Vector2(
		clampf(possessor.global_position.x + attack_direction * 150.0, 90.0, 1190.0),
		clampf(lane_y, 105.0, 615.0)
	)
	possessor.move_to(destination, 108.0)


func _apply_defensive_pressure() -> void:
	var defending_team := _opponent_of(possession_team)
	var pressing_player := defending_team.get_nearest_player(
		possessor.global_position,
		false
	)
	pressing_player.move_to(possessor.global_position, 137.0)


func _try_trigger_incident() -> bool:
	if incident_timer > 0.0:
		return false

	var defending_team := _opponent_of(possession_team)
	var pressing_player := defending_team.get_nearest_player(
		possessor.global_position,
		false
	)
	if pressing_player.global_position.distance_to(possessor.global_position) > 72.0:
		return false

	last_fouled_team = possession_team
	pressing_player.global_position = possessor.global_position + Vector2(
		-18.0 if possession_team.attacks_right else 18.0,
		8.0
	)
	ball.freeze_at(possessor.global_position + Vector2(10.0, 7.0))
	pause_for_incident()
	event_announced.emit("Contact entre deux joueurs")
	foul_committed.emit(possessor.global_position, possession_team.team_id)
	return true


func _try_turnover() -> bool:
	if tackle_cooldown > 0.0:
		return false

	var defending_team := _opponent_of(possession_team)
	var pressing_player := defending_team.get_nearest_player(
		possessor.global_position,
		false
	)
	if pressing_player.global_position.distance_to(possessor.global_position) > 29.0:
		return false

	tackle_cooldown = random.randf_range(2.5, 4.0)
	if random.randf() > 0.34:
		return false

	_set_possession(defending_team, pressing_player)
	action_timer = random.randf_range(0.9, 1.5)
	event_announced.emit("Ballon récupéré par %s" % defending_team.display_name)
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

	candidates.sort_custom(
		func(a: DemoPlayer, b: DemoPlayer) -> bool:
			var a_progress := a.global_position.x * attack_direction
			var b_progress := b.global_position.x * attack_direction
			return a_progress > b_progress
	)
	var selection_limit := mini(candidates.size(), 4)
	var receiver := candidates[random.randi_range(0, selection_limit - 1)]
	var passer_number := possessor.shirt_number

	possessor.set_has_ball(false)
	possessor = null
	var destination := receiver.global_position + receiver.velocity * 0.28
	var duration := clampf(
		ball.global_position.distance_to(destination) / 430.0,
		0.45,
		1.15
	)
	ball.kick_to(destination, duration, receiver)
	event_announced.emit("Passe du n°%d" % passer_number)


func _shoot() -> void:
	var shooting_team := possession_team
	var attack_direction := 1.0 if shooting_team.attacks_right else -1.0
	var goal_x := 1224.0 if shooting_team.attacks_right else 56.0
	var distance_to_goal := absf(goal_x - possessor.global_position.x)
	var scoring_probability := clampf(0.58 - distance_to_goal / 720.0, 0.14, 0.52)
	shot_will_score = random.randf() < scoring_probability
	pending_shot = true

	var target_y := random.randf_range(320.0, 400.0)
	if not shot_will_score:
		target_y = 270.0 if random.randi_range(0, 1) == 0 else 450.0

	var shooter_number := possessor.shirt_number
	possessor.set_has_ball(false)
	possessor = null
	ball.kick_to(Vector2(goal_x + attack_direction * 8.0, target_y), 0.62)
	event_announced.emit("Frappe du n°%d !" % shooter_number)


func _on_ball_travel_finished(intended_receiver: DemoPlayer) -> void:
	if pending_shot:
		_resolve_shot()
		return

	if intended_receiver == null:
		return

	var opponent_team := _opponent_of(possession_team)
	var interceptor := opponent_team.get_nearest_player(ball.global_position, false)
	if (
		interceptor.global_position.distance_to(ball.global_position) < 34.0
		and random.randf() < 0.46
	):
		_set_possession(opponent_team, interceptor)
		event_announced.emit("Passe interceptée")
	else:
		_set_possession(possession_team, intended_receiver)
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
		var goalkeeper := defending_team.get_goalkeeper()
		_set_possession(defending_team, goalkeeper)
		event_announced.emit("Le gardien relance")
		action_timer = 1.5


func _set_possession(team: FootballTeam, player: DemoPlayer) -> void:
	for football_player in blue_team.players + red_team.players:
		football_player.set_has_ball(false)

	possession_team = team
	possessor = player
	if possessor != null:
		possessor.set_has_ball(true)
		ball.follow(possessor, Vector2(18.0 if team.attacks_right else -18.0, 7.0))


func _opponent_of(team: FootballTeam) -> FootballTeam:
	return red_team if team == blue_team else blue_team


func _attacking_progress(x_position: float, team: FootballTeam) -> float:
	if team.attacks_right:
		return inverse_lerp(90.0, 1190.0, x_position)
	return inverse_lerp(1190.0, 90.0, x_position)
