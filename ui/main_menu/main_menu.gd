extends Control
class_name MainMenu

const STADIUM_CATALOG := preload(
	"res://gameplay/perspective/stadium_catalog.gd"
)

signal solo_requested(match_importance_id: String)
signal quit_requested

@onready var solo_button: Button = %SoloButton
@onready var quit_button: Button = %QuitButton
@onready var importance_option: OptionButton = %ImportanceOption
@onready var importance_description: Label = %ImportanceDescription
@onready var stadium_option: OptionButton = %StadiumOption
@onready var stadium_description: Label = %StadiumDescription


func _ready() -> void:
	_populate_importance_options()
	_populate_stadium_options()
	importance_option.item_selected.connect(_on_importance_selected)
	stadium_option.item_selected.connect(_on_stadium_selected)
	solo_button.pressed.connect(
		func() -> void:
			solo_requested.emit(_selected_importance_id())
	)
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
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


func selected_stadium_id() -> String:
	if stadium_option.selected < 0:
		return STADIUM_CATALOG.DEFAULT_ID
	return str(stadium_option.get_item_metadata(stadium_option.selected))
