extends CanvasLayer
class_name PerspectiveHud

@onready var phase_label: Label = %PhaseLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var venue_label: Label = %VenueLabel
@onready var match_label: Label = %MatchLabel
@onready var importance_label: Label = %ImportanceLabel
@onready var control_label: Label = %ControlLabel
@onready var blue_tension_bar: ProgressBar = %BlueTensionBar
@onready var red_tension_bar: ProgressBar = %RedTensionBar
@onready var blue_tension_value: Label = %BlueTensionValue
@onready var red_tension_value: Label = %RedTensionValue
@onready var blue_team_label: Label = %BlueTeamLabel
@onready var red_team_label: Label = %RedTeamLabel
@onready var distance_label: Label = %DistanceLabel
@onready var view_label: Label = %ViewLabel
@onready var ball_direction_label: Label = %BallDirectionLabel
@onready var assistant_signal_label: Label = %AssistantSignalLabel
@onready var minimap: RefereeMinimap2D = %RefereeMinimap
@onready var incident_panel: PanelContainer = %IncidentPanel
@onready var incident_title: Label = %IncidentTitle
@onready var incident_detail: Label = %IncidentDetail
@onready var controls_label: Label = %ControlsLabel
@onready var context_panel: PanelContainer = %ContextPanel
@onready var match_bar: PanelContainer = %MatchBar
@onready var tension_panel: PanelContainer = %TensionPanel
@onready var live_reading: Control = %LiveReading
@onready var bottom_panel: PanelContainer = %Bottom

var blue_team_name: String = "BLEUS"
var red_team_name: String = "ROUGES"
var decision_mode: bool = false


func _ready() -> void:
	incident_panel.visible = false
	assistant_signal_label.visible = false


func set_phase(text: String) -> void:
	phase_label.text = _sentence_case(text)


func set_objective(text: String) -> void:
	objective_label.text = text


func set_venue(stadium_name: String, city: String) -> void:
	venue_label.text = "%s · %s" % [
		stadium_name,
		city,
	]


func set_team_identity(
	home_name: String,
	home_color: Color,
	away_name: String = "VISITEURS",
	away_color: Color = Color("#e84a5f")
) -> void:
	blue_team_name = home_name.to_upper()
	red_team_name = away_name.to_upper()
	blue_team_label.text = blue_team_name
	red_team_label.text = red_team_name
	blue_team_label.add_theme_color_override("font_color", home_color.lightened(0.24))
	red_team_label.add_theme_color_override("font_color", away_color.lightened(0.2))
	var home_fill := (
		blue_tension_bar.get_theme_stylebox("fill").duplicate()
		as StyleBoxFlat
	)
	var away_fill := (
		red_tension_bar.get_theme_stylebox("fill").duplicate()
		as StyleBoxFlat
	)
	home_fill.bg_color = home_color
	away_fill.bg_color = away_color
	blue_tension_bar.add_theme_stylebox_override("fill", home_fill)
	red_tension_bar.add_theme_stylebox_override("fill", away_fill)


func configure_minimap(
	players: Array[PerspectivePlayer3D],
	ball: Node3D,
	referee: Node3D,
	camera: Camera3D,
	home_color: Color,
	away_color: Color
) -> void:
	minimap.configure(
		players,
		ball,
		referee,
		camera,
		home_color,
		away_color
	)


func set_match_state(match_minute: int, blue_score: int, red_score: int) -> void:
	match_label.text = "%02d′   %s %d — %d %s" % [
		clampi(match_minute, 0, 90),
		blue_team_name,
		blue_score,
		red_score,
		red_team_name,
	]


func set_match_tension(
	blue_tension: float,
	red_tension: float,
	control_state: Dictionary,
	importance: String
) -> void:
	blue_tension_bar.value = blue_tension
	red_tension_bar.value = red_tension
	blue_tension_value.text = "%d%%" % roundi(blue_tension)
	red_tension_value.text = "%d%%" % roundi(red_tension)
	importance_label.text = importance
	control_label.text = _sentence_case(str(control_state["label"]))
	var state_id: String = control_state["id"]
	control_label.add_theme_color_override(
		"font_color",
		(
			Color("#86efac")
			if state_id == "calm"
			else Color("#fde047")
			if state_id in ["nervous", "heated"]
			else Color("#fb7185")
		)
	)


func show_assistant_signal(text: String) -> void:
	assistant_signal_label.text = "Assistant · %s" % _sentence_case(text)
	assistant_signal_label.visible = true


func hide_assistant_signal() -> void:
	assistant_signal_label.visible = false


func set_live_reading(
	distance_meters: float,
	angle_degrees: float,
	in_frame: bool
) -> void:
	distance_label.text = "Distance %.0f m" % distance_meters
	view_label.text = (
		"Dans l’axe · %.0f°" % angle_degrees
		if in_frame
		else "Hors axe · %.0f°" % angle_degrees
	)
	view_label.add_theme_color_override(
		"font_color",
		Color("#86efac") if in_frame else Color("#fda4af")
	)


func set_ball_direction(
	distance_meters: float,
	signed_angle_degrees: float
) -> void:
	var distance_text := "%.0f m" % distance_meters
	var absolute_angle := absf(signed_angle_degrees)
	if absolute_angle <= 32.0:
		ball_direction_label.text = "BALLON · devant · %s" % distance_text
	elif absolute_angle >= 145.0:
		ball_direction_label.text = (
			"BALLON · derrière à droite · %s" % distance_text
			if signed_angle_degrees < 0.0
			else "BALLON · derrière à gauche · %s" % distance_text
		)
	elif signed_angle_degrees < 0.0:
		ball_direction_label.text = "BALLON · à droite · %s" % distance_text
	else:
		ball_direction_label.text = "BALLON · à gauche · %s" % distance_text


func show_incident(title: String, detail: String) -> void:
	incident_title.text = _sentence_case(title)
	incident_detail.text = detail
	incident_panel.visible = true


func update_incident_countdown(seconds_remaining: float) -> void:
	incident_detail.text = "Espace pour siffler · %.1f s restantes" % seconds_remaining


func hide_incident() -> void:
	incident_panel.visible = false


func set_controls(text: String) -> void:
	controls_label.text = text
	bottom_panel.visible = not text.is_empty() and not decision_mode


func set_decision_mode(enabled: bool) -> void:
	decision_mode = enabled
	context_panel.visible = not enabled
	tension_panel.visible = not enabled
	live_reading.visible = false
	incident_panel.visible = false if enabled else incident_panel.visible
	ball_direction_label.visible = not enabled
	bottom_panel.visible = not enabled and not controls_label.text.is_empty()
	minimap.modulate.a = 0.62 if enabled else 0.84


func _sentence_case(text: String) -> String:
	var clean := text.strip_edges().to_lower()
	if clean.is_empty():
		return clean
	var result := clean.left(1).to_upper() + clean.substr(1)
	if result.begins_with("Var"):
		result = "VAR" + result.substr(3)
	return result
