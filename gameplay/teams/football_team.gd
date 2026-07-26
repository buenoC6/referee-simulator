extends Node2D
class_name FootballTeam

const PLAYER_SCENE: PackedScene = preload("res://gameplay/players/demo_player.tscn")
const FIELD_CENTER := Vector2(640.0, 360.0)

@export var team_id: int = 0
@export var display_name: String = "Équipe"
@export var team_color := Color("#2684ff")
@export var attacks_right: bool = true

var players: Array[DemoPlayer] = []


func _ready() -> void:
	_spawn_roster()


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
	return players[0]


func get_player_by_number(number: int) -> DemoPlayer:
	for player in players:
		if player.shirt_number == number:
			return player
	return players[0]


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


func update_shape(
	ball_position: Vector2,
	in_possession: bool,
	carrier: DemoPlayer = null
) -> void:
	var ball_shift := Vector2(
		clampf((ball_position.x - FIELD_CENTER.x) * 0.20, -115.0, 115.0),
		clampf((ball_position.y - FIELD_CENTER.y) * 0.12, -55.0, 55.0)
	)
	var attack_shift := Vector2(
		45.0 if attacks_right else -45.0,
		0.0
	) if in_possession else Vector2.ZERO

	for player in players:
		if player == carrier:
			continue
		var role_factor := 0.35 if player.is_goalkeeper else 1.0
		var target := player.home_position + (ball_shift + attack_shift) * role_factor
		player.move_to(target, 92.0 if player.is_goalkeeper else 118.0)


func _spawn_roster() -> void:
	if not players.is_empty():
		return

	var roster := _formation_for_direction()
	var numbers: Array[int] = [1, 2, 3, 4, 5, 6, 8, 10, 7, 9, 11]
	var roles: Array[StringName] = [
		&"GK",
		&"RB",
		&"RCB",
		&"LCB",
		&"LB",
		&"DM",
		&"RCM",
		&"LCM",
		&"RW",
		&"ST",
		&"LW",
	]

	for index in range(roster.size()):
		var player := PLAYER_SCENE.instantiate() as DemoPlayer
		player.name = "%s_%02d" % [roles[index], numbers[index]]
		player.team_color = team_color
		player.shirt_number = numbers[index]
		player.move_speed = 125.0 if index > 0 else 92.0
		add_child(player)
		player.configure(team_id, roles[index], roster[index], index == 0)
		players.append(player)


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

