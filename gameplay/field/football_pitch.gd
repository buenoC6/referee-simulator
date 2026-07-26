extends Node2D
class_name FootballPitch

const FIELD_RECT := Rect2(64.0, 64.0, 1152.0, 592.0)
const LINE_COLOR := Color(0.92, 0.96, 0.90, 0.82)
const LINE_WIDTH := 3.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	# The pitch is drawn in code on purpose: the prototype stays runnable without
	# external assets, and every primitive is easy to inspect while learning.
	draw_rect(Rect2(Vector2.ZERO, Vector2(1580.0, 720.0)), Color("#111923"))
	draw_rect(FIELD_RECT.grow(14.0), Color("#07130d"))

	var stripe_width: float = FIELD_RECT.size.x / 12.0
	for stripe_index in range(12):
		var stripe_color := Color("#216e43") if stripe_index % 2 == 0 else Color("#247a49")
		var stripe_rect := Rect2(
			FIELD_RECT.position + Vector2(stripe_index * stripe_width, 0.0),
			Vector2(stripe_width + 1.0, FIELD_RECT.size.y)
		)
		draw_rect(stripe_rect, stripe_color)

	draw_rect(FIELD_RECT, LINE_COLOR, false, LINE_WIDTH)
	var center := FIELD_RECT.get_center()
	draw_line(
		Vector2(center.x, FIELD_RECT.position.y),
		Vector2(center.x, FIELD_RECT.end.y),
		LINE_COLOR,
		LINE_WIDTH
	)
	draw_arc(center, 72.0, 0.0, TAU, 64, LINE_COLOR, LINE_WIDTH)
	draw_circle(center, 5.0, LINE_COLOR)

	_draw_penalty_area(true)
	_draw_penalty_area(false)


func _draw_penalty_area(on_left: bool) -> void:
	var side: float = -1.0 if on_left else 1.0
	var goal_line_x: float = FIELD_RECT.position.x if on_left else FIELD_RECT.end.x
	var area_width := 165.0
	var area_height := 330.0
	var small_width := 62.0
	var small_height := 150.0
	var area_x: float = goal_line_x if on_left else goal_line_x - area_width
	var small_x: float = goal_line_x if on_left else goal_line_x - small_width
	var area_y: float = FIELD_RECT.get_center().y - area_height / 2.0
	var small_y: float = FIELD_RECT.get_center().y - small_height / 2.0

	draw_rect(Rect2(area_x, area_y, area_width, area_height), LINE_COLOR, false, LINE_WIDTH)
	draw_rect(Rect2(small_x, small_y, small_width, small_height), LINE_COLOR, false, LINE_WIDTH)

	var penalty_spot := Vector2(goal_line_x + side * 118.0, FIELD_RECT.get_center().y)
	draw_circle(penalty_spot, 4.0, LINE_COLOR)

	var goal_x: float = goal_line_x - 16.0 if on_left else goal_line_x
	draw_rect(
		Rect2(goal_x, FIELD_RECT.get_center().y - 48.0, 16.0, 96.0),
		LINE_COLOR,
		false,
		LINE_WIDTH
	)
