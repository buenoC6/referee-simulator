extends Control
class_name RefereeMinimap2D

const PITCH_WIDTH := 68.0
const PITCH_LENGTH := 105.0
const HALF_WIDTH := PITCH_WIDTH * 0.5
const HALF_LENGTH := PITCH_LENGTH * 0.5
const VIEW_HALF_ANGLE := deg_to_rad(38.0)

var players: Array[PerspectivePlayer3D] = []
var tracked_ball: Node3D
var tracked_referee: Node3D
var tracked_camera: Camera3D
var home_color := Color("#2274d8")
var away_color := Color("#df3545")
var refresh_accumulator: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func configure(
	player_nodes: Array[PerspectivePlayer3D],
	ball_node: Node3D,
	referee_node: Node3D,
	camera_node: Camera3D,
	selected_home_color: Color,
	selected_away_color: Color
) -> void:
	players = player_nodes
	tracked_ball = ball_node
	tracked_referee = referee_node
	tracked_camera = camera_node
	home_color = selected_home_color
	away_color = selected_away_color
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	refresh_accumulator += delta
	if refresh_accumulator >= 0.05:
		refresh_accumulator = 0.0
		queue_redraw()


func _draw() -> void:
	_draw_panel()
	var field_rect := _field_rect()
	_draw_pitch(field_rect)
	if (
		tracked_referee == null
		or tracked_camera == null
		or not is_instance_valid(tracked_referee)
		or not is_instance_valid(tracked_camera)
	):
		return
	_draw_referee_view(field_rect)
	_draw_players(field_rect)
	_draw_ball(field_rect)
	_draw_referee(field_rect)


func _draw_panel() -> void:
	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color(0.027, 0.032, 0.026, 0.82),
		true
	)
	draw_rect(
		Rect2(Vector2(0.75, 0.75), size - Vector2(1.5, 1.5)),
		Color(0.7, 0.72, 0.62, 0.14),
		false,
		1.0
	)
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(12.0, 21.0),
		"Terrain",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		Color("#e7e4d6")
	)
	draw_string(
		font,
		Vector2(size.x - 12.0, 21.0),
		"vue arbitre",
		HORIZONTAL_ALIGNMENT_RIGHT,
		72.0,
		10,
		Color("#899083")
	)


func _draw_legend_item(
	position: Vector2,
	color: Color,
	label: String
) -> void:
	draw_circle(position, 3.4, color)
	draw_string(
		ThemeDB.fallback_font,
		position + Vector2(7.0, 4.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		9,
		Color("#93a4b8")
	)


func _draw_referee_legend(position: Vector2) -> void:
	var diamond := PackedVector2Array([
		position + Vector2(0.0, -4.2),
		position + Vector2(4.2, 0.0),
		position + Vector2(0.0, 4.2),
		position + Vector2(-4.2, 0.0),
	])
	draw_colored_polygon(diamond, Color("#fb923c"))


func _field_rect() -> Rect2:
	var available_width := maxf(80.0, size.x - 28.0)
	var available_height := maxf(120.0, size.y - 48.0)
	var field_height := minf(
		available_height,
		available_width * PITCH_LENGTH / PITCH_WIDTH
	)
	var field_width := field_height * PITCH_WIDTH / PITCH_LENGTH
	return Rect2(
		Vector2((size.x - field_width) * 0.5, 34.0),
		Vector2(field_width, field_height)
	)


func _draw_pitch(field_rect: Rect2) -> void:
	draw_rect(field_rect, Color("#155b35"), true)
	var stripe_height := field_rect.size.y / 10.0
	for stripe_index in range(10):
		if stripe_index % 2 == 0:
			draw_rect(
				Rect2(
					Vector2(
						field_rect.position.x,
						field_rect.position.y
							+ float(stripe_index) * stripe_height
					),
					Vector2(field_rect.size.x, stripe_height)
				),
				Color("#1c6840"),
				true
			)

	var line_color := Color(0.94, 0.96, 0.91, 0.88)
	draw_rect(field_rect, line_color, false, 1.4)
	var halfway_y := field_rect.position.y + field_rect.size.y * 0.5
	draw_line(
		Vector2(field_rect.position.x, halfway_y),
		Vector2(field_rect.end.x, halfway_y),
		line_color,
		1.2
	)
	var scale := field_rect.size.x / PITCH_WIDTH
	draw_arc(
		field_rect.get_center(),
		9.15 * scale,
		0.0,
		TAU,
		40,
		line_color,
		1.2
	)
	draw_circle(field_rect.get_center(), 1.7, line_color)
	_draw_penalty_markings(field_rect, line_color)


func _draw_penalty_markings(
	field_rect: Rect2,
	line_color: Color
) -> void:
	var north_area_min := world_to_map(Vector3(-20.15, 0.0, -52.5))
	var north_area_max := world_to_map(Vector3(20.15, 0.0, -36.0))
	var south_area_min := world_to_map(Vector3(-20.15, 0.0, 36.0))
	var south_area_max := world_to_map(Vector3(20.15, 0.0, 52.5))
	draw_rect(
		Rect2(north_area_min, north_area_max - north_area_min),
		line_color,
		false,
		1.1
	)
	draw_rect(
		Rect2(south_area_min, south_area_max - south_area_min),
		line_color,
		false,
		1.1
	)
	var north_goal_min := world_to_map(Vector3(-9.16, 0.0, -52.5))
	var north_goal_max := world_to_map(Vector3(9.16, 0.0, -47.0))
	var south_goal_min := world_to_map(Vector3(-9.16, 0.0, 47.0))
	var south_goal_max := world_to_map(Vector3(9.16, 0.0, 52.5))
	draw_rect(
		Rect2(north_goal_min, north_goal_max - north_goal_min),
		line_color,
		false,
		1.0
	)
	draw_rect(
		Rect2(south_goal_min, south_goal_max - south_goal_min),
		line_color,
		false,
		1.0
	)
	draw_circle(
		world_to_map(Vector3(0.0, 0.0, -41.5)),
		1.45,
		line_color
	)
	draw_circle(
		world_to_map(Vector3(0.0, 0.0, 41.5)),
		1.45,
		line_color
	)


func _draw_referee_view(_field_rect: Rect2) -> void:
	var origin := world_to_map(tracked_referee.global_position)
	var direction := view_direction_2d()
	if direction.length_squared() <= 0.0001:
		return
	var view_length := 46.0
	var left_edge := origin + direction.rotated(-VIEW_HALF_ANGLE) * view_length
	var right_edge := origin + direction.rotated(VIEW_HALF_ANGLE) * view_length
	var cone := PackedVector2Array([origin, left_edge, right_edge])
	draw_colored_polygon(cone, Color(1.0, 0.72, 0.3, 0.14))
	draw_polyline(
		PackedVector2Array([left_edge, origin, right_edge]),
		Color(1.0, 0.75, 0.35, 0.52),
		1.1
	)
	var arrow_end := origin + direction * 33.0
	draw_line(origin, arrow_end, Color("#fb923c"), 2.2)
	var side := Vector2(-direction.y, direction.x)
	var arrow_head := PackedVector2Array([
		arrow_end + direction * 3.0,
		arrow_end - direction * 6.0 + side * 4.0,
		arrow_end - direction * 6.0 - side * 4.0,
	])
	draw_colored_polygon(arrow_head, Color("#fb923c"))


func _draw_players(_field_rect: Rect2) -> void:
	for player in players:
		if (
			player == null
			or not is_instance_valid(player)
			or not player.active
		):
			continue
		var position := world_to_map(player.global_position)
		var player_color := home_color if player.team_id == 0 else away_color
		draw_circle(position, 4.1, Color(0.02, 0.035, 0.055, 0.92))
		draw_circle(position, 3.0, player_color)


func _draw_ball(_field_rect: Rect2) -> void:
	if tracked_ball == null or not is_instance_valid(tracked_ball):
		return
	var position := world_to_map(tracked_ball.global_position)
	draw_circle(position, 5.0, Color(0.02, 0.035, 0.055, 0.94))
	draw_circle(position, 3.2, Color("#facc15"))
	draw_arc(
		position,
		5.2,
		0.0,
		TAU,
		16,
		Color(1.0, 0.9, 0.35, 0.78),
		1.0
	)


func _draw_referee(_field_rect: Rect2) -> void:
	var position := world_to_map(tracked_referee.global_position)
	var diamond := PackedVector2Array([
		position + Vector2(0.0, -5.5),
		position + Vector2(5.5, 0.0),
		position + Vector2(0.0, 5.5),
		position + Vector2(-5.5, 0.0),
	])
	draw_colored_polygon(diamond, Color("#fb923c"))
	draw_polyline(
		PackedVector2Array([
			diamond[0],
			diamond[1],
			diamond[2],
			diamond[3],
			diamond[0],
		]),
		Color("#fff7ed"),
		1.0
	)


func world_to_map(world_position: Vector3) -> Vector2:
	var field_rect := _field_rect()
	return Vector2(
		field_rect.position.x
			+ ((world_position.x + HALF_WIDTH) / PITCH_WIDTH)
			* field_rect.size.x,
		field_rect.position.y
			+ ((world_position.z + HALF_LENGTH) / PITCH_LENGTH)
			* field_rect.size.y
	)


func view_direction_2d() -> Vector2:
	if tracked_camera == null or not is_instance_valid(tracked_camera):
		return Vector2.ZERO
	var forward := -tracked_camera.global_transform.basis.z
	return Vector2(forward.x, forward.z).normalized()
