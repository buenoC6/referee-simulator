extends CanvasLayer
class_name PauseMenu

signal resume_requested
signal restart_requested
signal main_menu_requested

@onready var context_label: Label = %ContextLabel
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	main_menu_button.pressed.connect(
		func() -> void: main_menu_requested.emit()
	)
	visible = false


func open_menu(context: String) -> void:
	context_label.text = context
	visible = true
	resume_button.grab_focus()


func close_menu() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	resume_requested.emit()
	get_viewport().set_input_as_handled()
