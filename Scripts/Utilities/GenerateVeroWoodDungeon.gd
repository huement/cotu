# res://Scripts/Utilities/GenerateVeroWoodDungeon.gd
@tool
extends EditorScript
## Builds the Vero Wood dungeon - two floors under the VeroWood CryptHole:
##
##   VeroWood CryptHole -> VeroWoodDungeon_Upper (SpawnPoint)
##       ... crypt hole at the far end -> VeroWoodDungeon (SpawnPoint)
##       ... boss chamber: Rage Wraith + Cyclops minions (same setup as dungeon_map) ->
##           north gate back up to VeroWood
##   Each floor's entry stairs lead back up (Upper -> VeroWood, boss floor -> Upper's ExitArrival).
##
## Both floors have ghosts (GhostAmbushComponent jump scares), chests, and mid-forest enemy packs.
## Use: open this script -> File -> Run (Ctrl/Cmd+Shift+X). Re-running overwrites both floors.
## Don't like a layout? Change that floor's "seed" and run again.
##
## Difficulty knobs (per enemy type): "pack" = how many in the fight, "multiplier" = stat_multiplier.
## Boss chamber loot / exit come from Data/Lore/Bosses.csv row BOSS_ID.

const SAVE_DIR: String = "res://Scenes/Dungeons"
const BOSS_ID: int = 12

const ROOMS: Array[String] = [
	"res://Scenes/Dungeons/Parts/SmallRoom.tscn",
	"res://Scenes/Dungeons/Parts/WideRoom.tscn",
	"res://Scenes/Dungeons/Parts/LargeRoom.tscn",
	"res://Scenes/Dungeons/Parts/CornerRoom.tscn",
]
## Same open mix as the Fero Shaw dungeon: mostly Large and Wide rooms.
const ROOM_WEIGHTS: Array[int] = [1, 3, 4, 2]

const POT_HP25: String = "res://Data/Items/Consumables/PotHp25.tres"
const POT_HP50: String = "res://Data/Items/Consumables/PotHp50.tres"
const POT_MANA25: String = "res://Data/Items/Consumables/PotMana25.tres"
const POT_MANA50: String = "res://Data/Items/Consumables/PotMana50.tres"
const POT_REVIVE: String = "res://Data/Items/Consumables/PotRevive.tres"
const POT_CATNIP: String = "res://Data/Items/Consumables/PotCatnip.tres"
const POT_GROUP25: String = "res://Data/Items/Consumables/PotGroupHp25.tres"
const POT_GROUP50: String = "res://Data/Items/Consumables/PotGroupHp50.tres"

## Ghosts: a touch tougher than Fero Shaw's soft haunt pack.
const GHOST: Dictionary = {
	"data": "res://Data/Enemies/EnGhost.tres",
	"multiplier": 0.75,
	"level": 2,
	"haunt_radius": 3,
}

const UPPER: Dictionary = {
	"name": "VeroWoodDungeon_Upper",
	"title": "Vero Wood\nDungeon Top",
	"seed": 73,
	"room_count": 8,
	"enemy_count": 7,
	"enemies": [
		{"data": "res://Data/Enemies/EnZombieSavage.tres", "pack": 2, "multiplier": 1.0},
		{"data": "res://Data/Enemies/EnScavengerCyclops.tres", "pack": 2, "multiplier": 1.0},
		{"data": "res://Data/Enemies/EnRageWraith.tres", "pack": 1, "multiplier": 0.9},
		{"data": "res://Data/Enemies/EnZombieGuard.tres", "pack": 2, "multiplier": 1.0},
	],
	"ghost_count": 2,
	"chests": [
		{"gold": 80, "items": [POT_HP25, POT_HP50, POT_MANA25]},
		{"gold": 120, "items": ["res://Data/Items/Equipment/IronHeadArmor.tres", POT_CATNIP]},
		{"gold": 160, "items": ["res://Data/Items/Equipment/SteelKiteShield.tres", POT_REVIVE]},
	],
	"has_boss": false,
	"next_scene": "res://Scenes/Dungeons/VeroWoodDungeon.tscn",
	"next_arrival": "SpawnPoint",
	"exit_prompt": "A root-choked shaft drops into colder dark. Climb down to the deeper crypt?",
	"previous_scene": "res://Scenes/VeroWood.tscn",
	"previous_arrival": "SpawnPointDungeon",
	"entry_prompt": "Climb the stairs back up to the Vero Woods?",
}

const LOWER: Dictionary = {
	"name": "VeroWoodDungeon",
	"title": "Vero Wood\nDungeon Btm",
	"seed": 91,
	"room_count": 7,
	"enemy_count": 6,
	"enemies": [
		{"data": "res://Data/Enemies/EnRageWraith.tres", "pack": 2, "multiplier": 1.0},
		{"data": "res://Data/Enemies/EnZombieSaber.tres", "pack": 2, "multiplier": 1.0},
		{"data": "res://Data/Enemies/EnScavengerCyclops.tres", "pack": 2, "multiplier": 1.1},
		{"data": "res://Data/Enemies/EnOculatStriker.tres", "pack": 1, "multiplier": 1.0},
	],
	"ghost_count": 2,
	"chests": [
		{"gold": 140, "items": [POT_HP50, POT_MANA50]},
		{"gold": 200, "items": ["res://Data/Items/Equipment/IronBodyArmor.tres", POT_HP25]},
		{"gold": 260, "items": [POT_REVIVE, POT_GROUP50]},
	],
	"has_boss": true,
	"boss_id": BOSS_ID,
	## Same kind of boss as Scenes/dungeon_map.tscn: Rage Wraith + two Cyclops.
	"boss_enemy": {
		"data": "res://Data/Enemies/EnRageWraith.tres",
		"minion_data": "res://Data/Enemies/EnScavengerCyclops.tres",
		"minion_count": 2,
		"multiplier": 1.8,
		"model_scale_multiplier": 1.5,
	},
	"previous_scene": "res://Scenes/Dungeons/VeroWoodDungeon_Upper.tscn",
	"previous_arrival": "ExitArrival",
	"entry_prompt": "Climb back up to the upper crypt?",
}


## Builds both floors. Returns saved paths, or an empty array on failure.
## Callable from the editor (_run) or a headless SceneTree runner.
static func build_all() -> Array[String]:
	var saved: Array[String] = []
	for floor_cfg: Dictionary in [UPPER, LOWER]:
		var cfg: Dictionary = floor_cfg.duplicate(true)
		cfg["save_dir"] = SAVE_DIR
		cfg["room_scenes"] = ROOMS
		cfg["room_weights"] = ROOM_WEIGHTS
		cfg["ghost"] = GHOST
		var path: String = DungeonFloorBuilder.build_and_save(cfg)
		if path.is_empty():
			push_error("GenerateVeroWoodDungeon: %s failed - see errors above." % cfg["name"])
			return []
		saved.append(path)
	return saved


func _run() -> void:
	var saved: Array[String] = build_all()
	if saved.is_empty():
		return

	EditorInterface.get_resource_filesystem().scan()
	for path: String in saved:
		if EditorInterface.get_open_scenes().has(path):
			EditorInterface.reload_scene_from_path(path)
	EditorInterface.open_scene_from_path(saved[0])
	print("GenerateVeroWoodDungeon: built %s." % ", ".join(saved))
