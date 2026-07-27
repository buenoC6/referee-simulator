extends CanvasLayer
class_name ResultsPanel

signal replay_requested
signal main_menu_requested
signal continue_requested

@onready var eyebrow_label: Label = %EyebrowLabel
@onready var grade_label: Label = %GradeLabel
@onready var total_label: Label = %TotalLabel
@onready var breakdown_label: Label = %BreakdownLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var explanation_label: Label = %ExplanationLabel
@onready var replay_button: Button = %ReplayButton
@onready var continue_button: Button = %ContinueButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	replay_button.pressed.connect(func() -> void: replay_requested.emit())
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	main_menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	visible = false


func show_result(result: Dictionary) -> void:
	_configure_context_and_actions(result)
	if result.get("tension_mode", false):
		_show_tension_result(result)
		return

	var total_score: int = result["total_score"]
	grade_label.text = _grade_for(total_score)
	total_label.text = "%d / 100" % total_score
	breakdown_label.text = (
		"Décision %d/40  ·  Discipline %d/20  ·  Position %d/25  ·  Délai %d/15"
		% [
			result["technical_score"],
			result["discipline_score"],
			result["positioning_score"],
			result["response_score"],
		]
	)

	var feedback_lines: PackedStringArray = result["feedback"]
	var formatted_feedback := PackedStringArray()
	for feedback_line in feedback_lines:
		formatted_feedback.append("• %s" % feedback_line)
	feedback_label.text = "\n".join(formatted_feedback)
	explanation_label.text = result["explanation"]
	visible = true


func _show_tension_result(result: Dictionary) -> void:
	grade_label.text = _sentence_case(str(result["outcome"]))
	var highest_peak := maxi(
		int(result["blue_peak_tension"]),
		int(result["red_peak_tension"])
	)
	total_label.text = "Tension maximale · %d%%" % highest_peak
	breakdown_label.text = (
		"Bleus %d%% (pic %d) · Rouges %d%% (pic %d) · %s"
		% [
			result["blue_tension"],
			result["blue_peak_tension"],
			result["red_tension"],
			result["red_peak_tension"],
			result["importance_label"],
		]
	)

	var feedback_lines: PackedStringArray = result["feedback"]
	var formatted_feedback := PackedStringArray()
	for feedback_line in feedback_lines:
		formatted_feedback.append("• %s" % feedback_line)
	feedback_label.text = "\n".join(formatted_feedback)
	explanation_label.text = result["explanation"]
	visible = true


func _configure_context_and_actions(result: Dictionary) -> void:
	var result_context := str(result.get("result_context", "")).strip_edges()
	eyebrow_label.text = (
		result_context
		if not result_context.is_empty()
		else "FIN DU MATCH"
	)
	continue_button.visible = bool(result.get("can_continue", false))
	continue_button.text = str(
		result.get("continue_label", "Match suivant")
	)
	replay_button.text = str(result.get("replay_label", "Rejouer"))


func hide_panel() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			replay_requested.emit()
			get_viewport().set_input_as_handled()


func _grade_for(score: int) -> String:
	if score >= 90:
		return "Excellent arbitrage"
	if score >= 80:
		return "Bon arbitrage"
	if score >= 60:
		return "Match perfectible"
	return "Match à revoir"


func _sentence_case(text: String) -> String:
	var clean := text.strip_edges().to_lower()
	if clean.is_empty():
		return clean
	return clean.left(1).to_upper() + clean.substr(1)
