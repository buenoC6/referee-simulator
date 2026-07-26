extends SceneTree

const IncidentDataClass = preload("res://gameplay/incidents/incident_data.gd")
const EvaluationServiceClass = preload(
	"res://gameplay/evaluation/evaluation_service.gd"
)
const PositioningModelClass = preload(
	"res://gameplay/referee/positioning_model.gd"
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
	_test_dynamic_referee_positioning()

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
	var match_scene := app.current_screen as RefereeMatch
	_expect_equal(
		(match_scene.get_node("BlueTeam") as FootballTeam).players.size(),
		11,
		"blue team fields eleven players"
	)
	_expect_equal(
		(match_scene.get_node("RedTeam") as FootballTeam).players.size(),
		11,
		"red team fields eleven players"
	)
	var blue_team := match_scene.get_node("BlueTeam") as FootballTeam
	var red_team := match_scene.get_node("RedTeam") as FootballTeam
	_expect_equal(blue_team.profiles.size(), 16, "blue match sheet has sixteen players")
	_expect_equal(blue_team.substitute_count(), 5, "blue bench starts with five substitutes")
	_test_roster_discipline_and_substitution(blue_team, red_team)
	_test_basic_rules(match_scene, blue_team, red_team)
	app.current_screen.main_menu_requested.emit()
	_expect_equal(app.current_screen is MainMenu, true, "match returns to menu")

	app.free()


func _test_roster_discipline_and_substitution(
	blue_team: FootballTeam,
	red_team: FootballTeam
) -> void:
	var cautioned_player := blue_team.get_player_by_number(2)
	_expect_equal(
		blue_team.apply_yellow_card(cautioned_player),
		false,
		"first yellow does not send the player off"
	)
	_expect_equal(cautioned_player.profile.yellow_cards, 1, "yellow card is stored on profile")
	_expect_equal(
		blue_team.apply_yellow_card(cautioned_player),
		true,
		"second yellow sends the player off"
	)
	_expect_equal(blue_team.on_field_count(), 10, "sent-off team continues with ten")

	var substitution: Dictionary = red_team.make_automatic_substitution()
	_expect_equal(substitution.is_empty(), false, "automatic substitution is available")
	_expect_equal(red_team.on_field_count(), 11, "substitution keeps eleven on field")
	_expect_equal(red_team.substitute_count(), 4, "one substitute entered the field")


func _test_basic_rules(
	match_scene: RefereeMatch,
	blue_team: FootballTeam,
	red_team: FootballTeam
) -> void:
	var rules := match_scene.get_node("FootballRulesEngine") as FootballRulesEngine
	_expect_equal(
		rules.is_ball_out(Vector2(640.0, 50.0)),
		true,
		"ball wholly beyond touchline is out"
	)
	_expect_equal(
		rules.is_ball_out(Vector2(640.0, 360.0)),
		false,
		"ball inside field remains in play"
	)

	var receiver := blue_team.get_player_by_number(9)
	receiver.global_position = Vector2(1110.0, 360.0)
	var red_defenders := red_team.players.duplicate()
	for index in range(red_defenders.size()):
		red_defenders[index].global_position.x = 1020.0 - index * 18.0
	_expect_equal(
		rules.is_offside_position(
			receiver,
			blue_team,
			red_team,
			Vector2(950.0, 360.0)
		),
		true,
		"advanced receiver is in an offside position"
	)
	_expect_equal(
		rules.is_offside_position(
			receiver,
			blue_team,
			red_team,
			Vector2(1140.0, 360.0)
		),
		false,
		"receiver behind the ball is onside"
	)


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


func _test_dynamic_referee_positioning() -> void:
	var model = PositioningModelClass.new()
	var action_position := Vector2(760.0, 330.0)
	_expect_equal(
		model.proximity_quality(
			action_position + Vector2(180.0, 0.0),
			action_position
		),
		1.0,
		"nearby referee has a clear view"
	)
	_expect_equal(
		model.proximity_quality(
			action_position + Vector2(560.0, 0.0),
			action_position
		),
		0.0,
		"distant referee loses sight of the action"
	)
	_expect_equal(
		model.adjusted_response_window(4.0, 470.0, 230.0) < 4.0,
		true,
		"poor observation shortens the decision window"
	)


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
	incident.minimum_observation_distance = 0.0
	incident.maximum_observation_distance = 230.0
	incident.maximum_response_time = 4.0
	return incident


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("  PASS: %s" % label)
		return

	failures += 1
	push_error("  FAIL: %s — expected %s, got %s" % [label, expected, actual])
