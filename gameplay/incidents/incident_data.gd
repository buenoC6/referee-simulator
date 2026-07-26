extends Resource
class_name IncidentData

enum TechnicalDecision {
	PLAY_ON,
	DIRECT_FREE_KICK,
	PENALTY_KICK,
}

enum DisciplineDecision {
	NO_CARD,
	YELLOW_CARD,
	RED_CARD,
}

@export_category("Identity")
@export var incident_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export_multiline var explanation: String = ""

@export_category("Correct decision")
@export var correct_technical_decision := TechnicalDecision.PLAY_ON
@export var correct_discipline_decision := DisciplineDecision.NO_CARD

@export_category("Observation")
@export var incident_position := Vector2.ZERO
@export_range(40.0, 500.0, 5.0) var minimum_observation_distance: float = 90.0
@export_range(40.0, 500.0, 5.0) var maximum_observation_distance: float = 230.0
@export_range(1.0, 10.0, 0.25) var maximum_response_time: float = 4.0


static func technical_decision_label(decision: TechnicalDecision) -> String:
	match decision:
		TechnicalDecision.PLAY_ON:
			return "Laisser jouer"
		TechnicalDecision.DIRECT_FREE_KICK:
			return "Coup franc direct"
		TechnicalDecision.PENALTY_KICK:
			return "Penalty"
		_:
			return "Décision inconnue"


static func discipline_decision_label(decision: DisciplineDecision) -> String:
	match decision:
		DisciplineDecision.NO_CARD:
			return "Aucun carton"
		DisciplineDecision.YELLOW_CARD:
			return "Carton jaune"
		DisciplineDecision.RED_CARD:
			return "Carton rouge"
		_:
			return "Sanction inconnue"

