extends Control
class_name MenuBackground

const FIELD_COLOR := Color(0.14, 0.48, 0.29, 0.17)
const LINE_COLOR := Color(0.58, 0.78, 0.67, 0.22)


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var viewport_size := size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("#0b111b"))

	# A deliberately abstract pitch creates context without requiring an image
	# asset. It also demonstrates that Controls can draw custom UI decoration.
	var pitch_size := Vector2(viewport_size.x * 0.62, viewport_size.y * 0.82)
	var pitch_position := Vector2(viewport_size.x * 0.04, viewport_size.y * 0.09)
	var pitch_rect := Rect2(pitch_position, pitch_size)

	draw_rect(pitch_rect, FIELD_COLOR)
	draw_rect(pitch_rect, LINE_COLOR, false, 3.0)
	draw_line(
		Vector2(pitch_rect.get_center().x, pitch_rect.position.y),
		Vector2(pitch_rect.get_center().x, pitch_rect.end.y),
		LINE_COLOR,
		3.0
	)
	draw_arc(pitch_rect.get_center(), 82.0, 0.0, TAU, 64, LINE_COLOR, 3.0)
	draw_circle(pitch_rect.get_center(), 5.0, LINE_COLOR)

	for index in range(7):
		var point := Vector2(
			pitch_rect.position.x + 95.0 + index * 95.0,
			pitch_rect.position.y + 80.0 + fmod(index * 83.0, pitch_rect.size.y - 160.0)
		)
		draw_circle(point, 7.0, Color(0.95, 0.77, 0.24, 0.11))

	# Vignette-like panels on the right make the active menu card stand out.
	draw_rect(
		Rect2(viewport_size.x * 0.72, 0.0, viewport_size.x * 0.28, viewport_size.y),
		Color(0.02, 0.03, 0.05, 0.48)
	)

