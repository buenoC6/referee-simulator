extends RefCounted
class_name StadiumCatalog

const DEFAULT_ID := "royal_brussels"

const STADIUMS: Array[Dictionary] = [
	{
		"id": "royal_brussels",
		"home_team": "Royal Bruxelles",
		"short_name": "ROYAL",
		"stadium_name": "Stade du Parc",
		"city": "Bruxelles",
		"capacity": 28400,
		"description": (
			"Une enceinte urbaine compacte, bleu royal et or, baignée par "
			+ "une lumière de fin d’après-midi."
		),
		"primary_color": "#1855a5",
		"secondary_color": "#f4c84b",
		"away_color": "#d83a4e",
		"seat_color": "#133b70",
		"stand_color": "#17263b",
		"runoff_color": "#1e4730",
		"grass_base": "#145632",
		"grass_light": "#1d6639",
		"sky_top": "#367bb8",
		"sky_horizon": "#c8e4f1",
		"ground_horizon": "#8eb68c",
		"ground_bottom": "#31583b",
		"ambient_color": "#dcefff",
		"ambient_energy": 0.48,
		"sun_color": "#fff0c7",
		"sun_energy": 1.05,
		"sun_rotation": Vector3(-48.0, -32.0, 0.0),
		"floodlight_energy": 0.32,
	},
	{
		"id": "forge_united",
		"home_team": "Forge United",
		"short_name": "FORGE",
		"stadium_name": "Arène des Forges",
		"city": "Liège",
		"capacity": 36100,
		"description": (
			"Un chaudron rouge et anthracite sous les projecteurs, plus vertical "
			+ "et volontairement intimidant."
		),
		"primary_color": "#c62e3f",
		"secondary_color": "#f2f0e7",
		"away_color": "#2874cf",
		"seat_color": "#6e1825",
		"stand_color": "#161a22",
		"runoff_color": "#203d31",
		"grass_base": "#145f36",
		"grass_light": "#207542",
		"sky_top": "#18263f",
		"sky_horizon": "#d07968",
		"ground_horizon": "#5c5f66",
		"ground_bottom": "#17241f",
		"ambient_color": "#b8c9ea",
		"ambient_energy": 0.4,
		"sun_color": "#ffd6ad",
		"sun_energy": 0.68,
		"sun_rotation": Vector3(-22.0, 38.0, 0.0),
		"floodlight_energy": 1.25,
	},
	{
		"id": "coastal_sporting",
		"home_team": "Sporting Littoral",
		"short_name": "SPORTING",
		"stadium_name": "Stade des Dunes",
		"city": "Ostende",
		"capacity": 22750,
		"description": (
			"Un stade ouvert aux tons turquoise et corail, avec une lumière "
			+ "claire venue de la côte."
		),
		"primary_color": "#087f8c",
		"secondary_color": "#ff8066",
		"away_color": "#d9465f",
		"seat_color": "#075d68",
		"stand_color": "#20343d",
		"runoff_color": "#275a43",
		"grass_base": "#185d37",
		"grass_light": "#237043",
		"sky_top": "#3a99cf",
		"sky_horizon": "#d9edf3",
		"ground_horizon": "#8fbaa6",
		"ground_bottom": "#3a6951",
		"ambient_color": "#e0f4ff",
		"ambient_energy": 0.52,
		"sun_color": "#fff1cf",
		"sun_energy": 1.12,
		"sun_rotation": Vector3(-58.0, 24.0, 0.0),
		"floodlight_energy": 0.18,
	},
]


static func profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stadium in STADIUMS:
		result.append(stadium.duplicate(true))
	return result


static func profile(stadium_id: String) -> Dictionary:
	for stadium in STADIUMS:
		if stadium["id"] == stadium_id:
			return stadium.duplicate(true)
	return STADIUMS[0].duplicate(true)
