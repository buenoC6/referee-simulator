extends Node2D
class_name IncidentMarker

var is_active: bool = false
var pulse_time: float = 0.0
var observation_clarity: float = 1.0


func _process(delta: float) -> void:
	if not is_active:
		return
	pulse_time += delta
	queue_redraw()


func show_at(world_position: Vector2, clarity: float = 1.0) -> void:
	global_position = world_position
	pulse_time = 0.0
	observation_clarity = clampf(clarity, 0.12, 1.0)
	is_active = true
	visible = true
	queue_redraw()


func hide_marker() -> void:
	is_active = false
	visible = false


func _draw() -> void:
	if not is_active:
		return
	var pulse := (sin(pulse_time * 7.0) + 1.0) * 0.5
	var radius := lerpf(20.0, 39.0, observation_clarity)
	radius += lerpf(0.0, 8.0, pulse) * observation_clarity
	var alpha := lerpf(0.72, 0.20, pulse) * observation_clarity
	draw_circle(
		Vector2.ZERO,
		lerpf(5.0, 10.0, observation_clarity),
		Color(1.0, 0.78, 0.2, 0.35 * observation_clarity)
	)
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		48,
		Color(1.0, 0.82, 0.25, alpha),
		4.0
	)
