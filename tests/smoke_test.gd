extends SceneTree

const IncidentDataClass = preload("res://gameplay/incidents/incident_data.gd")
const EvaluationServiceClass = preload(
	"res://gameplay/evaluation/evaluation_service.gd"
)
const AppScene: PackedScene = preload("res://core/app.tscn")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("Running Referee Simulator smoke tests...")
	_test_app_navigates_between_menu_and_solo_match()
	_test_perfect_decision_scores_one_hundred()
	_test_wrong_decisions_keep_observation_points()

	if failures == 0:
		print("PASS: all smoke tests succeeded.")
		quit(0)
	else:
		push_error("FAIL: %d smoke test assertion(s) failed." % failures)
		quit(1)


func _test_app_navigates_between_menu_and_solo_match() -> void:
	var app = AppScene.instantiate()
	root.add_child(app)

	_expect_equal(app.current_screen is MainMenu, true, "app starts on main menu")
	app.current_screen.solo_requested.emit()
	_expect_equal(app.current_screen is RefereeMatch, true, "solo opens a match")
	app.current_screen.main_menu_requested.emit()
	_expect_equal(app.current_screen is MainMenu, true, "match returns to menu")

	app.free()


func _test_perfect_decision_scores_one_hundred() -> void:
	var incident = _make_incident()
	var service = EvaluationServiceClass.new()
	var result: Dictionary = service.evaluate(
		incident,
		IncidentDataClass.TechnicalDecision.DIRECT_FREE_KICK,
		IncidentDataClass.DisciplineDecision.YELLOW_CARD,
		Vector2(650.0, 300.0),
		1.0
	)

	_expect_equal(result["total_score"], 100, "perfect decision total")
	_expect_equal(result["technical_score"], 40, "perfect technical score")
	_expect_equal(result["discipline_score"], 20, "perfect discipline score")
	_expect_equal(result["positioning_score"], 25, "perfect positioning score")
	_expect_equal(result["response_score"], 15, "perfect response score")


func _test_wrong_decisions_keep_observation_points() -> void:
	var incident = _make_incident()
	var service = EvaluationServiceClass.new()
	var result: Dictionary = service.evaluate(
		incident,
		IncidentDataClass.TechnicalDecision.PLAY_ON,
		IncidentDataClass.DisciplineDecision.NO_CARD,
		Vector2(650.0, 300.0),
		1.0
	)

	_expect_equal(result["total_score"], 40, "wrong decision total")
	_expect_equal(result["technical_score"], 0, "wrong technical score")
	_expect_equal(result["discipline_score"], 0, "wrong discipline score")
	_expect_equal(result["positioning_score"], 25, "observation score remains")
	_expect_equal(result["response_score"], 15, "response score remains")


func _make_incident():
	var incident = IncidentDataClass.new()
	incident.incident_id = &"TEST-001"
	incident.title = "Test incident"
	incident.correct_technical_decision = (
		IncidentDataClass.TechnicalDecision.DIRECT_FREE_KICK
	)
	incident.correct_discipline_decision = (
		IncidentDataClass.DisciplineDecision.YELLOW_CARD
	)
	incident.incident_position = Vector2(500.0, 300.0)
	incident.minimum_observation_distance = 90.0
	incident.maximum_observation_distance = 230.0
	incident.maximum_response_time = 4.0
	return incident


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("  PASS: %s" % label)
		return

	failures += 1
	push_error("  FAIL: %s — expected %s, got %s" % [label, expected, actual])
