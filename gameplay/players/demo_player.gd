extends CharacterBody2D
class_name DemoPlayer

@export var team_color := Color("#2684ff")
@export_range(1, 99, 1) var shirt_number: int = 1
@export_range(40.0, 400.0, 10.0) var move_speed: float = 150.0

var team_id: int = 0
var role: StringName = &""
var home_position := Vector2.ZERO
var is_goalkeeper: bool = false
var has_ball: bool = false
var target_position := Vector2.ZERO
var movement_enabled: bool = false


func _ready() -> void:
	target_position = global_position
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if not movement_enabled:
		velocity = Vector2.ZERO
		return

	var distance_to_target := global_position.distance_to(target_position)
	if distance_to_target <= 4.0:
		global_position = target_position
		velocity = Vector2.ZERO
		movement_enabled = false
		return

	velocity = global_position.direction_to(target_position) * move_speed
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


func set_has_ball(value: bool) -> void:
	has_ball = value
	queue_redraw()


func reset_to(start_position: Vector2) -> void:
	global_position = start_position
	target_position = start_position
	stop()


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
