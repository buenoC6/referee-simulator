extends Node2D
class_name IncidentMarker

var is_active: bool = false
var pulse_time: float = 0.0


func _process(delta: float) -> void:
	if not is_active:
		return
	pulse_time += delta
	queue_redraw()


func show_at(world_position: Vector2) -> void:
	global_position = world_position
	pulse_time = 0.0
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
	var radius := lerpf(26.0, 39.0, pulse)
	var alpha := lerpf(0.85, 0.25, pulse)
	draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.78, 0.2, 0.35))
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		48,
		Color(1.0, 0.82, 0.25, alpha),
		4.0
	)

