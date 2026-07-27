extends RefCounted
class_name GameModeCatalog

const QUICK_MATCH_ID := "quick_match"
const WORLD_TOURNAMENT_ID := "world_tournament"
const INTERNATIONAL_CAREER_ID := "international_career"

const PROFILES := [
	{
		"id": QUICK_MATCH_ID,
		"label": "Partie rapide",
		"short_label": "Match unique",
		"description": (
			"Choisis librement l’enjeu et le stade pour jouer un seul match."
		),
		"button_label": "Lancer la partie rapide",
		"allows_importance": true,
		"stages": [
			{
				"label": "Match unique",
				"importance_id": "group_stage",
			},
		],
	},
	{
		"id": WORLD_TOURNAMENT_ID,
		"label": "Tournoi mondial",
		"short_label": "Coupe internationale",
		"description": (
			"Arbitre cinq rencontres d’une coupe internationale fictive, "
			+ "de la phase de groupes à la finale."
		),
		"button_label": "Commencer le tournoi",
		"allows_importance": false,
		"stages": [
			{
				"label": "Phase de groupes",
				"importance_id": "group_stage",
			},
			{
				"label": "Huitième de finale",
				"importance_id": "knockout",
			},
			{
				"label": "Quart de finale",
				"importance_id": "knockout",
			},
			{
				"label": "Demi-finale",
				"importance_id": "knockout",
			},
			{
				"label": "Finale",
				"importance_id": "final",
			},
		],
	},
	{
		"id": INTERNATIONAL_CAREER_ID,
		"label": "Carrière",
		"short_label": "Carrière internationale",
		"description": (
			"Enchaîne cinq désignations internationales de difficulté "
			+ "croissante. La sauvegarde et la réputation viendront ensuite."
		),
		"button_label": "Commencer la carrière",
		"allows_importance": false,
		"stages": [
			{
				"label": "Première désignation",
				"importance_id": "friendly",
			},
			{
				"label": "Match qualificatif",
				"importance_id": "qualifier",
			},
			{
				"label": "Phase de groupes",
				"importance_id": "group_stage",
			},
			{
				"label": "Phase à élimination directe",
				"importance_id": "knockout",
			},
			{
				"label": "Finale internationale",
				"importance_id": "final",
			},
		],
	},
]


static func profiles() -> Array:
	return PROFILES


static func profile(mode_id: String) -> Dictionary:
	for entry in PROFILES:
		if entry["id"] == mode_id:
			return entry
	return PROFILES[0]


static func stage(mode_id: String, stage_index: int) -> Dictionary:
	var mode_profile := profile(mode_id)
	var stages: Array = mode_profile["stages"]
	return stages[clampi(stage_index, 0, stages.size() - 1)]


static func stage_count(mode_id: String) -> int:
	return (profile(mode_id)["stages"] as Array).size()


static func is_last_stage(mode_id: String, stage_index: int) -> bool:
	return stage_index >= stage_count(mode_id) - 1


static func match_seed(
	session_seed: int,
	stage_index: int
) -> int:
	var safe_seed := maxi(session_seed, 1)
	if stage_index <= 0:
		return safe_seed
	return int(
		(safe_seed - 1 + stage_index * 7919) % 2147483646
	) + 1


static func context_label(mode_id: String, stage_index: int) -> String:
	var mode_profile := profile(mode_id)
	var stage_profile := stage(mode_id, stage_index)
	if mode_id == QUICK_MATCH_ID:
		return str(mode_profile["label"])
	return "%s · %s · %d/%d" % [
		mode_profile["short_label"],
		stage_profile["label"],
		stage_index + 1,
		stage_count(mode_id),
	]
