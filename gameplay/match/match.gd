extends Node2D
class_name RefereeMatch

signal main_menu_requested

enum MatchPhase {
	PRE_MATCH,
	PLAYING,
	INCIDENT_WINDOW,
	DECISION,
	FEEDBACK,
	RESULTS,
}

const INCIDENT_TEMPLATE: IncidentData = preload(
	"res://gameplay/incidents/sit_001_reckless_tackle.tres"
)

const REFEREE_START := Vector2(485.0, 420.0)
const MATCH_REAL_DURATION := 180.0
const PRE_MATCH_DURATION := 1.3
const FEEDBACK_DURATION := 2.6

@onready var referee: Referee = $Referee
@onready var ball: MatchBall = $MatchBall
@onready var simulation: MatchSimulation = $MatchSimulation
@onready var incident_marker: IncidentMarker = $IncidentMarker
@onready var incident_director: IncidentDirector = $IncidentDirector
@onready var hud: MatchHud = $MatchHud
@onready var roster_panel: RosterPanel = $RosterPanel
@onready var decision_panel: DecisionPanel = $DecisionPanel
@onready var results_panel: ResultsPanel = $ResultsPanel

var phase := MatchPhase.PRE_MATCH
var phase_elapsed: float = 0.0
var match_elapsed: float = 0.0
var current_incident: IncidentData
var referee_observation_position := Vector2.ZERO
var observation_distance: float = 0.0
var observation_label: String = ""
var observation_quality: float = 0.0
var decision_response_time: float = 0.0
var pending_foul_awarded: bool = false
var substitutions_triggered: bool = false
var evaluations: Array[Dictionary] = []
var evaluation_service := EvaluationService.new()
var positioning_model := PositioningModel.new()
var positioning_quality_total: float = 0.0
var positioning_sample_time: float = 0.0


func _ready() -> void:
	referee.whistle_requested.connect(_on_whistle_requested)
	simulation.score_changed.connect(_on_score_changed)
	simulation.event_announced.connect(_on_event_announced)
	simulation.foul_committed.connect(_on_foul_committed)
	incident_director.incident_started.connect(_on_incident_started)
	incident_director.incident_expired.connect(_on_incident_expired)
	decision_panel.decision_submitted.connect(_on_decision_submitted)
	results_panel.replay_requested.connect(_start_match)
	results_panel.main_menu_requested.connect(func() -> void: main_menu_requested.emit())
	roster_panel.setup($BlueTeam, $RedTeam)
	_start_match()


func _process(delta: float) -> void:
	phase_elapsed += delta

	match phase:
		MatchPhase.PRE_MATCH:
			if phase_elapsed >= PRE_MATCH_DURATION:
				_begin_play()
		MatchPhase.PLAYING:
			match_elapsed += delta
			_update_positioning(delta)
			var match_minutes := match_elapsed / MATCH_REAL_DURATION * 90.0
			hud.set_match_minute(match_minutes)
			if match_minutes >= 60.0 and not substitutions_triggered:
				substitutions_triggered = true
				simulation.make_automatic_substitutions()
			if match_elapsed >= MATCH_REAL_DURATION:
				_finish_match()
		MatchPhase.INCIDENT_WINDOW:
			hud.update_incident_countdown(incident_director.remaining_time())
		MatchPhase.FEEDBACK:
			if phase_elapsed >= FEEDBACK_DURATION:
				_resume_play()


func _start_match() -> void:
	phase = MatchPhase.PRE_MATCH
	phase_elapsed = 0.0
	match_elapsed = 0.0
	evaluations.clear()
	current_incident = null
	pending_foul_awarded = false
	substitutions_triggered = false
	positioning_quality_total = 0.0
	positioning_sample_time = 0.0

	incident_director.cancel()
	incident_marker.hide_marker()
	decision_panel.hide_panel()
	results_panel.hide_panel()
	simulation.reset_match()
	referee.reset_to(REFEREE_START)
	referee.set_input_enabled(true)

	hud.set_match_minute(0.0)
	hud.set_score(0, 0)
	hud.set_phase("Les équipes entrent sur le terrain")
	hud.set_controls("ZQSD / Flèches : se déplacer  ·  Espace : siffler")
	hud.hide_incident()
	hud.hide_action_proximity()


func _begin_play() -> void:
	phase = MatchPhase.PLAYING
	phase_elapsed = 0.0
	simulation.start_match()
	hud.set_phase("Match en cours")
	hud.set_controls("Reste proche du ballon pour bien lire les duels.")


func _on_score_changed(blue_score: int, red_score: int) -> void:
	hud.set_score(blue_score, red_score)


func _on_event_announced(text: String) -> void:
	if phase in [MatchPhase.PRE_MATCH, MatchPhase.PLAYING]:
		hud.set_phase(text)


func _on_foul_committed(
	position: Vector2,
	_fouled_team_id: int,
	offender: DemoPlayer
) -> void:
	if phase != MatchPhase.PLAYING:
		return

	current_incident = INCIDENT_TEMPLATE.duplicate(true) as IncidentData
	current_incident.incident_position = position
	referee_observation_position = referee.global_position
	observation_distance = referee_observation_position.distance_to(position)
	observation_quality = positioning_model.proximity_quality(
		referee_observation_position,
		position,
		current_incident.maximum_observation_distance
	)
	observation_label = positioning_model.observation_label(
		observation_distance,
		current_incident.maximum_observation_distance
	)
	current_incident.maximum_response_time = (
		positioning_model.adjusted_response_window(
			current_incident.maximum_response_time,
			observation_distance,
			current_incident.maximum_observation_distance
		)
	)
	current_incident.title = (
		"Intervention de %s" % offender.display_name()
		if observation_distance <= current_incident.maximum_observation_distance + 120.0
		else "Contact difficile à identifier"
	)
	if _is_in_own_penalty_area(position, offender.team_id):
		current_incident.correct_technical_decision = (
			IncidentData.TechnicalDecision.PENALTY_KICK
		)
		current_incident.explanation = (
			"La faute directe est commise dans la surface de réparation "
			+ "du défenseur : un penalty et un avertissement sont attendus."
		)
	phase = MatchPhase.INCIDENT_WINDOW
	phase_elapsed = 0.0
	referee.set_movement_enabled(false)
	hud.hide_action_proximity()
	incident_director.activate(current_incident)


func _on_incident_started(incident: IncidentData) -> void:
	incident_marker.show_at(incident.incident_position, observation_quality)
	hud.set_phase("Incident en cours")
	hud.show_incident(
		observation_label,
		"Contact observé à %.0f m · Espace pour siffler" % (
			positioning_model.pixels_to_meters(observation_distance)
		)
	)
	hud.set_controls("Ta position au moment du contact est maintenant figée.")


func _on_whistle_requested() -> void:
	if phase != MatchPhase.INCIDENT_WINDOW:
		hud.set_controls("Aucun incident à juger pour le moment.")
		return

	decision_response_time = incident_director.resolve()
	phase = MatchPhase.DECISION
	phase_elapsed = 0.0
	referee.set_input_enabled(false)
	hud.hide_incident()
	hud.set_phase("Décision arbitrale")
	hud.set_controls("Choisis la reprise et la sanction.")
	decision_panel.show_for(current_incident)


func _on_decision_submitted(
	technical_choice: IncidentData.TechnicalDecision,
	discipline_choice: IncidentData.DisciplineDecision
) -> void:
	var result := evaluation_service.evaluate(
		current_incident,
		technical_choice,
		discipline_choice,
		referee_observation_position,
		decision_response_time
	)
	pending_foul_awarded = (
		technical_choice != IncidentData.TechnicalDecision.PLAY_ON
	)
	simulation.apply_referee_discipline(discipline_choice)
	_record_evaluation_and_show_feedback(result)


func _on_incident_expired(incident: IncidentData) -> void:
	if phase != MatchPhase.INCIDENT_WINDOW:
		return

	var result := evaluation_service.evaluate(
		incident,
		IncidentData.TechnicalDecision.PLAY_ON,
		IncidentData.DisciplineDecision.NO_CARD,
		referee_observation_position,
		incident.maximum_response_time
	)
	pending_foul_awarded = false
	_record_evaluation_and_show_feedback(result)


func _record_evaluation_and_show_feedback(result: Dictionary) -> void:
	evaluations.append(result)
	phase = MatchPhase.FEEDBACK
	phase_elapsed = 0.0
	incident_director.cancel()
	incident_marker.hide_marker()
	decision_panel.hide_panel()
	referee.set_input_enabled(false)
	hud.hide_action_proximity()
	hud.set_phase("Décision enregistrée")
	hud.show_incident(
		"%d / 100 SUR CETTE ACTION" % result["total_score"],
		"%s  %s" % [result["feedback"][0], result["feedback"][1]]
	)
	hud.set_controls("Le match va reprendre.")


func _resume_play() -> void:
	phase = MatchPhase.PLAYING
	phase_elapsed = 0.0
	current_incident = null
	referee.set_input_enabled(true)
	hud.hide_incident()
	hud.set_controls("Rapproche-toi du ballon avant le prochain duel.")
	simulation.resume_after_incident(pending_foul_awarded)


func _finish_match() -> void:
	if phase == MatchPhase.RESULTS:
		return

	phase = MatchPhase.RESULTS
	phase_elapsed = 0.0
	simulation.stop_match()
	incident_director.cancel()
	incident_marker.hide_marker()
	decision_panel.hide_panel()
	referee.set_input_enabled(false)
	hud.hide_action_proximity()
	hud.hide_incident()
	hud.set_phase("Coup de sifflet final")
	hud.set_controls("R pour rejouer ou retourne au menu.")
	results_panel.show_result(_aggregate_match_result())


func _is_in_own_penalty_area(position: Vector2, defending_team_id: int) -> bool:
	var inside_vertical_bounds := position.y >= 195.0 and position.y <= 525.0
	if not inside_vertical_bounds:
		return false
	return (
		position.x <= 229.0
		if defending_team_id == 0
		else position.x >= 1051.0
	)


func _update_positioning(delta: float) -> void:
	if simulation.possession_team == null:
		return
	var distance_to_action := referee.global_position.distance_to(ball.global_position)
	var quality := positioning_model.proximity_quality(
		referee.global_position,
		ball.global_position
	)
	positioning_quality_total += quality * delta
	positioning_sample_time += delta
	hud.set_action_proximity(
		quality,
		positioning_model.quality_label(quality),
		positioning_model.pixels_to_meters(distance_to_action)
	)


func _continuous_positioning_score() -> int:
	if positioning_sample_time <= 0.0:
		return 0
	return roundi(
		clampf(
			positioning_quality_total / positioning_sample_time,
			0.0,
			1.0
		) * 25.0
	)


func _aggregate_match_result() -> Dictionary:
	var continuous_positioning_score := _continuous_positioning_score()
	var positioning_percent := roundi(
		float(continuous_positioning_score) / 25.0 * 100.0
	)
	if evaluations.is_empty():
		return {
			"total_score": 75 + continuous_positioning_score,
			"technical_score": 40,
			"discipline_score": 20,
			"positioning_score": continuous_positioning_score,
			"response_score": 15,
			"feedback": PackedStringArray([
				"Aucune situation arbitrale n'a nécessité d'intervention.",
				"Proximité avec l'action : %d %%." % positioning_percent,
			]),
			"explanation": "Score final : %s." % simulation.scoreline(),
		}

	var count := evaluations.size()
	var technical_total: int = 0
	var discipline_total: int = 0
	var positioning_total: int = 0
	var response_total: int = 0

	for result in evaluations:
		technical_total += result["technical_score"]
		discipline_total += result["discipline_score"]
		positioning_total += result["positioning_score"]
		response_total += result["response_score"]

	var technical_score := roundi(float(technical_total) / (count * 40.0) * 40.0)
	var discipline_score := roundi(float(discipline_total) / (count * 20.0) * 20.0)
	var incident_positioning_score := roundi(
		float(positioning_total) / (count * 25.0) * 25.0
	)
	var positioning_score := roundi(
		incident_positioning_score * 0.5
		+ continuous_positioning_score * 0.5
	)
	var response_score := roundi(float(response_total) / (count * 15.0) * 15.0)

	return {
		"total_score": technical_score + discipline_score + positioning_score + response_score,
		"technical_score": technical_score,
		"discipline_score": discipline_score,
		"positioning_score": positioning_score,
		"response_score": response_score,
		"feedback": PackedStringArray([
			"%d situation(s) arbitrale(s) évaluée(s)." % count,
			"Score final du match : %s." % simulation.scoreline(),
			"Proximité avec l'action : %d %%." % positioning_percent,
		]),
		"explanation": (
			"Le placement combine la proximité avec l'action pendant le jeu "
			+ "et la distance d'observation au moment de chaque contact."
		),
	}
