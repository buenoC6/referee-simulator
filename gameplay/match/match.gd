extends Node2D
class_name RefereeMatch

enum MatchPhase {
	INTRO,
	BUILDUP,
	INCIDENT_WINDOW,
	DECISION,
	RESULTS,
}

const SCENARIO: IncidentData = preload(
	"res://gameplay/incidents/sit_001_reckless_tackle.tres"
)

const REFEREE_START := Vector2(630.0, 565.0)
const ATTACKER_START := Vector2(410.0, 330.0)
const DEFENDER_START := Vector2(920.0, 332.0)
const BLUE_SUPPORT_START := Vector2(380.0, 485.0)
const RED_SUPPORT_START := Vector2(910.0, 205.0)
const BUILDUP_DURATION := 3.35
const INTRO_DURATION := 1.15

@onready var referee: Referee = $Referee
@onready var attacker: DemoPlayer = $BlueAttacker
@onready var defender: DemoPlayer = $RedDefender
@onready var blue_support: DemoPlayer = $BlueSupport
@onready var red_support: DemoPlayer = $RedSupport
@onready var ball: MatchBall = $MatchBall
@onready var incident_marker: IncidentMarker = $IncidentMarker
@onready var incident_director: IncidentDirector = $IncidentDirector
@onready var hud: MatchHud = $MatchHud
@onready var decision_panel: DecisionPanel = $DecisionPanel
@onready var results_panel: ResultsPanel = $ResultsPanel

var phase := MatchPhase.INTRO
var phase_elapsed: float = 0.0
var match_elapsed: float = 0.0
var referee_position_at_decision := Vector2.ZERO
var decision_response_time: float = 0.0
var evaluation_service := EvaluationService.new()


func _ready() -> void:
	referee.whistle_requested.connect(_on_whistle_requested)
	incident_director.incident_started.connect(_on_incident_started)
	incident_director.incident_expired.connect(_on_incident_expired)
	decision_panel.decision_submitted.connect(_on_decision_submitted)
	results_panel.replay_requested.connect(_start_round)
	_start_round()


func _process(delta: float) -> void:
	if phase not in [MatchPhase.DECISION, MatchPhase.RESULTS]:
		match_elapsed += delta
		hud.set_match_time(match_elapsed)

	phase_elapsed += delta
	match phase:
		MatchPhase.INTRO:
			if phase_elapsed >= INTRO_DURATION:
				_begin_buildup()
		MatchPhase.BUILDUP:
			if phase_elapsed >= BUILDUP_DURATION:
				_trigger_incident()
		MatchPhase.INCIDENT_WINDOW:
			hud.update_incident_countdown(incident_director.remaining_time())


func _start_round() -> void:
	phase = MatchPhase.INTRO
	phase_elapsed = 0.0
	match_elapsed = 0.0
	incident_director.cancel()
	incident_marker.hide_marker()
	decision_panel.hide_panel()
	results_panel.hide_panel()

	referee.reset_to(REFEREE_START)
	referee.set_input_enabled(true)
	attacker.reset_to(ATTACKER_START)
	defender.reset_to(DEFENDER_START)
	blue_support.reset_to(BLUE_SUPPORT_START)
	red_support.reset_to(RED_SUPPORT_START)
	ball.reset_to(ATTACKER_START + Vector2(22.0, 6.0))

	hud.set_match_time(0.0)
	hud.set_phase("Mise en place")
	hud.set_controls("ZQSD / Flèches : se déplacer  ·  Espace : siffler")
	hud.hide_incident()


func _begin_buildup() -> void:
	phase = MatchPhase.BUILDUP
	phase_elapsed = 0.0
	hud.set_phase("Suivre l'action")
	hud.set_controls("Reste proche de l'action sans gêner les joueurs.")

	attacker.move_to(Vector2(748.0, 336.0), 102.0)
	defender.move_to(Vector2(770.0, 336.0), 45.0)
	blue_support.move_to(Vector2(650.0, 480.0), 82.0)
	red_support.move_to(Vector2(720.0, 205.0), 58.0)
	ball.follow(attacker)


func _trigger_incident() -> void:
	if phase != MatchPhase.BUILDUP:
		return

	phase = MatchPhase.INCIDENT_WINDOW
	phase_elapsed = 0.0
	attacker.stop()
	defender.stop()
	blue_support.stop()
	red_support.stop()
	ball.freeze_at(SCENARIO.incident_position + Vector2(-12.0, 9.0))
	incident_director.activate(SCENARIO)


func _on_incident_started(incident: IncidentData) -> void:
	incident_marker.show_at(incident.incident_position)
	hud.set_phase("Incident en cours")
	hud.show_incident("CONTACT !", "Espace pour siffler")
	hud.set_controls("Décide vite : siffler ou laisser jouer.")


func _on_whistle_requested() -> void:
	if phase != MatchPhase.INCIDENT_WINDOW:
		hud.set_controls("Aucun incident à juger pour le moment.")
		return

	referee_position_at_decision = referee.global_position
	decision_response_time = incident_director.resolve()
	phase = MatchPhase.DECISION
	phase_elapsed = 0.0
	referee.set_input_enabled(false)
	hud.hide_incident()
	hud.set_phase("Décision")
	hud.set_controls("Choisis la reprise et la sanction.")
	decision_panel.show_for(SCENARIO)


func _on_decision_submitted(
	technical_choice: IncidentData.TechnicalDecision,
	discipline_choice: IncidentData.DisciplineDecision
) -> void:
	var result := evaluation_service.evaluate(
		SCENARIO,
		technical_choice,
		discipline_choice,
		referee_position_at_decision,
		decision_response_time
	)
	_finish_round(result)


func _on_incident_expired(incident: IncidentData) -> void:
	if phase != MatchPhase.INCIDENT_WINDOW:
		return

	referee_position_at_decision = referee.global_position
	var result := evaluation_service.evaluate(
		incident,
		IncidentData.TechnicalDecision.PLAY_ON,
		IncidentData.DisciplineDecision.NO_CARD,
		referee_position_at_decision,
		incident.maximum_response_time
	)
	_finish_round(result)


func _finish_round(result: Dictionary) -> void:
	phase = MatchPhase.RESULTS
	phase_elapsed = 0.0
	incident_director.cancel()
	incident_marker.hide_marker()
	referee.set_input_enabled(false)
	attacker.stop()
	defender.stop()
	blue_support.stop()
	red_support.stop()
	decision_panel.hide_panel()
	hud.hide_incident()
	hud.set_phase("Rapport")
	hud.set_controls("R pour rejouer la situation.")
	results_panel.show_result(result)
