extends SceneTree

const IncidentDataClass = preload("res://gameplay/incidents/incident_data.gd")
const EvaluationServiceClass = preload(
	"res://gameplay/evaluation/evaluation_service.gd"
)
const PositioningModelClass = preload(
	"res://gameplay/referee/positioning_model.gd"
)
const PerspectiveObservationModelClass = preload(
	"res://gameplay/perspective/perspective_observation_model.gd"
)
const AppScene: PackedScene = preload("res://core/app.tscn")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("Running Referee Simulator smoke tests...")
	_test_app_navigates_between_menu_and_solo_match()
	_test_detailed_foul_restart_flow()
	_test_visual_upgrade_and_ball_trajectory()
	_test_lawful_kickoff_and_restarts()
	_test_perfect_decision_scores_one_hundred()
	_test_wrong_decisions_keep_observation_points()
	_test_dynamic_referee_positioning()
	_test_perspective_observation_penalizes_angle_and_occlusion()
	_test_officiating_catalog_is_structured()
	_test_match_importance_scales_team_reactions()

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
	var menu := app.current_screen as MainMenu
	_expect_equal(
		menu.stadium_option.item_count,
		3,
		"menu exposes three home clubs and stadiums"
	)
	menu.stadium_option.select(1)
	menu.solo_requested.emit("qualifier")
	_expect_equal(
		app.current_screen is RefereePerspectiveMatch,
		true,
		"solo opens the referee-perspective match"
	)
	var match_scene := app.current_screen as RefereePerspectiveMatch
	_expect_equal(
		match_scene.match_importance_id,
		"qualifier",
		"selected match importance reaches the simulation"
	)
	_expect_equal(
		match_scene.stadium_profile["id"],
		"forge_united",
		"selected home stadium reaches the simulation"
	)
	_expect_equal(
		match_scene.get_node("Referee/Camera3D") is Camera3D,
		true,
		"referee owns the active ground-level camera"
	)
	_expect_equal(
		(
			match_scene.get_node("Referee/Camera3D") as Camera3D
		).position.y >= 2.0,
		true,
		"referee camera is raised above the previous eye line"
	)
	_expect_equal(
		match_scene.hud.minimap.players.size(),
		22,
		"minimap tracks every on-field player"
	)
	_expect_equal(
		match_scene.hud.minimap.tracked_ball,
		match_scene.ball,
		"minimap tracks the live ball"
	)
	_expect_equal(
		match_scene.hud.minimap.tracked_referee,
		match_scene.referee,
		"minimap tracks the referee"
	)
	_expect_equal(
		(
			match_scene.hud.minimap.world_to_map(
				Vector3(0.0, 0.0, -52.5)
			).y
			< match_scene.hud.minimap.world_to_map(
				Vector3(0.0, 0.0, 52.5)
			).y
		),
		true,
		"minimap preserves the pitch north-south orientation"
	)
	_expect_equal(
		match_scene.hud.minimap.view_direction_2d().length() > 0.99,
		true,
		"minimap exposes the referee viewing direction"
	)
	_expect_equal(
		match_scene.perspective_players.size(),
		22,
		"continuous perspective match fields two elevens"
	)
	_expect_equal(
		match_scene.assistants.size(),
		2,
		"two touchline assistants are present"
	)
	_expect_equal(
		match_scene.phase,
		RefereePerspectiveMatch.Phase.PRE_MATCH,
		"match waits for the referee's opening whistle"
	)
	match_scene._on_whistle_requested()
	_expect_equal(
		match_scene.phase,
		RefereePerspectiveMatch.Phase.PLAYING,
		"referee whistle starts the match"
	)
	match_scene._update_live_reading()
	_expect_equal(
		"BALLON" in match_scene.hud.ball_direction_label.text,
		true,
		"HUD continuously points toward the ball"
	)
	match_scene._register_offside_event(match_scene.blue_team[8])
	_expect_equal(
		match_scene.phase,
		RefereePerspectiveMatch.Phase.PLAYING,
		"assistant signal does not stop live play"
	)
	var assistant_flag_raised: bool = false
	for assistant in match_scene.assistants:
		if assistant.is_flag_raised():
			assistant_flag_raised = true
	_expect_equal(
		assistant_flag_raised,
		true,
		"offside raises an assistant flag"
	)
	match_scene._update_ground_truth(2.5)
	_expect_equal(
		match_scene.current_truth["var_alerted"],
		true,
		"VAR spontaneously flags a reviewable action"
	)
	_expect_equal(
		match_scene.var_referred_player,
		match_scene.blue_team[8],
		"VAR announcement names the player concerned by the review"
	)
	_expect_equal(
		match_scene.blue_team[8].var_marker.visible,
		true,
		"VAR-referred player receives a visible marker"
	)
	match_scene._on_whistle_requested()
	_expect_equal(
		match_scene.phase,
		RefereePerspectiveMatch.Phase.STOPPED_FOR_DECISION,
		"player whistle opens the officiating decision"
	)
	var paused_elapsed := match_scene.match_elapsed
	var paused_ball_position := match_scene.ball.global_position
	match_scene._process(1.0)
	_expect_equal(
		match_scene.match_elapsed,
		paused_elapsed,
		"match clock remains frozen during the decision"
	)
	_expect_equal(
		match_scene.ball.global_position,
		paused_ball_position,
		"ball remains frozen during the decision"
	)
	_expect_equal(
		match_scene.perspective_players[0].is_physics_processing(),
		false,
		"player simulation freezes during the decision"
	)
	_expect_equal(
		match_scene.assistants[0].is_processing(),
		false,
		"assistant movement freezes during the decision"
	)
	_expect_equal(
		match_scene.referee.movement_enabled,
		true,
		"referee can still walk while play is frozen"
	)
	_expect_equal(
		match_scene.referee.look_enabled,
		true,
		"referee can still look around while inspecting players"
	)
	_expect_equal(
		OfficiatingPanel.SIMPLE_ACTIONS.size(),
		2,
		"stoppage menu only exposes foul and offside"
	)
	match_scene.officiating_panel._unhandled_input(
		_pressed_physical_key(KEY_AMPERSAND, KEY_1)
	)
	_expect_equal(
		match_scene.officiating_panel.selected_action_id,
		"fouls",
		"AZERTY number row selects the foul action"
	)
	match_scene.officiating_panel._unhandled_input(_pressed_key(KEY_3))
	_expect_equal(
		"Revue recommandée" in match_scene.officiating_panel.var_label.text,
		true,
		"referee can request a VAR review from the simple panel"
	)
	match_scene.officiating_panel._unhandled_input(_pressed_key(KEY_2))
	match_scene.officiating_panel.set_look_target(match_scene.blue_team[8])
	match_scene.officiating_panel._unhandled_input(_pressed_key(KEY_E))
	_expect_equal(
		match_scene.officiating_panel.selected_player(),
		match_scene.blue_team[8],
		"referee identifies the player currently in the crosshair"
	)
	match_scene.officiating_panel._unhandled_input(_pressed_key(KEY_ENTER))
	_expect_equal(
		match_scene.phase,
		RefereePerspectiveMatch.Phase.PLAYING,
		"decision applies a restart and resumes the match"
	)
	_expect_equal(
		match_scene.assistants[0].is_processing(),
		true,
		"assistant movement resumes with play"
	)
	_expect_equal(
		match_scene.perspective_players[0].is_physics_processing(),
		true,
		"player simulation resumes with play"
	)
	app.current_screen.main_menu_requested.emit()
	_expect_equal(app.current_screen is MainMenu, true, "match returns to menu")

	app.free()


func _test_detailed_foul_restart_flow() -> void:
	var match_scene := preload(
		"res://gameplay/perspective/referee_perspective_match.tscn"
	).instantiate() as RefereePerspectiveMatch
	root.add_child(match_scene)
	match_scene._on_whistle_requested()
	match_scene._on_whistle_requested()
	var restart_position := match_scene.whistle_position
	_expect_equal(
		match_scene.restart_marker.visible,
		true,
		"whistle displays the remembered restart location"
	)
	_expect_equal(
		Vector2(
			match_scene.restart_marker.global_position.x,
			match_scene.restart_marker.global_position.z
		).is_equal_approx(
			Vector2(restart_position.x, restart_position.z)
		),
		true,
		"restart marker matches the ball position at the whistle"
	)

	var panel := match_scene.officiating_panel
	panel._unhandled_input(_pressed_key(KEY_1))
	panel._unhandled_input(_pressed_key(KEY_5))
	_expect_equal(
		panel.selected_restart_id,
		"penalty_kick",
		"foul flow allows a penalty restart"
	)
	panel._unhandled_input(_pressed_key(KEY_4))
	panel._unhandled_input(_pressed_key(KEY_8))
	panel.set_look_target(match_scene.red_team[4])
	panel._unhandled_input(_pressed_key(KEY_E))
	_expect_equal(
		panel.selected_discipline_id == "yellow_card"
			and panel.awarded_team_id == 0,
		true,
		"foul flow captures sanction and sensible beneficiary"
	)
	panel._unhandled_input(_pressed_key(KEY_T))
	panel._unhandled_input(_pressed_key(KEY_T))
	_expect_equal(
		panel.awarded_team_id,
		0,
		"referee can toggle the team receiving the restart"
	)
	panel._unhandled_input(_pressed_key(KEY_ENTER))
	_expect_equal(
		match_scene.red_team[4].caution_count,
		1,
		"selected yellow card is applied to the identified offender"
	)
	_expect_equal(
		match_scene.possession_team_id,
		0,
		"selected team receives possession"
	)
	_expect_equal(
		Vector2(
			match_scene.ball.global_position.x,
			match_scene.ball.global_position.z
		).is_equal_approx(
			Vector2(restart_position.x, restart_position.z)
		),
		true,
		"free kick restarts from the remembered whistle location"
	)
	_expect_equal(
		match_scene.restart_marker.visible,
		false,
		"restart marker hides when play resumes"
	)

	var victim := match_scene.blue_team[8]
	var offender := match_scene.red_team[5]
	match_scene._set_possession(0, victim)
	match_scene.current_truth = {
		"category_id": "fouls",
		"offence_id": "reckless_tackle",
		"restart_id": "direct_free_kick",
		"discipline_id": "yellow_card",
		"offender": offender,
		"affected": victim,
		"position": victim.global_position,
		"advantage_available": true,
	}
	match_scene._on_advantage_requested()
	_expect_equal(
		match_scene.phase == RefereePerspectiveMatch.Phase.PLAYING
			and match_scene.current_truth.is_empty()
			and match_scene.possession_team_id == 0,
		true,
		"advantage keeps play and possession alive without a whistle"
	)
	match_scene.free()


func _test_visual_upgrade_and_ball_trajectory() -> void:
	var match_scene := preload(
		"res://gameplay/perspective/referee_perspective_match.tscn"
	).instantiate() as RefereePerspectiveMatch
	root.add_child(match_scene)
	_expect_equal(
		match_scene.world_root.find_children(
			"MowingStripe*",
			"MeshInstance3D",
			true,
			false
		).size() >= 5,
		true,
		"pitch includes alternating mowing stripes"
	)
	_expect_equal(
		match_scene.world_root.find_children(
			"MowingStripe*",
			"MeshInstance3D",
			true,
			false
		).size() >= 20,
		true,
		"pitch uses dense professional mowing bands"
	)
	_expect_equal(
		match_scene.world_root.find_children(
			"StandTier*",
			"MeshInstance3D",
			true,
			false
		).size() >= 30,
		true,
		"stadium bowl includes stepped seating tiers"
	)
	_expect_equal(
		match_scene.world_root.find_children(
			"StadiumFloodlight*",
			"OmniLight3D",
			true,
			false
		).size(),
		4,
		"stadium includes four themed floodlights"
	)
	_expect_equal(
		match_scene.world_root.find_children(
			"*Arc*",
			"MeshInstance3D",
			true,
			false
		).size() >= 60,
		true,
		"pitch includes penalty and corner arc markings"
	)
	_expect_equal(
		match_scene.world_root.find_children(
			"GoalNetVertical*",
			"MeshInstance3D",
			true,
			false
		).size() >= 12,
		true,
		"goals include visible net meshes"
	)

	var start := Vector3(0.0, 0.22, 0.0)
	match_scene.ball.global_position = start
	match_scene._start_ball_flight(
		Vector3(0.0, 0.22, -12.0),
		1.0,
		1.0,
		0.6
	)
	match_scene._update_ball_flight(
		match_scene.ball_flight_duration * 0.5
	)
	_expect_equal(
		match_scene.ball.global_position.y > 1.1,
		true,
		"ball flight follows a lofted parabolic trajectory"
	)
	_expect_equal(
		absf(match_scene.ball.global_position.x) > 0.45,
		true,
		"ball flight supports lateral curl"
	)
	_expect_equal(
		match_scene.ball_shadow.global_position.y < 0.03,
		true,
		"ball shadow remains projected onto the pitch"
	)

	var player := match_scene.perspective_players[0]
	player._animate_run(0.12)
	_expect_equal(
		absf(player.left_leg_pivot.rotation.x) > 0.01,
		true,
		"player rig animates limbs while running"
	)
	_expect_equal(
		player.left_knee_pivot != null
			and player.right_knee_pivot != null
			and player.left_elbow_pivot != null
			and player.right_elbow_pivot != null,
		true,
		"player rig includes articulated knees and elbows"
	)
	player.reset_pose()
	player.stumble(1.8, 72.0)
	_expect_equal(
		is_zero_approx(player.visual_root.rotation.z),
		true,
		"foul reaction begins from the current pose instead of snapping down"
	)
	player._physics_process(0.42)
	_expect_equal(
		absf(player.visual_root.rotation.z) > 0.05
			and absf(player.visual_root.rotation.z) < deg_to_rad(72.0),
		true,
		"foul reaction eases through a visible loss of balance"
	)
	player.reset_for_match()
	player.perform_tackle(Vector3.FORWARD)
	player._physics_process(0.34)
	_expect_equal(
		maxf(
			absf(player.left_leg_pivot.rotation.x),
			absf(player.right_leg_pivot.rotation.x)
		) > 0.35,
		true,
		"offending player performs an articulated tackle"
	)
	match_scene.free()


func _test_lawful_kickoff_and_restarts() -> void:
	var match_scene := preload(
		"res://gameplay/perspective/referee_perspective_match.tscn"
	).instantiate() as RefereePerspectiveMatch
	root.add_child(match_scene)

	var own_halves_are_legal := true
	for player in match_scene.perspective_players:
		own_halves_are_legal = own_halves_are_legal and (
			FootballLaws3D.is_in_own_half(
				player.global_position,
				player.team_id,
				false
			)
		)
	_expect_equal(
		own_halves_are_legal,
		true,
		"every player starts in their own half"
	)

	var opponents_respect_center_circle := true
	for opponent in match_scene.red_team:
		opponents_respect_center_circle = (
			opponents_respect_center_circle
			and FootballLaws3D.respects_kickoff_distance(
				opponent.global_position,
				0,
				opponent.team_id,
				false
			)
		)
	_expect_equal(
		opponents_respect_center_circle,
		true,
		"kickoff opponents remain 9.15 metres from the ball"
	)
	_expect_equal(
		Vector2(
			match_scene.ball.global_position.x,
			match_scene.ball.global_position.z
		).is_zero_approx(),
		true,
		"kickoff ball is stationary on the centre mark"
	)

	match_scene._on_whistle_requested()
	_expect_equal(
		match_scene.ball_in_flight
			and match_scene.pending_action == "pass"
			and match_scene.ball_flight_start.distance_to(
				match_scene.ball_flight_target
			) > 0.5,
		true,
		"kickoff enters play only after the whistle and a clear kick"
	)

	_expect_equal(
		FootballLaws3D.is_offside_position(
			Vector3(0.0, 0.0, -30.0),
			Vector3(0.0, 0.0, -32.0),
			-20.0,
			0,
			false
		),
		false,
		"receiver behind the ball is not offside"
	)
	_expect_equal(
		FootballLaws3D.is_offside_position(
			Vector3(0.0, 0.0, -35.0),
			Vector3(0.0, 0.0, -25.0),
			-30.0,
			0,
			false
		),
		true,
		"receiver beyond ball and second-last defender is offside"
	)

	var shooter := match_scene.blue_team[9]
	match_scene.ball_in_flight = false
	match_scene._set_possession(0, shooter)
	match_scene.pending_action = "shot"
	match_scene.pending_shooter = shooter
	match_scene.pending_shot_scores = false
	match_scene._resolve_ball_flight()
	_expect_equal(
		match_scene.possession_team_id,
		1,
		"missed shot awards the defending team a goal kick"
	)
	_expect_equal(
		match_scene.ball_in_flight
			and match_scene.pending_action == "pass"
			and match_scene.ball_flight_start.z < -36.0,
		true,
		"goal kick is clearly taken from the defending goal area"
	)

	match_scene.match_elapsed = (
		RefereePerspectiveMatch.HALF_REAL_DURATION - 0.01
	)
	match_scene.phase = RefereePerspectiveMatch.Phase.PLAYING
	match_scene._process(0.02)
	_expect_equal(
		match_scene.phase,
		RefereePerspectiveMatch.Phase.HALF_TIME,
		"match stops at half-time"
	)
	match_scene._on_whistle_requested()
	_expect_equal(
		match_scene.phase == RefereePerspectiveMatch.Phase.PLAYING
			and match_scene.second_half,
		true,
		"referee whistle starts the second half"
	)
	var switched_halves_are_legal := true
	for player in match_scene.perspective_players:
		switched_halves_are_legal = switched_halves_are_legal and (
			FootballLaws3D.is_in_own_half(
				player.global_position,
				player.team_id,
				true
			)
		)
	_expect_equal(
		switched_halves_are_legal,
		true,
		"teams change ends for the second half"
	)
	_expect_equal(
		FootballLaws3D.is_penalty_area(
			Vector3(0.0, 0.0, -42.0),
			0,
			true
		),
		true,
		"penalty areas follow the defending team after ends change"
	)
	match_scene.free()


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


func _test_perspective_observation_penalizes_angle_and_occlusion() -> void:
	var clear = PerspectiveObservationModelClass.evaluate(
		Vector3(0.0, 1.7, 12.0),
		Vector3(0.0, 0.0, -1.0),
		Vector3(0.0, 0.4, 0.0),
		false
	)
	var angled = PerspectiveObservationModelClass.evaluate(
		Vector3(0.0, 1.7, 12.0),
		Vector3(1.0, 0.0, 0.0),
		Vector3(0.0, 0.4, 0.0),
		false
	)
	var occluded = PerspectiveObservationModelClass.evaluate(
		Vector3(0.0, 1.7, 12.0),
		Vector3(0.0, 0.0, -1.0),
		Vector3(0.0, 0.4, 0.0),
		true
	)
	_expect_equal(clear["quality"] > angled["quality"], true, "view angle affects evidence")
	_expect_equal(
		clear["quality"] > occluded["quality"],
		true,
		"player occlusion affects evidence"
	)


func _test_officiating_catalog_is_structured() -> void:
	var categories: Array = OfficiatingCatalog.categories()
	var offence_count: int = 0
	for category in categories:
		offence_count += category["offences"].size()
	_expect_equal(categories.size() >= 6, true, "officiating catalogue has clear families")
	_expect_equal(
		offence_count >= 35,
		true,
		"officiating catalogue covers practical offence types"
	)
	_expect_equal(
		OfficiatingCatalog.restarts().size(),
		9,
		"restart catalogue covers standard restarts"
	)


func _test_match_importance_scales_team_reactions() -> void:
	var expected := {
		"offence_id": "reckless_tackle",
		"restart_id": "direct_free_kick",
		"discipline_id": "yellow_card",
		"offender_team_id": 0,
		"affected_team_id": 1,
	}
	var wrong_decision := {
		"offence_id": "no_offence",
		"restart_id": "play_on",
		"discipline_id": "none",
		"offender_team_id": -1,
	}
	var simplified_foul := {
		"category_id": "fouls",
		"offence_id": "careless_tackle",
		"restart_id": "direct_free_kick",
		"discipline_id": "none",
		"offender_team_id": 0,
		"offender_instance_id": 42,
		"simplified": true,
	}
	expected["category_id"] = "fouls"
	expected["offender_instance_id"] = 42
	var friendly := MatchIntensityModel.evaluate_reaction(
		expected,
		wrong_decision,
		"friendly"
	)
	var final := MatchIntensityModel.evaluate_reaction(
		expected,
		wrong_decision,
		"final"
	)
	var simplified_result := MatchIntensityModel.evaluate_reaction(
		expected,
		simplified_foul,
		"group_stage"
	)
	_expect_equal(
		float(final["red_delta"]) > float(friendly["red_delta"]),
		true,
		"high-stakes matches amplify the wronged team's reaction"
	)
	_expect_equal(
		float(simplified_result["quality"]),
		1.0,
		"simplified foul choice is not punished for hidden sub-options"
	)
	_expect_equal(
		MatchIntensityModel.control_state(96.0, 30.0)["id"],
		"chaos",
		"extreme tension makes the match uncontrollable"
	)
	_expect_equal(
		MatchIntensityModel.foul_interval_multiplier(90.0, 20.0) < 0.6,
		true,
		"high tension increases foul frequency"
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


func _pressed_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _pressed_physical_key(
	keycode: Key,
	physical_keycode: Key
) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = physical_keycode
	event.pressed = true
	return event


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("  PASS: %s" % label)
		return

	failures += 1
	push_error("  FAIL: %s — expected %s, got %s" % [label, expected, actual])
