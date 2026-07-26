extends Control
class_name MenuBackground

const INK := Color("#10130f")
const FIELD_GLOW := Color(0.16, 0.31, 0.2, 0.18)
const LINE_COLOR := Color(0.75, 0.77, 0.6, 0.085)


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var viewport_size := size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), INK)
	for band in range(8):
		var band_alpha := 0.11 - float(band) * 0.011
		draw_rect(
			Rect2(
				Vector2(0.0, viewport_size.y * (0.46 + band * 0.06)),
				Vector2(viewport_size.x, viewport_size.y * 0.08)
			),
			Color(0.15, 0.3, 0.18, band_alpha)
		)

	var pitch_size := Vector2(viewport_size.x * 0.62, viewport_size.y * 0.84)
	var pitch_position := Vector2(-viewport_size.x * 0.16, viewport_size.y * 0.2)
	var pitch_rect := Rect2(pitch_position, pitch_size)
	draw_rect(pitch_rect, FIELD_GLOW)
	draw_line(
		Vector2(pitch_rect.get_center().x, pitch_rect.position.y),
		Vector2(pitch_rect.get_center().x, pitch_rect.end.y),
		LINE_COLOR,
		2.0
	)
	draw_arc(
		pitch_rect.get_center(),
		minf(viewport_size.x, viewport_size.y) * 0.13,
		0.0,
		TAU,
		80,
		LINE_COLOR,
		2.0
	)
