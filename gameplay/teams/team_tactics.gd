extends Resource
class_name TeamTactics

@export_range(0.0, 1.0, 0.05) var pressing_intensity: float = 0.62
@export_range(0.0, 1.0, 0.05) var compactness: float = 0.68
@export_range(0.0, 1.0, 0.05) var attacking_intent: float = 0.58
@export_range(0.0, 1.0, 0.05) var width: float = 0.72


func movement_speed_for_role(role: StringName, has_possession: bool) -> float:
	if role == &"GK":
		return 88.0
	if role in [&"ST", &"LW", &"RW", &"FW"]:
		return 128.0 if has_possession else 119.0
	if role in [&"DM", &"CM", &"RCM", &"LCM"]:
		return 122.0
	return 116.0
