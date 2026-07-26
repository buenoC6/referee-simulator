extends Node
class_name FootballRulesEngine

enum RestartType {
	KICK_OFF,
	THROW_IN,
	GOAL_KICK,
	CORNER_KICK,
	DIRECT_FREE_KICK,
	INDIRECT_FREE_KICK,
}

const FIELD_RECT := Rect2(64.0, 64.0, 1152.0, 592.0)
const BALL_RADIUS := 8.0


func restart_label(restart_type: RestartType) -> String:
	match restart_type:
		RestartType.KICK_OFF:
			return "Coup d'envoi"
		RestartType.THROW_IN:
			return "Rentrée de touche"
		RestartType.GOAL_KICK:
			return "Coup de pied de but"
		RestartType.CORNER_KICK:
			return "Corner"
		RestartType.DIRECT_FREE_KICK:
			return "Coup franc direct"
		RestartType.INDIRECT_FREE_KICK:
			return "Coup franc indirect"
		_:
			return "Reprise"


func is_ball_out(ball_position: Vector2) -> bool:
	# Law 9 requires the whole ball to have crossed the line. The visual ball has
	# an 8 px radius, so its centre must also have cleared that radius.
	return not FIELD_RECT.grow(BALL_RADIUS).has_point(ball_position)


func classify_ball_out(
	ball_position: Vector2,
	last_touch_team: FootballTeam
) -> Dictionary:
	if ball_position.y < FIELD_RECT.position.y or ball_position.y > FIELD_RECT.end.y:
		return {
			"type": RestartType.THROW_IN,
			"team": _opponent_of(last_touch_team),
			"position": Vector2(
				clampf(ball_position.x, FIELD_RECT.position.x + 20.0, FIELD_RECT.end.x - 20.0),
				clampf(ball_position.y, FIELD_RECT.position.y, FIELD_RECT.end.y)
			),
		}

	var crossed_right_goal_line := ball_position.x > FIELD_RECT.end.x
	var defending_team := (
		_opponent_of(last_touch_team)
		if last_touch_team.attacks_right == crossed_right_goal_line
		else last_touch_team
	)
	var touched_by_defender := last_touch_team == defending_team
	var restart_type := (
		RestartType.CORNER_KICK
		if touched_by_defender
		else RestartType.GOAL_KICK
	)
	return {
		"type": restart_type,
		"team": _opponent_of(defending_team) if touched_by_defender else defending_team,
		"position": _restart_position(restart_type, ball_position, defending_team),
	}


func is_offside_position(
	receiver: DemoPlayer,
	attacking_team: FootballTeam,
	defending_team: FootballTeam,
	ball_position: Vector2
) -> bool:
	if receiver == null or receiver.is_goalkeeper:
		return false

	var defenders: Array[DemoPlayer] = defending_team.players.duplicate()
	if defenders.size() < 2:
		return false
	defenders.sort_custom(
		func(a: DemoPlayer, b: DemoPlayer) -> bool:
			return (
				a.global_position.x > b.global_position.x
				if attacking_team.attacks_right
				else a.global_position.x < b.global_position.x
			)
	)
	var second_last_x := defenders[1].global_position.x

	if attacking_team.attacks_right:
		return (
			receiver.global_position.x > 640.0
			and receiver.global_position.x > ball_position.x
			and receiver.global_position.x > second_last_x
		)
	return (
		receiver.global_position.x < 640.0
		and receiver.global_position.x < ball_position.x
		and receiver.global_position.x < second_last_x
	)


func _restart_position(
	restart_type: RestartType,
	ball_position: Vector2,
	defending_team: FootballTeam
) -> Vector2:
	if restart_type == RestartType.CORNER_KICK:
		return Vector2(
			FIELD_RECT.end.x if ball_position.x > 640.0 else FIELD_RECT.position.x,
			FIELD_RECT.position.y if ball_position.y < 360.0 else FIELD_RECT.end.y
		)
	return Vector2(
		FIELD_RECT.end.x - 92.0 if not defending_team.attacks_right else FIELD_RECT.position.x + 92.0,
		360.0
	)


func _opponent_of(team: FootballTeam) -> FootballTeam:
	var parent := team.get_parent()
	for child in parent.get_children():
		if child is FootballTeam and child != team:
			return child as FootballTeam
	return null
