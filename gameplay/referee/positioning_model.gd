extends RefCounted
class_name PositioningModel

const CLEAR_VIEW_DISTANCE := 230.0
const LOST_VIEW_DISTANCE := 510.0
const METERS_PER_PIXEL := 105.0 / 1152.0


func proximity_quality(
	referee_position: Vector2,
	action_position: Vector2,
	clear_view_distance: float = CLEAR_VIEW_DISTANCE
) -> float:
	var distance := referee_position.distance_to(action_position)
	if distance <= clear_view_distance:
		return 1.0
	return 1.0 - clampf(
		(distance - clear_view_distance)
		/ (LOST_VIEW_DISTANCE - clear_view_distance),
		0.0,
		1.0
	)


func quality_label(quality: float) -> String:
	if quality >= 0.86:
		return "NETTE"
	if quality >= 0.58:
		return "CORRECTE"
	if quality >= 0.28:
		return "LOINTAINE"
	return "PERDUE"


func observation_label(distance: float, maximum_distance: float) -> String:
	if distance <= maximum_distance:
		return "VUE NETTE"
	if distance <= maximum_distance + 120.0:
		return "VISION LOINTAINE"
	return "ACTION MAL VUE"


func adjusted_response_window(
	base_window: float,
	distance: float,
	maximum_distance: float
) -> float:
	if distance <= maximum_distance:
		return base_window
	var distance_from_clear_view := distance - maximum_distance
	var observation_ratio := 1.0 - clampf(
		distance_from_clear_view / 240.0,
		0.0,
		1.0
	)
	return lerpf(1.6, base_window, observation_ratio)


func pixels_to_meters(distance: float) -> float:
	return distance * METERS_PER_PIXEL
