extends CanvasLayer
class_name MatchHud

@onready var clock_label: Label = %ClockLabel
@onready var score_label: Label = %ScoreLabel
@onready var phase_label: Label = %PhaseLabel
@onready var banner_panel: PanelContainer = %BannerPanel
@onready var banner_title: Label = %BannerTitle
@onready var banner_detail: Label = %BannerDetail
@onready var controls_label: Label = %ControlsLabel


func _ready() -> void:
	hide_incident()


func set_match_minute(match_minutes: float) -> void:
	clock_label.text = "%02d′" % clampi(floori(match_minutes), 0, 90)


func set_score(blue_score: int, red_score: int) -> void:
	score_label.text = "BLEUS  %d  –  %d  ROUGES" % [blue_score, red_score]


func set_phase(text: String) -> void:
	phase_label.text = text


func set_controls(text: String) -> void:
	controls_label.text = text


func show_incident(title: String, detail: String) -> void:
	banner_title.text = title
	banner_detail.text = detail
	banner_panel.visible = true


func update_incident_countdown(seconds_remaining: float) -> void:
	banner_detail.text = "Espace pour siffler · %.1f s pour réagir" % seconds_remaining


func hide_incident() -> void:
	banner_panel.visible = false
