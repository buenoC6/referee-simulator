extends Node
class_name RefereeSimulatorApp

const MAIN_MENU_SCENE: PackedScene = preload("res://ui/main_menu/main_menu.tscn")
const MATCH_SCENE: PackedScene = preload(
	"res://gameplay/perspective/referee_perspective_match.tscn"
)
const GAME_MODE_CATALOG := preload(
	"res://gameplay/modes/game_mode_catalog.gd"
)

var current_screen: Node
var current_mode_id: String = GAME_MODE_CATALOG.QUICK_MATCH_ID
var current_stage_index: int = 0
var current_quick_importance_id: String = "group_stage"
var current_stadium_id: String = StadiumCatalog.DEFAULT_ID
var current_session_seed: int = 1
var current_debug_tools_enabled: bool = false


func _ready() -> void:
	show_main_menu()


func show_main_menu() -> void:
	get_tree().paused = false
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	_replace_screen(menu)
	menu.solo_requested.connect(
		func(match_importance_id: String) -> void:
			start_game_mode(
				menu.selected_game_mode_id(),
				match_importance_id,
				menu.selected_stadium_id(),
				menu.selected_match_seed(),
				menu.debug_tools_enabled()
			)
	)
	menu.quit_requested.connect(_quit_game)


func start_solo_match(
	match_importance_id: String = "group_stage",
	stadium_id: String = StadiumCatalog.DEFAULT_ID,
	match_seed: int = 1,
	debug_tools_enabled: bool = false
) -> void:
	start_game_mode(
		GAME_MODE_CATALOG.QUICK_MATCH_ID,
		match_importance_id,
		stadium_id,
		match_seed,
		debug_tools_enabled
	)


func start_game_mode(
	mode_id: String,
	match_importance_id: String = "group_stage",
	stadium_id: String = StadiumCatalog.DEFAULT_ID,
	session_seed: int = 1,
	debug_tools_enabled: bool = false
) -> void:
	current_mode_id = str(GAME_MODE_CATALOG.profile(mode_id)["id"])
	current_stage_index = 0
	current_quick_importance_id = match_importance_id
	current_stadium_id = stadium_id
	current_session_seed = maxi(session_seed, 1)
	current_debug_tools_enabled = debug_tools_enabled
	_launch_current_match()


func _launch_current_match() -> void:
	var stage_profile := GAME_MODE_CATALOG.stage(
		current_mode_id,
		current_stage_index
	)
	var importance_id := (
		current_quick_importance_id
		if current_mode_id == GAME_MODE_CATALOG.QUICK_MATCH_ID
		else str(stage_profile["importance_id"])
	)
	var current_match_seed := GAME_MODE_CATALOG.match_seed(
		current_session_seed,
		current_stage_index
	)
	var match_scene := MATCH_SCENE.instantiate() as RefereePerspectiveMatch
	match_scene.configure_match(
		importance_id,
		current_stadium_id,
		current_match_seed,
		current_debug_tools_enabled,
		current_mode_id,
		current_stage_index
	)
	_replace_screen(match_scene)
	match_scene.main_menu_requested.connect(show_main_menu)
	match_scene.continue_mode_requested.connect(_continue_game_mode)


func _continue_game_mode() -> void:
	if GAME_MODE_CATALOG.is_last_stage(
		current_mode_id,
		current_stage_index
	):
		show_main_menu()
		return
	current_stage_index += 1
	_launch_current_match()


func _replace_screen(next_screen: Node) -> void:
	if is_instance_valid(current_screen):
		remove_child(current_screen)
		current_screen.queue_free()

	current_screen = next_screen
	add_child(current_screen)


func _quit_game() -> void:
	get_tree().quit()
