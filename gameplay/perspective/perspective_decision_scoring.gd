extends RefCounted
class_name PerspectiveDecisionScoring

const TECHNICAL_POINTS := 60
const POSITIONING_POINTS := 25
const RESPONSE_POINTS := 15


static func score(
	technical_quality: float,
	expected: Dictionary,
	fallback_observation: Dictionary,
	default_response_window: float
) -> Dictionary:
	var observation: Dictionary = expected.get("observation_at_event", {})
	if observation.is_empty():
		observation = fallback_observation
	var observation_quality := clampf(
		float(observation.get("quality", 1.0)),
		0.0,
		1.0
	)
	var response_window := maxf(
		float(
			observation.get(
				"response_window",
				expected.get("response_window", default_response_window)
			)
		),
		0.1
	)
	var response_seconds := maxf(float(expected.get("age", 0.0)), 0.0)
	var technical_score := roundi(
		clampf(technical_quality, 0.0, 1.0) * TECHNICAL_POINTS
	)
	var positioning_score := roundi(
		observation_quality * POSITIONING_POINTS
	)
	var response_score := roundi(
		clampf(
			1.0 - response_seconds / response_window,
			0.0,
			1.0
		) * RESPONSE_POINTS
	)
	return {
		"technical_score": technical_score,
		"positioning_score": positioning_score,
		"response_score": response_score,
		"total_score": technical_score + positioning_score + response_score,
		"observation_quality": observation_quality,
		"response_seconds": response_seconds,
	}
