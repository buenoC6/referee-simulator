extends Node
class_name RefereeSimulatorApp

const MAIN_MENU_SCENE: PackedScene = preload("res://ui/main_menu/main_menu.tscn")
const MATCH_SCENE: PackedScene = preload(
	"res://gameplay/perspective/referee_perspective_match.tscn"
)

var current_screen: Node


func _ready() -> void:
	show_main_menu()


func show_main_menu() -> void:
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	_replace_screen(menu)
	menu.solo_requested.connect(
		func(match_importance_id: String) -> void:
			start_solo_match(
				match_importance_id,
				menu.selected_stadium_id()
			)
	)
	menu.quit_requested.connect(_quit_game)


func start_solo_match(
	match_importance_id: String = "group_stage",
	stadium_id: String = StadiumCatalog.DEFAULT_ID
) -> void:
	var match_scene := MATCH_SCENE.instantiate() as RefereePerspectiveMatch
	match_scene.configure_match(match_importance_id, stadium_id)
	_replace_screen(match_scene)
	match_scene.main_menu_requested.connect(show_main_menu)


func _replace_screen(next_screen: Node) -> void:
	if is_instance_valid(current_screen):
		current_screen.queue_free()

	current_screen = next_screen
	add_child(current_screen)


func _quit_game() -> void:
	get_tree().quit()
