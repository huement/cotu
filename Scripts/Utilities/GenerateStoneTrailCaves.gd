# res://Scripts/Utilities/GenerateStoneTrailCaves.gd
@tool
extends EditorScript
## Builds the three Stone Trail cave levels behind the RockCave mouth on Stone Trail.
## A step up from the Windmill Cellars: bigger packs, stat multipliers at / above 1.0,
## two haunting ghosts on every floor, and two Bone party-gear pieces per floor.
##
##   StoneTrail RockCave -> StoneTrailCave1 (SpawnPoint)
##       ... crypt hole at the far end -> StoneTrailCave2 (SpawnPoint)
##       ... crypt hole at the far end -> StoneTrailCave3 (SpawnPoint)
##       ... exit stairs at the far end -> back out to StoneTrail (SpawnPoint_StoneTrailCave)
##   Entry stairs lead back up: Cave1 -> StoneTrail SpawnPoint_StoneTrailCave,
##   Cave2 -> Cave1 ExitArrival, Cave3 -> Cave2 ExitArrival.
##
## Use: open this script -> File -> Run (Ctrl/Cmd+Shift+X). Re-running overwrites all three levels.
## Don't like a layout? Change that level's "seed" and run again.
## Enemy entries: "pack" = random pack size range, "multiplier" = stat_multiplier (1.0 = as authored).
## Ghosts sit on the FIRST and LAST chest (CaveFloorBuilder._add_ghosts), so the Bone gear is
## put in exactly those two chests: the ghosts guard the good loot.

const SAVE_DIR: String = "res://Scenes/Caves"
const STONE_TRAIL: String = "res://Scenes/StoneTrail.tscn"
const OUTSIDE_ARRIVAL: String = "SpawnPoint_StoneTrailCave"

const BONE_GEAR: String = "res://Data/Items/Loot/TokenPartyGearBone.tres"

const POT_HP25: String = "res://Data/Items/Consumables/PotHp25.tres"
const POT_HP50: String = "res://Data/Items/Consumables/PotHp50.tres"
const POT_HP100: String = "res://Data/Items/Consumables/PotHp100.tres"
const POT_MANA25: String = "res://Data/Items/Consumables/PotMana25.tres"
const POT_MANA50: String = "res://Data/Items/Consumables/PotMana50.tres"
const POT_GROUP25: String = "res://Data/Items/Consumables/PotGroupHp25.tres"
const POT_GROUP50: String = "res://Data/Items/Consumables/PotGroupHp50.tres"
const POT_REVIVE: String = "res://Data/Items/Consumables/PotRevive.tres"
const POT_CATNIP: String = "res://Data/Items/Consumables/PotCatnip.tres"

const CYCLOPS: String = "res://Data/Enemies/EnScavengerCyclops.tres"
const CRAB: String = "res://Data/Enemies/EnMarshCrab.tres"
const CORRUPTED: String = "res://Data/Enemies/EnZombieCat.tres"
const WRAITH: String = "res://Data/Enemies/EnRageWraith.tres"
const OCULAT: String = "res://Data/Enemies/EnOculatStriker.tres"
const SAVAGE: String = "res://Data/Enemies/EnZombieSavage.tres"

const CAVE_1: Dictionary = {
	"name": "StoneTrailCave1",
	"title": "Stone Trail\nCave",
	"seed": 911,
	"grid_size": Vector2i(30, 30),
	"room_count": 8,
	"enemy_count": 6,
	"enemies": [
		{"data": CYCLOPS, "pack": Vector2i(2, 3), "multiplier": 1.0},
		{"data": CRAB, "pack": Vector2i(3, 4), "multiplier": 1.0, "world_scale": 0.65},
		{"data": CORRUPTED, "pack": Vector2i(1, 2), "multiplier": 0.9},
		{"data": WRAITH, "pack": Vector2i(1, 2), "multiplier": 0.85},
	],
	"chests": [
		{"gold": 60, "items": [BONE_GEAR, POT_HP25]}, # ghost 1
		{"gold": 40, "items": [POT_HP50, POT_MANA25]},
		{"gold": 45, "items": [POT_HP25, POT_CATNIP]},
		{"gold": 50, "items": [POT_REVIVE, POT_MANA25]},
		{"gold": 80, "items": [BONE_GEAR, POT_HP50]}, # ghost 2
	],
	"ghost_count": 2,
	"ghost": {"multiplier": 0.85, "level": 2, "haunt_radius": 15},
	"exit_is_stairs": false,
	"next_scene": "res://Scenes/Caves/StoneTrailCave2.tscn",
	"next_arrival": "SpawnPoint",
	"exit_prompt": "A crack in the canyon floor drops into deeper dark. Climb down?",
	"previous_scene": STONE_TRAIL,
	"previous_arrival": OUTSIDE_ARRIVAL,
	"entry_prompt": "Climb back out onto the Stone Trail?",
}

const CAVE_2: Dictionary = {
	"name": "StoneTrailCave2",
	"title": "Stone Trail\nLower Cave",
	"seed": 922,
	"grid_size": Vector2i(32, 32),
	"room_count": 9,
	"enemy_count": 7,
	"enemies": [
		{"data": CYCLOPS, "pack": Vector2i(2, 3), "multiplier": 1.05},
		{"data": WRAITH, "pack": Vector2i(1, 2), "multiplier": 1.0},
		{"data": CORRUPTED, "pack": Vector2i(2, 3), "multiplier": 1.0},
		{"data": OCULAT, "pack": Vector2i(1, 2), "multiplier": 0.9},
	],
	"chests": [
		{"gold": 75, "items": [BONE_GEAR, POT_HP50]}, # ghost 1
		{"gold": 50, "items": [POT_MANA50, POT_HP25]},
		{"gold": 55, "items": [POT_GROUP25, POT_HP50]},
		{"gold": 60, "items": [POT_REVIVE, POT_MANA25]},
		{"gold": 50, "items": [POT_CATNIP, POT_HP50]},
		{"gold": 100, "items": [BONE_GEAR, POT_REVIVE]}, # ghost 2
	],
	"ghost_count": 2,
	"ghost": {"multiplier": 0.95, "level": 2, "haunt_radius": 15},
	"exit_is_stairs": false,
	"next_scene": "res://Scenes/Caves/StoneTrailCave3.tscn",
	"next_arrival": "SpawnPoint",
	"exit_prompt": "The tunnel ends at a sheer shaft. Cold air rises from below. Climb down?",
	"previous_scene": "res://Scenes/Caves/StoneTrailCave1.tscn",
	"previous_arrival": "ExitArrival",
	"entry_prompt": "Climb back up to the upper cave?",
}

const CAVE_3: Dictionary = {
	"name": "StoneTrailCave3",
	"title": "Stone Trail\nDeep Cave",
	"seed": 933,
	"grid_size": Vector2i(34, 34),
	"room_count": 10,
	"enemy_count": 8,
	"enemies": [
		{"data": OCULAT, "pack": Vector2i(2, 3), "multiplier": 1.0},
		{"data": WRAITH, "pack": Vector2i(2, 3), "multiplier": 1.0},
		{"data": SAVAGE, "pack": Vector2i(1, 2), "multiplier": 1.0},
		{"data": CORRUPTED, "pack": Vector2i(2, 4), "multiplier": 1.05},
	],
	"chests": [
		{"gold": 90, "items": [BONE_GEAR, POT_HP100]}, # ghost 1
		{"gold": 60, "items": [POT_MANA50, POT_HP50]},
		{"gold": 70, "items": [POT_GROUP50, POT_HP25]},
		{"gold": 65, "items": [POT_REVIVE, POT_MANA50]},
		{"gold": 60, "items": [POT_CATNIP, POT_HP50, POT_MANA25]},
		{"gold": 150, "items": [BONE_GEAR, POT_REVIVE, POT_HP50]}, # ghost 2
	],
	"ghost_count": 2,
	"ghost": {"multiplier": 1.0, "level": 3, "haunt_radius": 15},
	"exit_is_stairs": true,
	"next_scene": STONE_TRAIL,
	"next_arrival": OUTSIDE_ARRIVAL,
	"exit_prompt": "Daylight spills down a long stair. Climb out onto the Stone Trail?",
	"previous_scene": "res://Scenes/Caves/StoneTrailCave2.tscn",
	"previous_arrival": "ExitArrival",
	"entry_prompt": "Climb back up to the lower cave?",
}


func _run() -> void:
	var saved: Array[String] = []
	for level: Dictionary in [CAVE_1, CAVE_2, CAVE_3]:
		var cfg: Dictionary = level.duplicate(true)
		cfg["save_dir"] = SAVE_DIR
		var path: String = CaveFloorBuilder.build_and_save(cfg)
		if path.is_empty():
			push_error("GenerateStoneTrailCaves: %s failed - see errors above." % cfg["name"])
			return
		saved.append(path)
	EditorInterface.get_resource_filesystem().scan()
	for path: String in saved:
		if EditorInterface.get_open_scenes().has(path):
			EditorInterface.reload_scene_from_path(path)
	EditorInterface.open_scene_from_path(saved[0])
	print("GenerateStoneTrailCaves: built %s." % ", ".join(saved))
