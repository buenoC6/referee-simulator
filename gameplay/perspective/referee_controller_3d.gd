extends CharacterBody3D
class_name RefereeController3D

signal whistle_requested
signal advantage_requested

@export var movement_speed: float = 7.4
@export var mouse_sensitivity: float = 0.0022
@export var movement_bounds := Rect2(-31.5, -49.5, 63.0, 99.0)

@onready var camera: Camera3D = $Camera3D

var movement_enabled: bool = true
var whistle_enabled: bool = true
var look_enabled: bool = true
var pitch: float = -0.105


func _ready() -> void:
	camera.rotation.x = pitch
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(_delta: float) -> void:
	if not movement_enabled:
		velocity = Vector3.ZERO
		return

	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	var movement := (
		right.normalized() * input_direction.x
		+ forward.normalized() * -input_direction.y
	).limit_length(1.0)

	velocity = movement * movement_speed
	move_and_slide()
	global_position.x = clampf(
		global_position.x,
		movement_bounds.position.x,
		movement_bounds.end.x
	)
	global_position.z = clampf(
		global_position.z,
		movement_bounds.position.y,
		movement_bounds.end.y
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and look_enabled:
		var mouse_motion := event as InputEventMouseMotion
		rotate_y(-mouse_motion.relative.x * mouse_sensitivity)
		pitch = clampf(
			pitch - mouse_motion.relative.y * mouse_sensitivity,
			deg_to_rad(-58.0),
			deg_to_rad(48.0)
		)
		camera.rotation.x = pitch
		get_viewport().set_input_as_handled()
		return

	if whistle_enabled and event.is_action_pressed("whistle"):
		whistle_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if whistle_enabled and event.is_action_pressed("advantage"):
		advantage_requested.emit()
		get_viewport().set_input_as_handled()
		return

func set_movement_enabled(value: bool) -> void:
	movement_enabled = value
	if not movement_enabled:
		velocity = Vector3.ZERO


func set_input_enabled(value: bool) -> void:
	movement_enabled = value
	whistle_enabled = value
	look_enabled = value
	if not value:
		velocity = Vector3.ZERO
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = (
			Input.MOUSE_MODE_CAPTURED
			if value
			else Input.MOUSE_MODE_VISIBLE
		)


func set_inspection_enabled() -> void:
	movement_enabled = true
	look_enabled = true
	whistle_enabled = false
	velocity = Vector3.ZERO
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func reset_to(reset_position: Vector3, yaw_degrees: float = 0.0) -> void:
	global_position = reset_position
	rotation = Vector3(0.0, deg_to_rad(yaw_degrees), 0.0)
	pitch = -0.105
	camera.rotation.x = pitch
	velocity = Vector3.ZERO


func camera_position() -> Vector3:
	return camera.global_position


func camera_forward() -> Vector3:
	return -camera.global_transform.basis.z
