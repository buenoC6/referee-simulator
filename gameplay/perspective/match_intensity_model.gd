extends RefCounted
class_name MatchIntensityModel

const PROFILES := [
	{
		"id": "friendly",
		"label": "Match amical",
		"description": "Réactions mesurées, tension qui retombe rapidement.",
		"reaction_multiplier": 0.65,
		"baseline_tension": 3.0,
		"recovery_per_second": 0.085,
	},
	{
		"id": "group_stage",
		"label": "Phase de poules",
		"description": "Un enjeu réel, mais les équipes gardent encore de la marge.",
		"reaction_multiplier": 0.90,
		"baseline_tension": 7.0,
		"recovery_per_second": 0.060,
	},
	{
		"id": "qualifier",
		"label": "Match qualificatif",
		"description": "Chaque décision peut peser sur une qualification.",
		"reaction_multiplier": 1.12,
		"baseline_tension": 12.0,
		"recovery_per_second": 0.042,
	},
	{
		"id": "knockout",
		"label": "Match à élimination directe",
		"description": "La nervosité monte vite et redescend difficilement.",
		"reaction_multiplier": 1.34,
		"baseline_tension": 17.0,
		"recovery_per_second": 0.028,
	},
	{
		"id": "final",
		"label": "Finale",
		"description": "Pression maximale : une erreur peut faire basculer le match.",
		"reaction_multiplier": 1.55,
		"baseline_tension": 22.0,
		"recovery_per_second": 0.018,
	},
	{
		"id": "derby",
		"label": "Derby sous haute tension",
		"description": "Rivalité explosive, contestations et fautes plus fréquentes.",
		"reaction_multiplier": 1.75,
		"baseline_tension": 27.0,
		"recovery_per_second": 0.012,
	},
]


static func profiles() -> Array:
	return PROFILES


static func profile(profile_id: String) -> Dictionary:
	for entry in PROFILES:
		if entry["id"] == profile_id:
			return entry
	return PROFILES[1]


static func control_state(blue_tension: float, red_tension: float) -> Dictionary:
	var highest := maxf(blue_tension, red_tension)
	if highest < 25.0:
		return {
			"id": "calm",
			"label": "SOUS CONTRÔLE",
			"description": "Les joueurs acceptent globalement les décisions.",
		}
	if highest < 50.0:
		return {
			"id": "nervous",
			"label": "NERVEUX",
			"description": "Les contestations commencent et les duels se durcissent.",
		}
	if highest < 75.0:
		return {
			"id": "heated",
			"label": "ÉLECTRIQUE",
			"description": "Le rythme s’emballe et les joueurs entourent plus facilement l’arbitre.",
		}
	if highest < 92.0:
		return {
			"id": "hostile",
			"label": "HOSTILE",
			"description": "Le match devient difficile à contrôler.",
		}
	return {
		"id": "chaos",
		"label": "HORS DE CONTRÔLE",
		"description": "Une nouvelle erreur peut provoquer l’interruption du match.",
	}


static func tempo_multiplier(blue_tension: float, red_tension: float) -> float:
	var highest := maxf(blue_tension, red_tension)
	return lerpf(1.0, 1.38, clampf(highest / 100.0, 0.0, 1.0))


static func foul_interval_multiplier(
	blue_tension: float,
	red_tension: float
) -> float:
	var highest := maxf(blue_tension, red_tension)
	return lerpf(1.0, 0.46, clampf(highest / 100.0, 0.0, 1.0))


static func evaluate_reaction(
	expected: Dictionary,
	decision: Dictionary,
	profile_id: String
) -> Dictionary:
	var match_profile := profile(profile_id)
	var multiplier: float = match_profile["reaction_multiplier"]
	var expected_offender_team: int = expected.get("offender_team_id", -1)
	var expected_affected_team: int = expected.get("affected_team_id", -1)
	if expected_affected_team < 0 and expected_offender_team >= 0:
		expected_affected_team = 1 - expected_offender_team
	var selected_offender_team: int = decision.get("offender_team_id", -1)
	var expected_awarded_team: int = expected.get(
		"awarded_team_id",
		expected_affected_team
	)
	if expected_awarded_team < 0 and expected_offender_team >= 0:
		expected_awarded_team = 1 - expected_offender_team
	var selected_awarded_team: int = decision.get("awarded_team_id", -1)
	if selected_awarded_team < 0 and selected_offender_team >= 0:
		selected_awarded_team = 1 - selected_offender_team

	var simplified: bool = decision.get("simplified", false)
	var offence_correct: bool = (
		decision["offence_id"] == expected["offence_id"]
		or (
			simplified
			and decision.get("category_id", "") == expected.get("category_id", "")
		)
	)
	var restart_correct: bool = decision["restart_id"] == expected["restart_id"]
	var discipline_correct: bool = (
		decision["discipline_id"] == expected["discipline_id"]
		or (
			simplified
			and not bool(decision.get("discipline_explicit", false))
		)
	)
	var awarded_team_correct: bool = (
		selected_awarded_team == expected_awarded_team
		or selected_awarded_team < 0 and expected_awarded_team < 0
	)
	var selected_offender_instance: int = decision.get(
		"offender_instance_id",
		0
	)
	var expected_offender_instance: int = expected.get(
		"offender_instance_id",
		0
	)
	var offender_correct: bool = (
		selected_offender_instance == expected_offender_instance
		if selected_offender_instance > 0 or expected_offender_instance > 0
		else (
			selected_offender_team == expected_offender_team
			or selected_offender_team < 0 and expected_offender_team < 0
		)
	)
	var quality := (
		(0.35 if offence_correct else 0.0)
		+ (0.20 if restart_correct else 0.0)
		+ (0.15 if discipline_correct else 0.0)
		+ (0.15 if offender_correct else 0.0)
		+ (0.15 if awarded_team_correct else 0.0)
	)
	var blue_delta := 0.0
	var red_delta := 0.0
	var reaction_strength := (8.0 + (1.0 - quality) * 25.0) * multiplier

	if quality >= 0.85:
		if expected_offender_team >= 0:
			if expected_offender_team == 0:
				blue_delta += 3.5 * multiplier
			else:
				red_delta += 3.5 * multiplier
		if expected_affected_team >= 0:
			if expected_affected_team == 0:
				blue_delta -= 6.0 * multiplier
			else:
				red_delta -= 6.0 * multiplier
	else:
		if expected_affected_team >= 0:
			if expected_affected_team == 0:
				blue_delta += reaction_strength
			else:
				red_delta += reaction_strength
		else:
			blue_delta += reaction_strength * 0.72
			red_delta += reaction_strength * 0.72

		if not offender_correct and selected_offender_team >= 0:
			if selected_offender_team == 0:
				blue_delta += reaction_strength * 0.72
			else:
				red_delta += reaction_strength * 0.72

		if not discipline_correct and selected_offender_team >= 0:
			if selected_offender_team == 0:
				blue_delta += reaction_strength * 0.48
			else:
				red_delta += reaction_strength * 0.48

		var other_team := (
			1 - expected_affected_team
			if expected_affected_team >= 0
			else -1
		)
		if other_team == 0:
			blue_delta += reaction_strength * 0.12
		elif other_team == 1:
			red_delta += reaction_strength * 0.12

	if (
		decision["offence_id"] == "verbal_management"
		and selected_offender_team >= 0
	):
		if selected_offender_team == 0:
			blue_delta -= 9.0 * multiplier
		else:
			red_delta -= 9.0 * multiplier

	return {
		"quality": quality,
		"blue_delta": blue_delta,
		"red_delta": red_delta,
		"offence_correct": offence_correct,
		"restart_correct": restart_correct,
		"discipline_correct": discipline_correct,
		"offender_correct": offender_correct,
		"awarded_team_correct": awarded_team_correct,
	}


static func missed_event_reaction(
	affected_team_id: int,
	profile_id: String
) -> Dictionary:
	var multiplier: float = profile(profile_id)["reaction_multiplier"]
	var reaction := 10.0 * multiplier
	return {
		"blue_delta": reaction if affected_team_id == 0 else reaction * 0.18,
		"red_delta": reaction if affected_team_id == 1 else reaction * 0.18,
	}
