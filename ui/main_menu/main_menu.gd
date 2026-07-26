extends Control
class_name MainMenu

signal solo_requested
signal quit_requested

@onready var solo_button: Button = %SoloButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	solo_button.pressed.connect(func() -> void: solo_requested.emit())
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	solo_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		quit_requested.emit()
		get_viewport().set_input_as_handled()

