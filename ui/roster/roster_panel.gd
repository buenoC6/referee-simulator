extends CanvasLayer
class_name RosterPanel

@onready var blue_button: Button = %BlueButton
@onready var red_button: Button = %RedButton
@onready var team_label: Label = %TeamLabel
@onready var summary_label: Label = %SummaryLabel
@onready var player_list: VBoxContainer = %PlayerList

var blue_team: FootballTeam
var red_team: FootballTeam
var selected_team: FootballTeam


func _ready() -> void:
	blue_button.pressed.connect(func() -> void: _select_team(blue_team))
	red_button.pressed.connect(func() -> void: _select_team(red_team))


func setup(new_blue_team: FootballTeam, new_red_team: FootballTeam) -> void:
	blue_team = new_blue_team
	red_team = new_red_team
	blue_team.roster_changed.connect(_refresh)
	red_team.roster_changed.connect(_refresh)
	_select_team(blue_team)


func _select_team(team: FootballTeam) -> void:
	if team == null:
		return
	selected_team = team
	blue_button.button_pressed = team == blue_team
	red_button.button_pressed = team == red_team
	_refresh()


func _refresh() -> void:
	if selected_team == null or player_list == null:
		return

	team_label.text = selected_team.display_name.to_upper()
	team_label.modulate = selected_team.team_color.lightened(0.18)
	summary_label.text = "%d sur le terrain  ·  %d remplacement(s)" % [
		selected_team.on_field_count(),
		selected_team.substitutions_used,
	]
	for child in player_list.get_children():
		child.queue_free()

	var active_profiles: Array[PlayerProfile] = []
	var bench_profiles: Array[PlayerProfile] = []
	var inactive_profiles: Array[PlayerProfile] = []
	for profile in selected_team.profiles:
		match profile.status:
			PlayerProfile.SquadStatus.STARTER:
				active_profiles.append(profile)
			PlayerProfile.SquadStatus.SUBSTITUTE:
				bench_profiles.append(profile)
			_:
				inactive_profiles.append(profile)

	_add_section("TERRAIN · %d" % active_profiles.size(), active_profiles)
	_add_section("REMPLAÇANTS · %d" % bench_profiles.size(), bench_profiles)
	if not inactive_profiles.is_empty():
		_add_section("SORTIS / EXCLUS · %d" % inactive_profiles.size(), inactive_profiles)


func _add_section(title: String, section_profiles: Array[PlayerProfile]) -> void:
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color("#8fa2b8"))
	heading.custom_minimum_size.y = 25.0
	player_list.add_child(heading)

	section_profiles.sort_custom(
		func(a: PlayerProfile, b: PlayerProfile) -> bool:
			return a.shirt_number < b.shirt_number
	)
	for profile in section_profiles:
		player_list.add_child(_make_player_row(profile))


func _make_player_row(profile: PlayerProfile) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 24.0
	row.add_theme_constant_override("separation", 7)

	var number_label := Label.new()
	number_label.text = "%02d" % profile.shirt_number
	number_label.custom_minimum_size.x = 28.0
	number_label.add_theme_font_size_override("font_size", 13)
	number_label.add_theme_color_override("font_color", Color("#facc3d"))
	row.add_child(number_label)

	var name_label := Label.new()
	name_label.text = profile.full_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 14)
	if profile.status != PlayerProfile.SquadStatus.STARTER:
		name_label.add_theme_color_override("font_color", Color("#9aabba"))
	row.add_child(name_label)

	var role_label := Label.new()
	role_label.text = str(profile.role)
	role_label.custom_minimum_size.x = 31.0
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	role_label.add_theme_font_size_override("font_size", 11)
	role_label.add_theme_color_override("font_color", Color("#8494a7"))
	row.add_child(role_label)

	var discipline := profile.discipline_label()
	if not discipline.is_empty():
		var card_label := Label.new()
		card_label.text = discipline
		card_label.custom_minimum_size.x = 28.0
		card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		card_label.add_theme_font_size_override("font_size", 11)
		card_label.add_theme_color_override(
			"font_color",
			Color("#ef4444") if profile.has_red_card else Color("#facc15")
		)
		row.add_child(card_label)
	elif profile.status == PlayerProfile.SquadStatus.SUBSTITUTED:
		var substituted_label := Label.new()
		substituted_label.text = "REM"
		substituted_label.add_theme_font_size_override("font_size", 10)
		substituted_label.add_theme_color_override("font_color", Color("#94a3b8"))
		row.add_child(substituted_label)

	return row
