extends CharacterBody2D
class_name DemoPlayer

enum AiState {
	HOLD_SHAPE,
	SUPPORT,
	PRESS,
	CARRY,
	RECOVER,
}

@export var team_color := Color("#2684ff")
@export_range(1, 99, 1) var shirt_number: int = 1
@export_range(40.0, 400.0, 10.0) var move_speed: float = 150.0

var team_id: int = 0
var role: StringName = &""
var profile: PlayerProfile
var home_position := Vector2.ZERO
var is_goalkeeper: bool = false
var has_ball: bool = false
var target_position := Vector2.ZERO
var movement_enabled: bool = false
var ai_state := AiState.HOLD_SHAPE
var stamina: float = 100.0
var decision_bias: float = 0.0


func _ready() -> void:
	target_position = global_position
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not movement_enabled:
		velocity = Vector2.ZERO
		stamina = minf(stamina + delta * 0.6, 100.0)
		return

	var distance_to_target := global_position.distance_to(target_position)
	if distance_to_target <= 4.0:
		global_position = target_position
		velocity = Vector2.ZERO
		movement_enabled = false
		return

	var fatigue_factor := lerpf(0.82, 1.0, stamina / 100.0)
	velocity = global_position.direction_to(target_position) * move_speed * fatigue_factor
	stamina = maxf(stamina - delta * 0.34, 35.0)
	move_and_slide()


func move_to(new_target: Vector2, new_speed: float = -1.0) -> void:
	target_position = new_target
	if new_speed > 0.0:
		move_speed = new_speed
	movement_enabled = true


func stop() -> void:
	movement_enabled = false
	velocity = Vector2.ZERO


func configure(
	new_team_id: int,
	new_role: StringName,
	new_home_position: Vector2,
	goalkeeper: bool = false
) -> void:
	team_id = new_team_id
	role = new_role
	home_position = new_home_position
	is_goalkeeper = goalkeeper
	global_position = home_position
	target_position = home_position
	queue_redraw()


func configure_profile(
	new_team_id: int,
	new_profile: PlayerProfile,
	new_home_position: Vector2
) -> void:
	profile = new_profile
	shirt_number = new_profile.shirt_number
	configure(
		new_team_id,
		new_profile.role,
		new_home_position,
		new_profile.role == &"GK"
	)
	decision_bias = (
		float((shirt_number * 17 + team_id * 11) % 13) / 12.0 - 0.5
	) * 34.0


func think_tactically(
	ball_position: Vector2,
	team_has_possession: bool,
	carrier: DemoPlayer,
	pressing_player: DemoPlayer,
	attacks_right: bool,
	tactics: TeamTactics
) -> void:
	if self == carrier:
		ai_state = AiState.CARRY
		return

	var attack_direction := 1.0 if attacks_right else -1.0
	if self == pressing_player and not team_has_possession:
		ai_state = AiState.PRESS
		var press_offset := Vector2(-attack_direction * 10.0, decision_bias * 0.12)
		move_to(ball_position + press_offset, 132.0 + tactics.pressing_intensity * 18.0)
		return

	var ball_delta := ball_position - Vector2(640.0, 360.0)
	var horizontal_response := 0.08 if is_goalkeeper else lerpf(0.14, 0.25, tactics.compactness)
	var vertical_response := 0.08 if is_goalkeeper else lerpf(0.12, 0.25, tactics.compactness)
	var collective_shift := Vector2(
		clampf(ball_delta.x * horizontal_response, -120.0, 120.0),
		clampf(ball_delta.y * vertical_response, -72.0, 72.0)
	)
	var target := home_position + collective_shift

	if is_goalkeeper:
		ai_state = AiState.HOLD_SHAPE
		target.y = clampf(lerpf(home_position.y, ball_position.y, 0.22), 285.0, 435.0)
	elif team_has_possession:
		ai_state = AiState.SUPPORT
		target += _attacking_run(attack_direction, ball_position, tactics)
	else:
		ai_state = AiState.RECOVER
		target += _defensive_adjustment(ball_position, tactics)

	target.x = clampf(target.x, 88.0, 1192.0)
	target.y = clampf(target.y, 92.0, 628.0)
	move_to(target, tactics.movement_speed_for_role(role, team_has_possession))


func set_has_ball(value: bool) -> void:
	has_ball = value
	if value:
		ai_state = AiState.CARRY
	queue_redraw()


func reset_to(start_position: Vector2) -> void:
	global_position = start_position
	target_position = start_position
	ai_state = AiState.HOLD_SHAPE
	stop()


func display_name() -> String:
	return profile.full_name if profile != null else "N°%d" % shirt_number


func _attacking_run(
	attack_direction: float,
	ball_position: Vector2,
	tactics: TeamTactics
) -> Vector2:
	var forward_distance := 0.0
	if role in [&"ST", &"LW", &"RW", &"FW"]:
		forward_distance = lerpf(65.0, 118.0, tactics.attacking_intent)
	elif role in [&"DM", &"CM", &"RCM", &"LCM"]:
		forward_distance = lerpf(30.0, 72.0, tactics.attacking_intent)
	else:
		forward_distance = lerpf(10.0, 38.0, tactics.attacking_intent)

	var lane_offset := decision_bias
	if role in [&"LW", &"LB"]:
		lane_offset -= 25.0 * tactics.width
	elif role in [&"RW", &"RB"]:
		lane_offset += 25.0 * tactics.width

	# A nearby player offers a shorter passing angle instead of making the same
	# forward run as every teammate.
	if global_position.distance_to(ball_position) < 190.0:
		forward_distance *= 0.55
		lane_offset += 34.0 if shirt_number % 2 == 0 else -34.0
	return Vector2(attack_direction * forward_distance, lane_offset)


func _defensive_adjustment(
	ball_position: Vector2,
	tactics: TeamTactics
) -> Vector2:
	var toward_ball_y := (ball_position.y - home_position.y) * tactics.compactness * 0.16
	var retreat := 0.0
	if role in [&"ST", &"LW", &"RW", &"FW"]:
		retreat = -18.0 if team_id == 0 else 18.0
	return Vector2(retreat, toward_ball_y + decision_bias * 0.18)


func _draw() -> void:
	if has_ball:
		draw_arc(
			Vector2.ZERO,
			23.0,
			0.0,
			TAU,
			32,
			Color("#facc15"),
			3.0
		)
	draw_circle(Vector2(2.0, 5.0), 18.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_circle(Vector2.ZERO, 17.0, team_color)
	draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 32, Color.WHITE, 2.0)
	var font := ThemeDB.fallback_font
	var number_text := str(shirt_number)
	var text_size := font.get_string_size(number_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	draw_string(
		font,
		Vector2(-text_size.x / 2.0, text_size.y / 3.0),
		number_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		15,
		Color.WHITE
	)

	if profile != null and profile.yellow_cards > 0:
		draw_rect(Rect2(11.0, -22.0, 7.0, 10.0), Color("#facc15"))
	if profile != null and profile.has_red_card:
		draw_rect(Rect2(11.0, -22.0, 7.0, 10.0), Color("#ef4444"))
