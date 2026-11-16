# res://Scripts/Utilities/GenerateGloomReachDungeon.gd
@tool
extends EditorScript
## Builds the Gloom Reach dungeon - three floors under the GloomReach RockCave:
##
##   GloomReach RockCave -> GloomReachDungeon_Upper (SpawnPoint)
##       ... crypt hole at the far end -> GloomReachDungeon_Middle (SpawnPoint)
##       ... crypt hole at the far end -> GloomReachDungeon (SpawnPoint)
##       ... boss chamber: Void Weaver (level 8, x2.2 boss stats) + two level-8 Hazard Cleaners.
##           Beat it and the Arcanum Shard "gloomreach_dungeon" appears where it stood;
##           the north gate then leads back up to GloomReach (DungeonExitArrival).
##   Each floor's entry stairs lead back up (Upper -> GloomReach, the others -> the floor above's
##   ExitArrival).
##
## Use: open this script -> File -> Run (Ctrl/Cmd+Shift+X). Re-running overwrites all three floors
## (the shard is rebuilt with them). Don't like a layout? Change that floor's "seed" and run again.
## Headless: godot --path . --headless -s res://Scripts/Utilities/BuildGloomReachDungeon.gd
##
## Difficulty knobs (per enemy type): "pack" = how many in the fight, "level" = level of that
## placement (0 / missing = the sheet's level), "multiplier" = stat_multiplier.
## Hazard Cleaners appear on every floor and level up as you go down (5 -> 6 -> 7, boss room 8).
## Climbs from the GloomReach surface (levels 2-6) toward the Slime Lord-tier boss.
## Boss chamber loot / exit come from Data/Lore/Bosses.csv row BOSS_ID.

const SAVE_DIR: String = "res://Scenes/Dungeons"
const BOSS_ID: int = 13

const ROOMS: Array[String] = [
	"res://Scenes/Dungeons/Parts/SmallRoom.tscn",
	"res://Scenes/Dungeons/Parts/WideRoom.tscn",
	"res://Scenes/Dungeons/Parts/LargeRoom.tscn",
	"res://Scenes/Dungeons/Parts/CornerRoom.tscn",
]
const ROOM_WEIGHTS: Array[int] = [1, 3, 4, 2]

## Shard in the boss chamber (ShardLedger.CATALOG row "gloomreach_dungeon").
const SHARD_SCENE: String = "res://Scenes/Objects/ArcanumShard.tscn"
const SHARD_ID: String = "gloomreach_dungeon"
const SHARD_PLACE: String = "Gloom Reach Dungeon"

const POT_HP25: String = "res://Data/Items/Consumables/PotHp25.tres"
const POT_HP50: String = "res://Data/Items/Consumables/PotHp50.tres"
const POT_HP100: String = "res://Data/Items/Consumables/PotHp100.tres"
const POT_MANA25: String = "res://Data/Items/Consumables/PotMana25.tres"
const POT_MANA50: String = "res://Data/Items/Consumables/PotMana50.tres"
const POT_REVIVE: String = "res://Data/Items/Consumables/PotRevive.tres"
const POT_CATNIP: String = "res://Data/Items/Consumables/PotCatnip.tres"
const POT_GROUP25: String = "res://Data/Items/Consumables/PotGroupHp25.tres"
const POT_GROUP50: String = "res://Data/Items/Consumables/PotGroupHp50.tres"

const EN_SAVAGE: String = "res://Data/Enemies/EnZombieSavage.tres"
const EN_PUNK: String = "res://Data/Enemies/EnZombiePunk.tres"
const EN_GUARD: String = "res://Data/Enemies/EnZombieGuard.tres"
const EN_CORRUPTED: String = "res://Data/Enemies/EnZombieCat.tres"
const EN_KNIGHT: String = "res://Data/Enemies/EnZombieKnight.tres"
const EN_RONIN: String = "res://Data/Enemies/EnCorruptedRonin.tres"
const EN_CLEANER: String = "res://Data/Enemies/EnHazardCleaner.tres"
const EN_ASSASSIN: String = "res://Data/Enemies/EnShadowAssassin.tres"
const EN_WEAVER: String = "res://Data/Enemies/EnVoidWeaver.tres"
const EN_SERVITOR: String = "res://Data/Enemies/EnHeavyServitor.tres"

## Ghosts: tougher than Vero Wood's, level 2 (a little less time to turn around).
const GHOST: Dictionary = {
	"data": "res://Data/Enemies/EnGhost.tres",
	"multiplier": 0.85,
	"level": 2,
	"haunt_radius": 15,
}

const UPPER: Dictionary = {
	"name": "GloomReachDungeon_Upper",
	"title": "Gloom Reach\nDungeon I",
	"seed": 113,
	"room_count": 8,
	"enemy_count": 7,
	"enemies": [
		{"data": EN_SAVAGE, "pack": 2, "multiplier": 1.0},
		{"data": EN_PUNK, "pack": 2, "multiplier": 1.0},
		{"data": EN_CLEANER, "pack": 2, "level": 5, "multiplier": 1.0},
		{"data": EN_GUARD, "pack": 2, "multiplier": 1.0},
	],
	"ghost_count": 1,
	"chests": [
		{"gold": 120, "items": [POT_HP50, POT_HP25, POT_MANA25]},
		{"gold": 160, "items": ["res://Data/Items/Equipment/KnightHeadArmor.tres", POT_CATNIP]},
		{"gold": 200, "items": ["res://Data/Items/Equipment/SteelKiteShield.tres", POT_REVIVE]},
	],
	"has_boss": false,
	"next_scene": "res://Scenes/Dungeons/GloomReachDungeon_Middle.tscn",
	"next_arrival": "SpawnPoint",
	"exit_prompt": "A slab has slid aside over a shaft that breathes cold, rotten air. Climb down?",
	"previous_scene": "res://Scenes/GloomReach.tscn",
	"previous_arrival": "DungeonExitArrival",
	"entry_prompt": "Climb the stairs back up to Gloom Reach?",
}

const MIDDLE: Dictionary = {
	"name": "GloomReachDungeon_Middle",
	"title": "Gloom Reach\nDungeon II",
	"seed": 127,
	"room_count": 9,
	"enemy_count": 8,
	"enemies": [
		{"data": EN_KNIGHT, "pack": 2, "multiplier": 1.0},
		{"data": EN_RONIN, "pack": 2, "multiplier": 1.0},
		{"data": EN_CLEANER, "pack": 2, "level": 6, "multiplier": 1.0},
		{"data": EN_ASSASSIN, "pack": 1, "multiplier": 1.0},
	],
	"ghost_count": 2,
	"chests": [
		{"gold": 180, "items": [POT_HP50, POT_MANA50]},
		{"gold": 240, "items": ["res://Data/Items/Equipment/KnightBodyArmor.tres", POT_HP50]},
		{"gold": 300, "items": [POT_REVIVE, POT_GROUP25]},
	],
	"has_boss": false,
	"next_scene": "res://Scenes/Dungeons/GloomReachDungeon.tscn",
	"next_arrival": "SpawnPoint",
	"exit_prompt": "Something below is humming. The air is thick with it. Climb down to the vault?",
	"previous_scene": "res://Scenes/Dungeons/GloomReachDungeon_Upper.tscn",
	"previous_arrival": "ExitArrival",
	"entry_prompt": "Climb back up to the first crypt?",
}

const LOWER: Dictionary = {
	"name": "GloomReachDungeon",
	"title": "Gloom Reach\nDungeon III",
	"seed": 139,
	"room_count": 8,
	"enemy_count": 7,
	"enemies": [
		{"data": EN_RONIN, "pack": 2, "multiplier": 1.1},
		{"data": EN_WEAVER, "pack": 2, "multiplier": 1.0},
		{"data": EN_SERVITOR, "pack": 2, "multiplier": 1.0},
		{"data": EN_ASSASSIN, "pack": 2, "multiplier": 1.0},
		{"data": EN_CLEANER, "pack": 2, "level": 7, "multiplier": 1.0},
	],
	"ghost_count": 2,
	"chests": [
		{"gold": 260, "items": [POT_HP100, POT_MANA50]},
		{"gold": 320, "items": ["res://Data/Items/Equipment/KnightLegsArmor.tres", POT_HP50]},
		{"gold": 400, "items": [POT_REVIVE, POT_GROUP50]},
	],
	"has_boss": true,
	"boss_id": BOSS_ID,
	## Void Weaver flanked by two Hazard Cleaners. "level" applies to the whole group;
	## "boss_multiplier" only to the Void Weaver (about 250 HP / 63 attack in battle).
	"boss_enemy": {
		"data": EN_WEAVER,
		"minion_data": EN_CLEANER,
		"minion_count": 2,
		"level": 8,
		"multiplier": 1.0,
		"boss_multiplier": 2.2,
		"model_scale_multiplier": 1.5,
	},
	"previous_scene": "res://Scenes/Dungeons/GloomReachDungeon_Middle.tscn",
	"previous_arrival": "ExitArrival",
	"entry_prompt": "Climb back up to the second crypt?",
}


## Builds all three floors. Returns saved paths, or an empty array on failure.
## Callable from the editor (_run) or a headless SceneTree runner.
static func build_all() -> Array[String]:
	var saved: Array[String] = []
	for floor_cfg: Dictionary in [UPPER, MIDDLE, LOWER]:
		var cfg: Dictionary = floor_cfg.duplicate(true)
		cfg["save_dir"] = SAVE_DIR
		cfg["room_scenes"] = ROOMS
		cfg["room_weights"] = ROOM_WEIGHTS
		cfg["ghost"] = GHOST
		if bool(cfg.get("has_boss", false)):
			cfg["inject"] = _add_boss_shard
		var path: String = DungeonFloorBuilder.build_and_save(cfg)
		if path.is_empty():
			push_error("GenerateGloomReachDungeon: %s failed - see errors above." % cfg["name"])
			return []
		saved.append(path)
	return saved


## Puts the Arcanum Shard in the boss chamber. It stays hidden until the boss is beaten, then
## appears where the boss stood (ArcanumShard.boss / appear_at_boss).
static func _add_boss_shard(root: Node3D, _layout: Variant) -> void:
	var shard_scene: PackedScene = load(SHARD_SCENE) as PackedScene
	if shard_scene == null:
		push_error("GenerateGloomReachDungeon: could not load %s." % SHARD_SCENE)
		return
	var shard: Node3D = shard_scene.instantiate() as Node3D
	shard.name = "ArcanumShard"
	shard.set("shard_id", SHARD_ID)
	shard.set("level_name", SHARD_PLACE)
	var spawn: Node3D = root.get_node_or_null("BossSpawn") as Node3D
	if spawn != null:
		shard.position = Vector3(spawn.position.x, 0.0, spawn.position.z)
	var boss: Node = root.find_child("Boss", true, false)
	if boss != null:
		# Boss-only multiplier (also set by DungeonFloorBuilder; set here too so an editor holding an
		# older cached copy of the builder still gets it right).
		var boss_cfg: Dictionary = LOWER.get("boss_enemy", {})
		if "boss_stat_multiplier" in boss:
			boss.set("boss_stat_multiplier", float(boss_cfg.get("boss_multiplier", 1.0)))
		# Path from the shard (a child of root) to the boss: "../<path from root>".
		var parts: PackedStringArray = []
		var node: Node = boss
		while node != null and node != root:
			parts.insert(0, String(node.name))
			node = node.get_parent()
		shard.set("boss", NodePath("../" + "/".join(parts)))
	else:
		push_warning("GenerateGloomReachDungeon: no Boss found - the shard will just be lying there.")
	root.add_child(shard)


func _run() -> void:
	var saved: Array[String] = build_all()
	if saved.is_empty():
		return

	EditorInterface.get_resource_filesystem().scan()
	for path: String in saved:
		if EditorInterface.get_open_scenes().has(path):
			EditorInterface.reload_scene_from_path(path)
	EditorInterface.open_scene_from_path(saved[0])
	print("GenerateGloomReachDungeon: built %s." % ", ".join(saved))
