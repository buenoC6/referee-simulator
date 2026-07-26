extends Resource
class_name PlayerProfile

enum SquadStatus {
	STARTER,
	SUBSTITUTE,
	SUBSTITUTED,
	SENT_OFF,
}

@export var full_name: String = ""
@export_range(1, 99, 1) var shirt_number: int = 1
@export var role: StringName = &"CM"
@export var status := SquadStatus.SUBSTITUTE

var yellow_cards: int = 0
var has_red_card: bool = false


func is_on_field() -> bool:
	return status == SquadStatus.STARTER


func is_available_substitute() -> bool:
	return status == SquadStatus.SUBSTITUTE


func add_yellow_card() -> bool:
	yellow_cards += 1
	if yellow_cards >= 2:
		send_off()
		return true
	return false


func add_red_card() -> void:
	send_off()


func mark_substituted() -> void:
	status = SquadStatus.SUBSTITUTED


func enter_field() -> void:
	status = SquadStatus.STARTER


func reset_match_state(initial_status: SquadStatus) -> void:
	status = initial_status
	yellow_cards = 0
	has_red_card = false


func status_label() -> String:
	match status:
		SquadStatus.STARTER:
			return "Terrain"
		SquadStatus.SUBSTITUTE:
			return "Remplaçant"
		SquadStatus.SUBSTITUTED:
			return "Remplacé"
		SquadStatus.SENT_OFF:
			return "Exclu"
		_:
			return "Inconnu"


func discipline_label() -> String:
	if has_red_card:
		return "CR"
	if yellow_cards > 0:
		return "CJ" if yellow_cards == 1 else "2CJ"
	return ""


func send_off() -> void:
	has_red_card = true
	status = SquadStatus.SENT_OFF
