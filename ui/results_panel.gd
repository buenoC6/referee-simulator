extends CanvasLayer
class_name ResultsPanel

signal replay_requested

@onready var grade_label: Label = %GradeLabel
@onready var total_label: Label = %TotalLabel
@onready var breakdown_label: Label = %BreakdownLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var explanation_label: Label = %ExplanationLabel
@onready var replay_button: Button = %ReplayButton


func _ready() -> void:
	replay_button.pressed.connect(func() -> void: replay_requested.emit())
	visible = false


func show_result(result: Dictionary) -> void:
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
		return "EXCELLENTE DÉCISION"
	if score >= 75:
		return "BON ARBITRAGE"
	if score >= 55:
		return "DÉCISION PERFECTIBLE"
	return "ACTION À REVOIR"

