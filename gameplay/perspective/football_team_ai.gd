extends RefCounted
class_name FootballTeamAI

const EMPTY_SPACE_DISTANCE := 30.0
const PASS_LEAD_DISTANCE := 2.8
const PITCH_HALF_WIDTH := 32.0


static func nearest_opponent_distance(
	position: Vector3,
	opponents: Array
) -> float:
	var nearest := EMPTY_SPACE_DISTANCE
	for opponent_candidate in opponents:
		var opponent := opponent_candidate as Node3D
		if opponent == null:
			continue
		var distance := _flat_distance(position, opponent.global_position)
		nearest = minf(nearest, distance)
	return nearest


static func best_open_lane_direction(
	position: Vector3,
	attack_direction: float,
	opponents: Array
) -> Vector3:
	var forward := Vector3(0.0, 0.0, signf(attack_direction))
	var best_direction := forward
	var best_score := -INF
	for angle_degrees in [-52.0, -34.0, -18.0, 0.0, 18.0, 34.0, 52.0]:
		var direction := forward.rotated(
			Vector3.UP,
			deg_to_rad(angle_degrees)
		).normalized()
		var probe_end := position + direction * 7.5
		var lane_clearance := _lane_clearance(
			position,
			probe_end,
			opponents
		)
		var width_penalty := clampf(
			(absf(probe_end.x) - (PITCH_HALF_WIDTH - 3.0)) / 4.0,
			0.0,
			1.0
		)
		var forward_preference := 1.0 - absf(angle_degrees) / 90.0
		var score := (
			clampf(lane_clearance / 5.5, 0.0, 1.0) * 0.76
			+ forward_preference * 0.24
			- width_penalty * 0.8
		)
		if score > best_score:
			best_score = score
			best_direction = direction
	return best_direction


static func pass_option(
	passer_position: Vector3,
	receiver: Node3D,
	attack_direction: float,
	opponents: Array,
	offside_line: float
) -> Dictionary:
	if receiver == null:
		return {}

	var destination := receiver.global_position
	var receiver_target: Vector3 = receiver.get("target_position")
	var receiver_moving: bool = bool(receiver.get("moving"))
	if receiver_moving:
		var run_direction := receiver_target - receiver.global_position
		run_direction.y = 0.0
		destination += run_direction.limit_length(PASS_LEAD_DISTANCE)
	destination.x = clampf(
		destination.x,
		-PITCH_HALF_WIDTH + 1.0,
		PITCH_HALF_WIDTH - 1.0
	)

	var distance := _flat_distance(passer_position, destination)
	var lane_clearance := _lane_clearance(
		passer_position,
		destination,
		opponents
	)
	var receiver_space := nearest_opponent_distance(destination, opponents)
	var progression := (
		(destination.z - passer_position.z) * signf(attack_direction)
	)
	var beyond_offside_line := (
		(destination.z - offside_line) * signf(attack_direction) > 0.0
	)
	var distance_quality := 1.0 - clampf(
		absf(distance - 15.0) / 28.0,
		0.0,
		1.0
	)
	var score := (
		clampf(lane_clearance / 5.5, 0.0, 1.0) * 0.42
		+ clampf(receiver_space / 6.0, 0.0, 1.0) * 0.24
		+ clampf((progression + 8.0) / 32.0, 0.0, 1.0) * 0.20
		+ distance_quality * 0.14
		- (0.62 if beyond_offside_line else 0.0)
	)
	return {
		"receiver": receiver,
		"destination": destination,
		"distance": distance,
		"lane_clearance": lane_clearance,
		"receiver_space": receiver_space,
		"progression": progression,
		"offside_risk": beyond_offside_line,
		"score": score,
	}


static func _lane_clearance(
	start: Vector3,
	end: Vector3,
	opponents: Array
) -> float:
	var clearance := EMPTY_SPACE_DISTANCE
	var start_2d := Vector2(start.x, start.z)
	var end_2d := Vector2(end.x, end.z)
	for opponent_candidate in opponents:
		var opponent := opponent_candidate as Node3D
		if opponent == null:
			continue
		var opponent_position := Vector2(
			opponent.global_position.x,
			opponent.global_position.z
		)
		clearance = minf(
			clearance,
			_distance_to_segment(opponent_position, start_2d, end_2d)
		)
	return clearance


static func _distance_to_segment(
	point: Vector2,
	start: Vector2,
	end: Vector2
) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var progress := clampf(
		(point - start).dot(segment) / length_squared,
		0.0,
		1.0
	)
	return point.distance_to(start + segment * progress)


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
