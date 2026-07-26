extends RefCounted
class_name FootballLaws3D

const HALF_PITCH_WIDTH := 34.0
const HALF_PITCH_LENGTH := 52.5
const CENTER_CIRCLE_RADIUS := 9.15
const PENALTY_AREA_HALF_WIDTH := 20.15
const PENALTY_AREA_DEPTH_LINE := 36.0


static func own_half_sign(team_id: int, second_half: bool = false) -> float:
	var first_half_sign := 1.0 if team_id == 0 else -1.0
	return -first_half_sign if second_half else first_half_sign


static func attack_direction(
	team_id: int,
	second_half: bool = false
) -> float:
	return -own_half_sign(team_id, second_half)


static func is_in_own_half(
	position: Vector3,
	team_id: int,
	second_half: bool = false
) -> bool:
	return (
		position.z * own_half_sign(team_id, second_half)
		>= -0.001
	)


static func respects_kickoff_distance(
	position: Vector3,
	kicking_team_id: int,
	player_team_id: int,
	second_half: bool = false
) -> bool:
	if player_team_id == kicking_team_id:
		return true
	var flat_position := Vector2(position.x, position.z)
	return flat_position.length() >= CENTER_CIRCLE_RADIUS - 0.001 and (
		is_in_own_half(position, player_team_id, second_half)
	)


static func is_offside_position(
	receiver_position: Vector3,
	ball_position: Vector3,
	second_last_defender_z: float,
	attacking_team_id: int,
	second_half: bool = false
) -> bool:
	var direction := attack_direction(attacking_team_id, second_half)
	var receiver_progress := receiver_position.z * direction
	var ball_progress := ball_position.z * direction
	var defender_progress := second_last_defender_z * direction
	return (
		receiver_progress > 0.001
		and receiver_progress > ball_progress + 0.001
		and receiver_progress > defender_progress + 0.001
	)


static func is_penalty_area(
	position: Vector3,
	defending_team_id: int,
	second_half: bool = false
) -> bool:
	if absf(position.x) > PENALTY_AREA_HALF_WIDTH:
		return false
	return (
		position.z * own_half_sign(defending_team_id, second_half)
		> PENALTY_AREA_DEPTH_LINE
	)


static func clamp_inside_pitch(position: Vector3) -> Vector3:
	return Vector3(
		clampf(
			position.x,
			-HALF_PITCH_WIDTH + 0.15,
			HALF_PITCH_WIDTH - 0.15
		),
		position.y,
		clampf(
			position.z,
			-HALF_PITCH_LENGTH + 0.15,
			HALF_PITCH_LENGTH - 0.15
		)
	)
