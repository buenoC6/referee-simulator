extends Node2D
class_name MatchBall

signal travel_finished(intended_receiver: DemoPlayer)

@export_range(1.0, 30.0, 0.5) var follow_strength: float = 14.0

var carrier: Node2D
var follow_offset := Vector2(22.0, 6.0)
var following: bool = false
var is_in_flight: bool = false
var flight_origin := Vector2.ZERO
var flight_destination := Vector2.ZERO
var flight_duration: float = 0.0
var flight_elapsed: float = 0.0
var intended_receiver: DemoPlayer


func _process(delta: float) -> void:
	if is_in_flight:
		_process_flight(delta)
		return

	if not following or not is_instance_valid(carrier):
		return

	var target_position := carrier.global_position + follow_offset
	var interpolation_weight := 1.0 - exp(-follow_strength * delta)
	global_position = global_position.lerp(target_position, interpolation_weight)


func follow(new_carrier: Node2D, offset: Vector2 = Vector2(22.0, 6.0)) -> void:
	is_in_flight = false
	carrier = new_carrier
	follow_offset = offset
	following = true


func freeze_at(frozen_position: Vector2) -> void:
	following = false
	is_in_flight = false
	carrier = null
	global_position = frozen_position


func kick_to(
	destination: Vector2,
	duration: float,
	receiver: DemoPlayer = null
) -> void:
	following = false
	carrier = null
	is_in_flight = true
	flight_origin = global_position
	flight_destination = destination
	flight_duration = maxf(duration, 0.1)
	flight_elapsed = 0.0
	intended_receiver = receiver


func reset_to(start_position: Vector2) -> void:
	freeze_at(start_position)


func _process_flight(delta: float) -> void:
	flight_elapsed += delta
	var progress := clampf(flight_elapsed / flight_duration, 0.0, 1.0)
	var eased_progress := smoothstep(0.0, 1.0, progress)
	global_position = flight_origin.lerp(flight_destination, eased_progress)

	if progress >= 1.0:
		is_in_flight = false
		var receiver := intended_receiver
		intended_receiver = null
		travel_finished.emit(receiver)


func _draw() -> void:
	draw_circle(Vector2(2.0, 4.0), 9.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_circle(Vector2.ZERO, 8.0, Color("#f8fafc"))
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, Color("#111827"), 1.5)
	draw_circle(Vector2.ZERO, 2.6, Color("#111827"))
	draw_circle(Vector2(5.0, -2.0), 1.8, Color("#111827"))
	draw_circle(Vector2(-4.0, 3.0), 1.8, Color("#111827"))
