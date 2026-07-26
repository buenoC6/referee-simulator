extends Node2D
class_name FootballTeam

signal roster_changed
signal player_sent_off(player_name: String)
signal substitution_made(out_name: String, in_name: String)

const PLAYER_SCENE: PackedScene = preload("res://gameplay/players/demo_player.tscn")

@export var team_id: int = 0
@export var display_name: String = "Équipe"
@export var team_color := Color("#2684ff")
@export var attacks_right: bool = true

var players: Array[DemoPlayer] = []
var profiles: Array[PlayerProfile] = []
var tactics := TeamTactics.new()
var substitutions_used: int = 0


func _ready() -> void:
	reset_squad()


func reset_squad() -> void:
	for player in players:
		if is_instance_valid(player):
			player.queue_free()
	players.clear()
	profiles.clear()
	substitutions_used = 0
	_build_profiles()
	_spawn_starting_eleven()
	roster_changed.emit()


func prepare_new_match() -> void:
	var needs_rebuild := substitutions_used > 0 or players.size() != 11
	for profile in profiles:
		if (
			profile.yellow_cards > 0
			or profile.has_red_card
			or profile.status in [
				PlayerProfile.SquadStatus.SUBSTITUTED,
				PlayerProfile.SquadStatus.SENT_OFF,
			]
		):
			needs_rebuild = true
			break
	if needs_rebuild:
		reset_squad()
	else:
		reset_formation()


func reset_formation() -> void:
	for player in players:
		player.reset_to(player.home_position)
		player.set_has_ball(false)


func stop_all() -> void:
	for player in players:
		player.stop()


func get_goalkeeper() -> DemoPlayer:
	for player in players:
		if player.is_goalkeeper:
			return player
	return players[0] if not players.is_empty() else null


func get_player_by_number(number: int) -> DemoPlayer:
	for player in players:
		if player.shirt_number == number:
			return player
	return players[0] if not players.is_empty() else null


func get_nearest_player(
	world_position: Vector2,
	include_goalkeeper: bool = true,
	excluded_player: DemoPlayer = null
) -> DemoPlayer:
	var nearest_player: DemoPlayer
	var nearest_distance := INF
	for player in players:
		if player == excluded_player:
			continue
		if not include_goalkeeper and player.is_goalkeeper:
			continue
		var distance := player.global_position.distance_squared_to(world_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_player = player
	return nearest_player


func publish_tactical_context(
	ball_position: Vector2,
	in_possession: bool,
	carrier: DemoPlayer = null,
	pressing_player: DemoPlayer = null
) -> void:
	for player in players:
		player.think_tactically(
			ball_position,
			in_possession,
			carrier,
			pressing_player,
			attacks_right,
			tactics
		)


func apply_yellow_card(player: DemoPlayer) -> bool:
	if not is_instance_valid(player) or player.profile == null:
		return false
	var became_red := player.profile.add_yellow_card()
	player.queue_redraw()
	if became_red:
		_remove_sent_off_player(player)
	roster_changed.emit()
	return became_red


func apply_red_card(player: DemoPlayer) -> void:
	if not is_instance_valid(player) or player.profile == null:
		return
	player.profile.add_red_card()
	_remove_sent_off_player(player)
	roster_changed.emit()


func make_automatic_substitution(excluded_player: DemoPlayer = null) -> Dictionary:
	if substitutions_used >= 5:
		return {}

	var outgoing_candidates: Array[DemoPlayer] = []
	for player in players:
		if not player.is_goalkeeper and player != excluded_player:
			outgoing_candidates.append(player)
	if outgoing_candidates.is_empty():
		return {}
	outgoing_candidates.sort_custom(
		func(a: DemoPlayer, b: DemoPlayer) -> bool:
			return a.stamina < b.stamina
	)
	var outgoing := outgoing_candidates[0]
	var incoming_profile := _best_substitute_for(outgoing.role)
	if incoming_profile == null:
		return {}

	var entry_position := outgoing.global_position
	var formation_position := outgoing.home_position
	var out_name := outgoing.display_name()
	outgoing.profile.mark_substituted()
	players.erase(outgoing)
	outgoing.queue_free()

	incoming_profile.enter_field()
	var incoming := _spawn_player(incoming_profile, formation_position)
	incoming.global_position = entry_position
	incoming.target_position = entry_position
	substitutions_used += 1
	roster_changed.emit()
	substitution_made.emit(out_name, incoming.display_name())
	return {
		"out": out_name,
		"in": incoming.display_name(),
		"player": incoming,
	}


func on_field_count() -> int:
	return players.size()


func substitute_count() -> int:
	var count := 0
	for profile in profiles:
		if profile.status == PlayerProfile.SquadStatus.SUBSTITUTE:
			count += 1
	return count


func _spawn_starting_eleven() -> void:
	var formation := _formation_for_direction()
	var starter_index := 0
	for profile in profiles:
		if profile.status != PlayerProfile.SquadStatus.STARTER:
			continue
		_spawn_player(profile, formation[starter_index])
		starter_index += 1


func _spawn_player(profile: PlayerProfile, formation_position: Vector2) -> DemoPlayer:
	var player := PLAYER_SCENE.instantiate() as DemoPlayer
	player.name = "%s_%02d" % [profile.role, profile.shirt_number]
	player.team_color = team_color
	player.move_speed = 125.0 if profile.role != &"GK" else 92.0
	add_child(player)
	player.configure_profile(team_id, profile, formation_position)
	players.append(player)
	return player


func _remove_sent_off_player(player: DemoPlayer) -> void:
	var sent_off_name := player.display_name()
	if player in players:
		players.erase(player)
	player.set_has_ball(false)
	player.queue_free()
	player_sent_off.emit(sent_off_name)


func _best_substitute_for(outgoing_role: StringName) -> PlayerProfile:
	var same_line: Array[StringName] = _role_family(outgoing_role)
	for profile in profiles:
		if profile.is_available_substitute() and profile.role in same_line:
			return profile
	for profile in profiles:
		if profile.is_available_substitute() and profile.role != &"GK":
			return profile
	return null


func _role_family(player_role: StringName) -> Array[StringName]:
	if player_role in [&"RB", &"RCB", &"LCB", &"LB", &"CB", &"FB"]:
		return [&"RB", &"RCB", &"LCB", &"LB", &"CB", &"FB"]
	if player_role in [&"DM", &"RCM", &"LCM", &"CM"]:
		return [&"DM", &"RCM", &"LCM", &"CM"]
	return [&"RW", &"ST", &"LW", &"FW"]


func _build_profiles() -> void:
	var names := _blue_names() if team_id == 0 else _red_names()
	var numbers: Array[int] = [
		1, 2, 3, 4, 5, 6, 8, 10, 7, 9, 11,
		12, 13, 14, 15, 16,
	]
	var roles: Array[StringName] = [
		&"GK", &"RB", &"RCB", &"LCB", &"LB", &"DM",
		&"RCM", &"LCM", &"RW", &"ST", &"LW",
		&"GK", &"CB", &"FB", &"CM", &"FW",
	]

	for index in range(names.size()):
		var profile := PlayerProfile.new()
		profile.full_name = names[index]
		profile.shirt_number = numbers[index]
		profile.role = roles[index]
		profile.status = (
			PlayerProfile.SquadStatus.STARTER
			if index < 11
			else PlayerProfile.SquadStatus.SUBSTITUTE
		)
		profiles.append(profile)


func _blue_names() -> Array[String]:
	return [
		"Lucas Morel",
		"Théo Bernard",
		"Arthur Leroy",
		"Noah Fontaine",
		"Jules Lambert",
		"Hugo Simon",
		"Mathis Laurent",
		"Enzo Michel",
		"Louis Dubois",
		"Adam Robert",
		"Gabriel André",
		"Tom Vincent",
		"Rayan Petit",
		"Nathan Garcia",
		"Maël Lefèvre",
		"Sacha Roux",
	]


func _red_names() -> Array[String]:
	return [
		"Victor Janssen",
		"Liam Peeters",
		"Raphaël Maes",
		"Elias Willems",
		"Milan Claes",
		"Antoine Jacobs",
		"Yanis Aerts",
		"Robin Vermeulen",
		"Nolan De Smet",
		"Sam Declercq",
		"Ilyes Martens",
		"Axel Goossens",
		"Amine Wouters",
		"Tiago Mertens",
		"Ruben Vandenberg",
		"Maxime Coppens",
	]


func _formation_for_direction() -> Array[Vector2]:
	var right_facing: Array[Vector2] = [
		Vector2(112.0, 360.0),
		Vector2(275.0, 150.0),
		Vector2(290.0, 285.0),
		Vector2(290.0, 435.0),
		Vector2(275.0, 570.0),
		Vector2(455.0, 360.0),
		Vector2(510.0, 235.0),
		Vector2(510.0, 485.0),
		Vector2(680.0, 185.0),
		Vector2(705.0, 360.0),
		Vector2(680.0, 535.0),
	]
	if attacks_right:
		return right_facing

	var mirrored: Array[Vector2] = []
	for position in right_facing:
		mirrored.append(Vector2(1280.0 - position.x, position.y))
	return mirrored
