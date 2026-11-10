# res://Scripts/Utilities/GenerateWindmillCaves.gd
@tool
extends EditorScript
## Builds the two Windmill Cellar cave levels under FeroShaw's windmill - an easy, early area
## (low-level enemies, lots of chests with potions):
##
##   FeroShaw WindMill (unlocked by the Masoleum lock) -> WindmillCave1 (SpawnPoint)
##       ... crypt hole at the far end -> WindmillCave2 (SpawnPoint)
##       ... exit stairs at the far end -> back up to FeroShaw (SpawnPoint_Windmill)
##   Entry stairs lead back up: Cave1 -> FeroShaw SpawnPoint_Windmill, Cave2 -> Cave1 ExitArrival.
##
## Use: open this script -> File -> Run (Ctrl/Cmd+Shift+X). Re-running overwrites both levels.
## Don't like a layout? Change that level's "seed" and run again.
## Enemy entries: "pack" = random pack size range, "multiplier" = stat_multiplier (1.0 = as authored).

const SAVE_DIR: String = "res://Scenes/Caves"
const FEROSHAW: String = "res://Scenes/FeroShaw.tscn"
const OUTSIDE_ARRIVAL: String = "SpawnPoint_Windmill"

const POT_HP5: String = "res://Data/Items/Consumables/PotHp5.tres"
const POT_HP25: String = "res://Data/Items/Consumables/PotHp25.tres"
const POT_HP50: String = "res://Data/Items/Consumables/PotHp50.tres"
const POT_MANA5: String = "res://Data/Items/Consumables/PotMana5.tres"
const POT_MANA25: String = "res://Data/Items/Consumables/PotMana25.tres"
const POT_GROUP25: String = "res://Data/Items/Consumables/PotGroupHp25.tres"
const POT_REVIVE: String = "res://Data/Items/Consumables/PotRevive.tres"
const POT_CATNIP: String = "res://Data/Items/Consumables/PotCatnip.tres"

const SLIME: String = "res://Data/Enemies/EnSlimeDrone.tres"
const CYCLOPS: String = "res://Data/Enemies/EnScavengerCyclops.tres"
const CRAB: String = "res://Data/Enemies/EnMarshCrab.tres"
const CORRUPTED: String = "res://Data/Enemies/EnZombieCat.tres"

const CELLAR_1: Dictionary = {
	"name": "WindmillCave1",
	"title": "Windmill\nCellar",
	"seed": 811,
	"grid_size": Vector2i(30, 30),
	"room_count": 8,
	"enemy_count": 5,
	"enemies": [
		{"data": SLIME, "pack": Vector2i(2, 3), "multiplier": 1.0},
		{"data": CYCLOPS, "pack": Vector2i(1, 2), "multiplier": 0.9},
		{"data": CRAB, "pack": Vector2i(2, 3), "multiplier": 0.9, "world_scale": 0.65},
	],
	"chests": [
		{"gold": 30, "items": [POT_HP25, POT_HP25]},
		{"gold": 25, "items": [POT_MANA25, POT_HP5]},
		{"gold": 40, "items": [POT_HP25, POT_CATNIP]},
		{"gold": 35, "items": [POT_HP50]},
		{"gold": 50, "items": [POT_REVIVE, POT_MANA5]},
	],
	"exit_is_stairs": false,
	"next_scene": "res://Scenes/Caves/WindmillCave2.tscn",
	"next_arrival": "SpawnPoint",
	"exit_prompt": "Below a broken millstone, a shaft drops deeper. Climb down?",
	"previous_scene": FEROSHAW,
	"previous_arrival": OUTSIDE_ARRIVAL,
	"entry_prompt": "Climb the ladder back up into the windmill?",
}

const CELLAR_2: Dictionary = {
	"name": "WindmillCave2",
	"title": "Windmill\nDeep Cellar",
	"seed": 822,
	"grid_size": Vector2i(34, 34),
	"room_count": 10,
	"enemy_count": 6,
	"enemies": [
		{"data": CYCLOPS, "pack": Vector2i(2, 3), "multiplier": 1.0},
		{"data": SLIME, "pack": Vector2i(2, 4), "multiplier": 1.0},
		{"data": CORRUPTED, "pack": Vector2i(1, 1), "multiplier": 0.7},
		{"data": CRAB, "pack": Vector2i(2, 3), "multiplier": 1.0, "world_scale": 0.65},
	],
	"chests": [
		{"gold": 45, "items": [POT_HP50, POT_HP25]},
		{"gold": 40, "items": [POT_MANA25, POT_MANA25]},
		{"gold": 60, "items": [POT_GROUP25, POT_HP25]},
		{"gold": 50, "items": [POT_REVIVE, POT_HP50]},
		{"gold": 55, "items": [POT_CATNIP, POT_MANA25, POT_HP25]},
		{"gold": 120, "items": ["res://Data/Items/Equipment/ApprenticeBodyGarb.tres", POT_REVIVE]},
	],
	"exit_is_stairs": true,
	"next_scene": FEROSHAW,
	"next_arrival": OUTSIDE_ARRIVAL,
	"exit_prompt": "Daylight shows at the top of a long stair. Climb out by the windmill?",
	"previous_scene": "res://Scenes/Caves/WindmillCave1.tscn",
	"previous_arrival": "ExitArrival",
	"entry_prompt": "Climb back up to the windmill cellar?",
}


func _run() -> void:
	var saved: Array[String] = []
	for level: Dictionary in [CELLAR_1, CELLAR_2]:
		var cfg: Dictionary = level.duplicate(true)
		cfg["save_dir"] = SAVE_DIR
		var path: String = CaveFloorBuilder.build_and_save(cfg)
		if path.is_empty():
			push_error("GenerateWindmillCaves: %s failed - see errors above." % cfg["name"])
			return
		saved.append(path)
	EditorInterface.get_resource_filesystem().scan()
	for path: String in saved:
		if EditorInterface.get_open_scenes().has(path):
			EditorInterface.reload_scene_from_path(path)
	EditorInterface.open_scene_from_path(saved[0])
	print("GenerateWindmillCaves: built %s." % ", ".join(saved))
