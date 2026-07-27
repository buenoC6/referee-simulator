extends Control
class_name MainMenu

const STADIUM_CATALOG := preload(
	"res://gameplay/perspective/stadium_catalog.gd"
)
const GAME_MODE_CATALOG := preload(
	"res://gameplay/modes/game_mode_catalog.gd"
)

signal solo_requested(match_importance_id: String)
signal quit_requested

@onready var solo_button: Button = %SoloButton
@onready var quit_button: Button = %QuitButton
@onready var quick_match_button: Button = %QuickMatchButton
@onready var tournament_button: Button = %TournamentButton
@onready var career_button: Button = %CareerButton
@onready var mode_description: Label = %ModeDescription
@onready var setup_subtitle: Label = %SetupSubtitle
@onready var importance_title: Label = %ImportanceTitle
@onready var importance_option: OptionButton = %ImportanceOption
@onready var importance_description: Label = %ImportanceDescription
@onready var stadium_option: OptionButton = %StadiumOption
@onready var stadium_description: Label = %StadiumDescription
@onready var seed_input: LineEdit = %SeedInput
@onready var new_seed_button: Button = %NewSeedButton
@onready var debug_check: CheckButton = %DebugCheck

var selected_mode_id: String = GAME_MODE_CATALOG.QUICK_MATCH_ID


func _ready() -> void:
	_populate_importance_options()
	_populate_stadium_options()
	importance_option.item_selected.connect(_on_importance_selected)
	stadium_option.item_selected.connect(_on_stadium_selected)
	new_seed_button.pressed.connect(_set_new_seed)
	quick_match_button.pressed.connect(
		func() -> void:
			_select_game_mode(GAME_MODE_CATALOG.QUICK_MATCH_ID)
	)
	tournament_button.pressed.connect(
		func() -> void:
			_select_game_mode(GAME_MODE_CATALOG.WORLD_TOURNAMENT_ID)
	)
	career_button.pressed.connect(
		func() -> void:
			_select_game_mode(GAME_MODE_CATALOG.INTERNATIONAL_CAREER_ID)
	)
	if seed_input.text.is_empty():
		_set_new_seed()
	solo_button.pressed.connect(
		func() -> void:
			solo_requested.emit(_selected_importance_id())
	)
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	_select_game_mode(GAME_MODE_CATALOG.QUICK_MATCH_ID)
	solo_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		quit_requested.emit()
		get_viewport().set_input_as_handled()


func _populate_importance_options() -> void:
	importance_option.clear()
	for profile in MatchIntensityModel.profiles():
		importance_option.add_item(profile["label"])
		importance_option.set_item_metadata(
			importance_option.item_count - 1,
			profile["id"]
		)
		if profile["id"] == "group_stage":
			importance_option.select(importance_option.item_count - 1)
	_on_importance_selected(importance_option.selected)


func _on_importance_selected(_index: int) -> void:
	var profile := MatchIntensityModel.profile(_selected_importance_id())
	importance_description.text = profile["description"]


func _select_game_mode(mode_id: String) -> void:
	selected_mode_id = GAME_MODE_CATALOG.profile(mode_id)["id"]
	var mode_profile := GAME_MODE_CATALOG.profile(selected_mode_id)
	mode_description.text = mode_profile["description"]
	solo_button.text = mode_profile["button_label"]
	setup_subtitle.text = (
		"Choisis l’enjeu et le stade de ce match."
		if bool(mode_profile["allows_importance"])
		else "Le calendrier fixe l’enjeu ; choisis le stade de la session."
	)
	importance_title.text = (
		"Enjeu"
		if bool(mode_profile["allows_importance"])
		else "Enjeu de la première affectation"
	)
	importance_option.disabled = not bool(mode_profile["allows_importance"])
	if not bool(mode_profile["allows_importance"]):
		_select_importance_id(
			str(GAME_MODE_CATALOG.stage(selected_mode_id, 0)["importance_id"])
		)
	_on_importance_selected(importance_option.selected)

	for button in [
		quick_match_button,
		tournament_button,
		career_button,
	]:
		button.set_pressed_no_signal(
			str(button.get_meta("mode_id")) == selected_mode_id
		)


func _select_importance_id(importance_id: String) -> void:
	for index in range(importance_option.item_count):
		if str(importance_option.get_item_metadata(index)) == importance_id:
			importance_option.select(index)
			return


func _populate_stadium_options() -> void:
	stadium_option.clear()
	for stadium in STADIUM_CATALOG.profiles():
		stadium_option.add_item(
			"%s · %s" % [stadium["home_team"], stadium["stadium_name"]]
		)
		stadium_option.set_item_metadata(
			stadium_option.item_count - 1,
			stadium["id"]
		)
		if stadium["id"] == STADIUM_CATALOG.DEFAULT_ID:
			stadium_option.select(stadium_option.item_count - 1)
	_on_stadium_selected(stadium_option.selected)


func _on_stadium_selected(_index: int) -> void:
	var stadium := STADIUM_CATALOG.profile(selected_stadium_id())
	stadium_description.text = "%s · %s places" % [
		stadium["city"],
		_format_capacity(int(stadium["capacity"])),
	]


func _format_capacity(capacity: int) -> String:
	var raw := str(capacity)
	if raw.length() <= 3:
		return raw
	return "%s %s" % [
		raw.left(raw.length() - 3),
		raw.right(3),
	]


func _selected_importance_id() -> String:
	if importance_option.selected < 0:
		return "group_stage"
	return str(importance_option.get_item_metadata(importance_option.selected))


func selected_game_mode_id() -> String:
	return selected_mode_id


func selected_stadium_id() -> String:
	if stadium_option.selected < 0:
		return STADIUM_CATALOG.DEFAULT_ID
	return str(stadium_option.get_item_metadata(stadium_option.selected))


func selected_match_seed() -> int:
	var selected_seed := seed_input.text.strip_edges().to_int()
	if selected_seed <= 0:
		_set_new_seed()
		selected_seed = seed_input.text.to_int()
	return selected_seed


func debug_tools_enabled() -> bool:
	return debug_check.button_pressed


func _set_new_seed() -> void:
	var milliseconds := (
		Time.get_unix_time_from_system() * 1000.0
		+ float(Time.get_ticks_msec() % 1000)
	)
	var generated_seed := int(fmod(milliseconds, 2147483646.0)) + 1
	seed_input.text = str(generated_seed)
