extends CanvasLayer
class_name DecisionPanel

signal decision_submitted(
	technical_choice: IncidentData.TechnicalDecision,
	discipline_choice: IncidentData.DisciplineDecision
)

@onready var situation_label: Label = %SituationLabel
@onready var evidence_label: Label = %EvidenceLabel
@onready var selection_label: Label = %SelectionLabel
@onready var submit_button: Button = %SubmitButton

@onready var play_on_button: Button = %PlayOnButton
@onready var free_kick_button: Button = %FreeKickButton
@onready var penalty_button: Button = %PenaltyButton
@onready var no_card_button: Button = %NoCardButton
@onready var yellow_card_button: Button = %YellowCardButton
@onready var red_card_button: Button = %RedCardButton

var technical_choice: int = -1
var discipline_choice: int = -1


func _ready() -> void:
	play_on_button.pressed.connect(
		_select_technical.bind(IncidentData.TechnicalDecision.PLAY_ON)
	)
	free_kick_button.pressed.connect(
		_select_technical.bind(IncidentData.TechnicalDecision.DIRECT_FREE_KICK)
	)
	penalty_button.pressed.connect(
		_select_technical.bind(IncidentData.TechnicalDecision.PENALTY_KICK)
	)
	no_card_button.pressed.connect(
		_select_discipline.bind(IncidentData.DisciplineDecision.NO_CARD)
	)
	yellow_card_button.pressed.connect(
		_select_discipline.bind(IncidentData.DisciplineDecision.YELLOW_CARD)
	)
	red_card_button.pressed.connect(
		_select_discipline.bind(IncidentData.DisciplineDecision.RED_CARD)
	)
	submit_button.pressed.connect(_submit)
	visible = false


func show_for(incident: IncidentData, evidence: String = "") -> void:
	situation_label.text = "%s · %s" % [incident.incident_id, incident.title]
	evidence_label.text = evidence
	evidence_label.visible = not evidence.is_empty()
	technical_choice = -1
	discipline_choice = -1
	_reset_buttons()
	_refresh_selection()
	visible = true


func hide_panel() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_1:
			_select_technical(IncidentData.TechnicalDecision.PLAY_ON)
		KEY_2:
			_select_technical(IncidentData.TechnicalDecision.DIRECT_FREE_KICK)
		KEY_3:
			_select_technical(IncidentData.TechnicalDecision.PENALTY_KICK)
		KEY_4:
			_select_discipline(IncidentData.DisciplineDecision.NO_CARD)
		KEY_5:
			_select_discipline(IncidentData.DisciplineDecision.YELLOW_CARD)
		KEY_6:
			_select_discipline(IncidentData.DisciplineDecision.RED_CARD)
		KEY_ENTER, KEY_KP_ENTER:
			if not submit_button.disabled:
				_submit()
		_:
			return

	get_viewport().set_input_as_handled()


func _select_technical(choice: IncidentData.TechnicalDecision) -> void:
	technical_choice = choice
	var buttons: Array[Button] = [play_on_button, free_kick_button, penalty_button]
	for button in buttons:
		button.set_pressed_no_signal(false)
	buttons[choice].set_pressed_no_signal(true)
	_refresh_selection()


func _select_discipline(choice: IncidentData.DisciplineDecision) -> void:
	discipline_choice = choice
	var buttons: Array[Button] = [no_card_button, yellow_card_button, red_card_button]
	for button in buttons:
		button.set_pressed_no_signal(false)
	buttons[choice].set_pressed_no_signal(true)
	_refresh_selection()


func _refresh_selection() -> void:
	submit_button.disabled = technical_choice < 0 or discipline_choice < 0
	if submit_button.disabled:
		selection_label.text = "Choisis une décision technique et une sanction."
		return

	selection_label.text = "%s · %s" % [
		IncidentData.technical_decision_label(technical_choice),
		IncidentData.discipline_decision_label(discipline_choice),
	]


func _reset_buttons() -> void:
	for button: Button in [
		play_on_button,
		free_kick_button,
		penalty_button,
		no_card_button,
		yellow_card_button,
		red_card_button,
	]:
		button.set_pressed_no_signal(false)


func _submit() -> void:
	if submit_button.disabled:
		return
	decision_submitted.emit(technical_choice, discipline_choice)
