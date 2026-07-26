extends Node
class_name IncidentDirector

signal incident_started(incident: IncidentData)
signal incident_expired(incident: IncidentData)

var current_incident: IncidentData
var response_time: float = 0.0
var is_active: bool = false


func _process(delta: float) -> void:
	if not is_active or current_incident == null:
		return

	response_time += delta
	if response_time >= current_incident.maximum_response_time:
		var expired_incident := current_incident
		is_active = false
		incident_expired.emit(expired_incident)


func activate(incident: IncidentData) -> void:
	current_incident = incident
	response_time = 0.0
	is_active = true
	incident_started.emit(incident)


func resolve() -> float:
	is_active = false
	return response_time


func cancel() -> void:
	is_active = false
	current_incident = null
	response_time = 0.0


func remaining_time() -> float:
	if not is_active or current_incident == null:
		return 0.0
	return maxf(current_incident.maximum_response_time - response_time, 0.0)

