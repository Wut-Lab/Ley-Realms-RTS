extends Node
## Autoload holding the skirmish setup chosen in the menu.

const MAP_SIZE_NAMES := ["Small", "Medium", "Large", "Huge"]
const MAP_SIZES := [128, 168, 216, 264]
const BIOME_NAMES := ["Verdant Vale", "Highland Crags", "Frostmarch", "Ashen Wastes", "Elderwood"]
const DIFFICULTY_NAMES := ["Easy", "Hard"]
const ABUNDANCE_NAMES := ["Scarce", "Normal", "Abundant"]
const START_RES_NAMES := ["Low", "Standard", "High", "Very High"]
const FOREST_NAMES := ["Sparse", "Normal", "Dense"]
const WATER_NAMES := ["None", "Lakes", "Wetlands"]
const RELIEF_NAMES := ["Flat", "Rolling Hills", "Mountainous"]
const AGE_NAMES := ["Age of Settlement", "Age of Steel", "Age of Sorcery"]
const PEACE_NAMES := ["None", "5 minutes", "10 minutes", "20 minutes"]
const PEACE_MINUTES := [0, 5, 10, 20]
const VICTORY_NAMES := ["Conquest", "Ley Dominion", "Conquest or Dominion"]
const POP_NAMES := ["75", "125", "200"]
const POP_VALUES := [75, 125, 200]
const TEAM_NAMES := ["Free for all", "AIs allied vs you"]
const SPEED_NAMES := ["Normal", "Fast", "Very Fast"]
const SPEED_VALUES := [1.0, 1.5, 2.0]

var map_size := 1
var biome := 0
var map_seed := 12345
var random_seed := true
var num_ai := 1
var difficulty := 0
var abundance := 1
var start_res := 1
var forests := 1
var water := 1
var relief := 1
var fog := true
var reveal := false
var monsters := true
var shrines := true
var start_age := 1
var peace := 0
var victory := 0
var pop_cap := 1
var teams := 0
var player_color := 1
var speed := 0
var champions := true
var champion_class := 0
var autotest := false
var autotest_time := 1500.0
var shots: Array = []
var test_scale := 1.0


func to_dict() -> Dictionary:
	return {
		"size": MAP_SIZES[map_size], "biome": biome, "seed": map_seed, "players": num_ai + 1,
		"abundance": abundance, "forests": forests, "water": water, "relief": relief,
		"monsters": monsters, "shrines": shrines,
	}
