extends SceneTree


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var app := preload("res://core/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png("res://.godot/menu_modes.png")
	var menu := app.current_screen as MainMenu
	menu.tournament_button.pressed.emit()
	await process_frame
	image = root.get_texture().get_image()
	image.save_png("res://.godot/menu_tournament.png")
	quit()
