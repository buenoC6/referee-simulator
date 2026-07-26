extends CharacterBody2D
class_name Referee

signal whistle_requested

@export_range(100.0, 600.0, 10.0) var speed: float = 290.0
@export var movement_bounds := Rect2(84.0, 84.0, 1112.0, 552.0)

var input_enabled: bool = true
var facing_direction := Vector2.UP


func _physics_process(_delta: float) -> void:
	if not input_enabled:
		velocity = Vector2.ZERO
		return

	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	# Arrow keys are accepted as a friendly fallback while ZQSD remains visible
	# in Project Settings as the canonical input map.
	input_direction += Vector2(
		float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP))
	)
	input_direction = input_direction.limit_length(1.0)

	if not input_direction.is_zero_approx():
		facing_direction = input_direction.normalized()
		queue_redraw()

	velocity = input_direction * speed
	move_and_slide()
	global_position = Vector2(
		clampf(global_position.x, movement_bounds.position.x, movement_bounds.end.x),
		clampf(global_position.y, movement_bounds.position.y, movement_bounds.end.y)
	)


func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event.is_action_pressed("whistle"):
		whistle_requested.emit()
		get_viewport().set_input_as_handled()


func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not input_enabled:
		velocity = Vector2.ZERO


func reset_to(start_position: Vector2) -> void:
	global_position = start_position
	facing_direction = Vector2.UP
	velocity = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(2.0, 5.0), 17.0, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(Vector2.ZERO, 16.0, Color("#f5c542"))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color("#111827"), 3.0)
	draw_rect(Rect2(-9.0, -5.0, 18.0, 10.0), Color("#171717"))
	draw_circle(Vector2(0.0, -19.0), 7.5, Color("#c88a63"))
	draw_line(
		facing_direction * 12.0,
		facing_direction * 24.0,
		Color("#fff1b8"),
		3.0
	)

