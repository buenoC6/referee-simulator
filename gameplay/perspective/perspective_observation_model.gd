extends RefCounted
class_name PerspectiveObservationModel

const CLEAR_DISTANCE_METERS := 12.0
const LOST_DISTANCE_METERS := 38.0
const CLEAR_ANGLE_DEGREES := 18.0
const LOST_ANGLE_DEGREES := 72.0


static func evaluate(
	camera_position: Vector3,
	camera_forward: Vector3,
	contact_position: Vector3,
	is_occluded: bool
) -> Dictionary:
	var direction_to_contact := contact_position - camera_position
	var distance := direction_to_contact.length()
	var flat_forward := Vector3(camera_forward.x, 0.0, camera_forward.z).normalized()
	var flat_direction := Vector3(
		direction_to_contact.x,
		0.0,
		direction_to_contact.z
	).normalized()
	var view_angle := rad_to_deg(
		acos(clampf(flat_forward.dot(flat_direction), -1.0, 1.0))
	)
	var distance_quality := _falloff(
		distance,
		CLEAR_DISTANCE_METERS,
		LOST_DISTANCE_METERS
	)
	var angle_quality := _falloff(
		view_angle,
		CLEAR_ANGLE_DEGREES,
		LOST_ANGLE_DEGREES
	)
	var occlusion_quality := 0.28 if is_occluded else 1.0
	var quality := clampf(
		distance_quality * angle_quality * occlusion_quality,
		0.0,
		1.0
	)

	return {
		"distance_meters": distance,
		"view_angle_degrees": view_angle,
		"is_occluded": is_occluded,
		"distance_quality": distance_quality,
		"angle_quality": angle_quality,
		"quality": quality,
		"positioning_score": roundi(quality * 25.0),
		"response_window": lerpf(1.8, 4.5, quality),
		"label": _quality_label(quality, is_occluded),
	}


static func _falloff(value: float, clear_limit: float, lost_limit: float) -> float:
	if value <= clear_limit:
		return 1.0
	return 1.0 - clampf(
		(value - clear_limit) / (lost_limit - clear_limit),
		0.0,
		1.0
	)


static func _quality_label(quality: float, is_occluded: bool) -> String:
	if is_occluded:
		return "Jambes masquées"
	if quality >= 0.82:
		return "Lecture nette"
	if quality >= 0.52:
		return "Angle exploitable"
	if quality >= 0.24:
		return "Indices partiels"
	return "Contact mal vu"
