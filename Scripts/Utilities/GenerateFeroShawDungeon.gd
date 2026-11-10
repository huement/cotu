# res://Scripts/Utilities/GenerateFeroShawDungeon.gd
@tool
extends EditorScript
## Builds the Fero Shaw dungeon - the FIRST dungeon in the game, so it is deliberately easy:
##
##   FeroShaw CryptHole -> FeroShawDungeon_Upper (SpawnPoint)
##       ... crypt hole at the far end -> FeroShawDungeon (SpawnPoint)
##       ... boss chamber: Azurian Drone boss + minions -> north gate back up to FeroShaw
##   Each floor's entry stairs lead back up (Upper -> FeroShaw, boss floor -> Upper's ExitArrival).
##
## Both floors have ghosts (GhostAmbushComponent jump scares), chests, and easy enemy packs.
## Use: open this script -> File -> Run (Ctrl/Cmd+Shift+X). Re-running overwrites both floors.
## Don't like a layout? Change that floor's "seed" and run again.
##
## Difficulty knobs (per enemy type): "pack" = how many in the fight, "multiplier" = stat_multiplier
## (0.6 = much softer, 1.0 = as authored, 1.8 = boss-tough). Starter party: four level-5 cats.
## Boss chamber loot / exit come from Data/Lore/Bosses.csv row BOSS_ID.

const SAVE_DIR: String = "res://Scenes/Dungeons"
const BOSS_ID: int = 11

const ROOMS: Array[String] = [
	"res://Scenes/Dungeons/Parts/SmallRoom.tscn",
	"res://Scenes/Dungeons/Parts/WideRoom.tscn",
	"res://Scenes/Dungeons/Parts/LargeRoom.tscn",
	"res://Scenes/Dungeons/Parts/CornerRoom.tscn",
]
## Bigger, more open than Dungeon 1: mostly Large and Wide rooms.
const ROOM_WEIGHTS: Array[int] = [1, 3, 4, 2]

const POT_HP25: String = "res://Data/Items/Consumables/PotHp25.tres"
const POT_HP50: String = "res://Data/Items/Consumables/PotHp50.tres"
const POT_MANA25: String = "res://Data/Items/Consumables/PotMana25.tres"
const POT_REVIVE: String = "res://Data/Items/Consumables/PotRevive.tres"
const POT_CATNIP: String = "res://Data/Items/Consumables/PotCatnip.tres"
const POT_GROUP25: String = "res://Data/Items/Consumables/PotGroupHp25.tres"

## Ghosts: soft (0.6 stats) and slow to strike (level 1 = 4 s to turn around) for dungeon one.
const GHOST: Dictionary = {
	"data": "res://Data/Enemies/EnGhost.tres",
	"multiplier": 0.6,
	"level": 1,
	"haunt_radius": 3,
}

const UPPER: Dictionary = {
	"name": "FeroShawDungeon_Upper",
	"title": "Fero Shaw\nDungeon Top",
	"seed": 31,
	"room_count": 8,
	"enemy_count": 7,
	"enemies": [
		{"data": "res://Data/Enemies/EnSlimeDrone.tres", "pack": 2, "multiplier": 1.0},
		{"data": "res://Data/Enemies/EnScavengerCyclops.tres", "pack": 2, "multiplier": 1.0},
		{"data": "res://Data/Enemies/EnZombieCat.tres", "pack": 1, "multiplier": 0.8},
		{"data": "res://Data/Enemies/EnRageWraith.tres", "pack": 1, "multiplier": 0.8},
	],
	"ghost_count": 2,
	"chests": [
		{"gold": 60, "items": [POT_HP25, POT_HP25, POT_MANA25]},
		{"gold": 90, "items": ["res://Data/Items/Equipment/ApprenticeHeadGarb.tres", POT_CATNIP]},
		{"gold": 120, "items": ["res://Data/Items/Equipment/ArmorCrusaderRegularShield.tres", POT_REVIVE]},
	],
	"has_boss": false,
	"next_scene": "res://Scenes/Dungeons/FeroShawDungeon.tscn",
	"next_arrival": "SpawnPoint",
	"exit_prompt": "Cold air rises from a gap beneath a cracked slab. Climb down to the deeper crypt?",
	"previous_scene": "res://Scenes/FeroShaw.tscn",
	"previous_arrival": "SpawnPoint_Dungeon",
	"entry_prompt": "Climb the stairs back up to Fero Shaw?",
}

const LOWER: Dictionary = {
	"name": "FeroShawDungeon",
	"title": "Fero Shaw\nDungeon Btm",
	"seed": 47,
	"room_count": 7,
	"enemy_count": 6,
	"enemies": [
		{"data": "res://Data/Enemies/EnZombieCat.tres", "pack": 2, "multiplier": 0.8},
		{"data": "res://Data/Enemies/EnScavengerCyclops.tres", "pack": 2, "multiplier": 1.0},
		{"data": "res://Data/Enemies/EnRageWraith.tres", "pack": 2, "multiplier": 0.8},
		{"data": "res://Data/Enemies/EnSlimeDrone.tres", "pack": 3, "multiplier": 1.0},
	],
	"ghost_count": 2,
	"chests": [
		{"gold": 100, "items": [POT_HP50, POT_MANA25]},
		{"gold": 150, "items": ["res://Data/Items/Equipment/ArmorAmazonRegularBody.tres", POT_HP25]},
		{"gold": 200, "items": [POT_REVIVE, POT_GROUP25]},
	],
	"has_boss": true,
	"boss_id": BOSS_ID,
	## The boss: an Azurian Drone (stronger than anything else here) flanked by two Cyclops.
	"boss_enemy": {
		"data": "res://Data/Enemies/EnAzurianDrone.tres",
		"minion_data": "res://Data/Enemies/EnScavengerCyclops.tres",
		"minion_count": 2,
		"multiplier": 1.8,
		"model_scale_multiplier": 1.5,
	},
	"previous_scene": "res://Scenes/Dungeons/FeroShawDungeon_Upper.tscn",
	"previous_arrival": "ExitArrival",
	"entry_prompt": "Climb back up to the upper crypt?",
}


func _run() -> void:
	var saved: Array[String] = []
	for floor_cfg: Dictionary in [UPPER, LOWER]:
		var cfg: Dictionary = floor_cfg.duplicate(true)
		cfg["save_dir"] = SAVE_DIR
		cfg["room_scenes"] = ROOMS
		cfg["room_weights"] = ROOM_WEIGHTS
		cfg["ghost"] = GHOST
		var path: String = DungeonFloorBuilder.build_and_save(cfg)
		if path.is_empty():
			push_error("GenerateFeroShawDungeon: %s failed - see errors above." % cfg["name"])
			return
		saved.append(path)

	EditorInterface.get_resource_filesystem().scan()
	for path: String in saved:
		if EditorInterface.get_open_scenes().has(path):
			EditorInterface.reload_scene_from_path(path)
	EditorInterface.open_scene_from_path(saved[0])
	print("GenerateFeroShawDungeon: built %s." % ", ".join(saved))
