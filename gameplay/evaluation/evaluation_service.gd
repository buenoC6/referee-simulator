extends RefCounted
class_name EvaluationService

const TECHNICAL_MAX := 40
const DISCIPLINE_MAX := 20
const POSITIONING_MAX := 25
const RESPONSE_MAX := 15
const METERS_PER_PIXEL := 105.0 / 1152.0


func evaluate(
	incident: IncidentData,
	technical_choice: IncidentData.TechnicalDecision,
	discipline_choice: IncidentData.DisciplineDecision,
	referee_position: Vector2,
	response_time: float
) -> Dictionary:
	var technical_score := (
		TECHNICAL_MAX
		if technical_choice == incident.correct_technical_decision
		else 0
	)
	var discipline_score := (
		DISCIPLINE_MAX
		if discipline_choice == incident.correct_discipline_decision
		else 0
	)
	var distance := referee_position.distance_to(incident.incident_position)
	var positioning_score := _score_positioning(incident, distance)
	var response_score := _score_response_time(incident, response_time)

	var feedback := PackedStringArray()
	feedback.append(_technical_feedback(incident, technical_choice))
	feedback.append(_discipline_feedback(incident, discipline_choice))
	feedback.append(_positioning_feedback(incident, distance))
	feedback.append(_response_feedback(incident, response_time))

	return {
		"total_score": technical_score + discipline_score + positioning_score + response_score,
		"technical_score": technical_score,
		"discipline_score": discipline_score,
		"positioning_score": positioning_score,
		"response_score": response_score,
		"distance": distance,
		"response_time": response_time,
		"feedback": feedback,
		"explanation": incident.explanation,
	}


func _score_positioning(incident: IncidentData, distance: float) -> int:
	if (
		distance >= incident.minimum_observation_distance
		and distance <= incident.maximum_observation_distance
	):
		return POSITIONING_MAX

	var distance_from_valid_zone: float
	if distance < incident.minimum_observation_distance:
		distance_from_valid_zone = incident.minimum_observation_distance - distance
	else:
		distance_from_valid_zone = distance - incident.maximum_observation_distance

	var score_ratio := 1.0 - clampf(distance_from_valid_zone / 220.0, 0.0, 1.0)
	return roundi(POSITIONING_MAX * score_ratio)


func _score_response_time(incident: IncidentData, response_time: float) -> int:
	var full_score_threshold := minf(1.25, incident.maximum_response_time * 0.35)
	if response_time <= full_score_threshold:
		return RESPONSE_MAX

	var scoring_window := incident.maximum_response_time - full_score_threshold
	if scoring_window <= 0.0:
		return 0

	var score_ratio := 1.0 - clampf(
		(response_time - full_score_threshold) / scoring_window,
		0.0,
		1.0
	)
	return roundi(RESPONSE_MAX * score_ratio)


func _technical_feedback(
	incident: IncidentData,
	choice: IncidentData.TechnicalDecision
) -> String:
	if choice == incident.correct_technical_decision:
		return "Décision technique correcte : %s." % IncidentData.technical_decision_label(choice)
	return "Décision technique attendue : %s." % IncidentData.technical_decision_label(
		incident.correct_technical_decision
	)


func _discipline_feedback(
	incident: IncidentData,
	choice: IncidentData.DisciplineDecision
) -> String:
	if choice == incident.correct_discipline_decision:
		return "Sanction disciplinaire correcte : %s." % IncidentData.discipline_decision_label(
			choice
		)
	return "Sanction attendue : %s." % IncidentData.discipline_decision_label(
		incident.correct_discipline_decision
	)


func _positioning_feedback(incident: IncidentData, distance: float) -> String:
	var distance_meters := distance * METERS_PER_PIXEL
	if distance > incident.maximum_observation_distance:
		return "Position trop éloignée (%.0f m) : rapproche-toi de l'action." % distance_meters
	return "Bonne distance d'observation : %.0f m." % distance_meters


func _response_feedback(incident: IncidentData, response_time: float) -> String:
	if response_time <= 1.25:
		return "Réaction rapide : %.1f s." % response_time
	if response_time < incident.maximum_response_time:
		return "Décision enregistrée en %.1f s : encore un peu d'hésitation." % response_time
	return "Aucune décision avant la fin de la fenêtre de %.1f s." % (
		incident.maximum_response_time
	)
