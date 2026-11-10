# res://Scripts/Utilities/GenerateBattleTestArena.gd
@tool
extends EditorScript
## Builds the Battle Test Arena — a tiny empty dungeon with a BattleConfigTerminal.
## Interact with the statue to pick any EnemyData pack (main x1–3 + optional minions), then
## fade into combat the same way GloomReach's BossStatue does.
##
## Use: open this script → File → Run. Or headless:
##   godot --path . --headless -s res://Scripts/Utilities/BuildBattleTestArena.gd
## Jump there from the debug menu (DUNGEONS → Battle Test Arena).

const SAVE_DIR: String = "res://Scenes/Dungeons"
const LEVEL_NAME: String = "BattleTestArena"
const TERMINAL_SCENE: String = "res://Scenes/Objects/BattleConfigTerminal.tscn"

const ROOMS: Array[String] = [
	"res://Scenes/Dungeons/Parts/LargeRoom.tscn",
]
const ROOM_WEIGHTS: Array[int] = [1]

const CFG: Dictionary = {
	"name": LEVEL_NAME,
	"title": "Battle\nTest Arena",
	"seed": 7,
	"room_count": 1,
	"enemy_count": 0,
	"enemies": [],
	"ghost_count": 0,
	"chests": [],
	"has_boss": false,
	"next_scene": "res://Scenes/GloomReach.tscn",
	"next_arrival": "SpawnPoint",
	"exit_prompt": "Leave the arena through the shaft?",
	"previous_scene": "res://Scenes/GloomReach.tscn",
	"previous_arrival": "SpawnPoint",
	"entry_prompt": "Climb the stairs back up to Gloom Reach?",
	"fog_begin": 14.0,
	"fog_end": 40.0,
}


## Builds the arena. Returns the saved path, or "" on failure.
## Callable from the editor (_run) or a headless SceneTree runner.
static func build() -> String:
	var cfg: Dictionary = CFG.duplicate(true)
	cfg["save_dir"] = SAVE_DIR
	cfg["room_scenes"] = ROOMS
	cfg["room_weights"] = ROOM_WEIGHTS
	cfg["inject"] = _inject_arena
	return DungeonFloorBuilder.build_and_save(cfg)


## Places FightStart / EnemySpawn markers and the BattleConfigTerminal in the first room.
static func _inject_arena(root: Node3D, layout: DungeonGenerator.Layout) -> void:
	if layout.rooms.is_empty():
		push_error("GenerateBattleTestArena: no rooms to inject into.")
		return
	var room: DungeonGenerator.Placement = layout.rooms[0]
	var center: Vector2i = DungeonGenerator.module_center(room.origin)

	# Party stands south of center, facing north toward the spawn point (markers face -Z).
	var fight := Marker3D.new()
	fight.name = "FightStart"
	fight.unique_name_in_owner = true
	fight.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(0.0)), Vector3(center.x, 0.0, center.y + 4.0))
	root.add_child(fight)

	var spawn := Marker3D.new()
	spawn.name = "EnemySpawn"
	spawn.unique_name_in_owner = true
	spawn.transform = Transform3D(Basis.IDENTITY, Vector3(center.x, 0.0, center.y - 2.0))
	root.add_child(spawn)

	# Terminal near spawn (one cell east of stairs spawn), so the player bumps into it first.
	var terminal: Node3D = (load(TERMINAL_SCENE) as PackedScene).instantiate() as Node3D
	terminal.name = "BattleConfigTerminal"
	var spawn_cell: Vector2i = layout.spawn_cell
	# Sit on the north side of the entry corridor / first walkable cell, facing south toward the party.
	terminal.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(180.0)).scaled(Vector3(1.5, 1.5, 1.5)),
		Vector3(float(spawn_cell.x + 2), 0.0, float(spawn_cell.y - 2)))
	terminal.set("object_id", "battle_test_arena_terminal")
	root.add_child(terminal)
	# NodePath exports must be set after the terminal is in the tree with its targets.
	terminal.set("fight_start", fight)
	terminal.set("enemy_spawn", spawn)

	# Soft arena light over the fight floor.
	var lights: Node = root.get_node_or_null("Lights")
	if lights != null:
		var glow := OmniLight3D.new()
		glow.name = "ArenaLight"
		glow.position = Vector3(center.x, 4.0, center.y)
		glow.light_color = Color(0.55, 0.75, 1.0)
		glow.light_energy = 1.8
		glow.omni_range = 14.0
		lights.add_child(glow)


func _run() -> void:
	var path: String = build()
	if path.is_empty():
		return
	EditorInterface.get_resource_filesystem().scan()
	if EditorInterface.get_open_scenes().has(path):
		EditorInterface.reload_scene_from_path(path)
	else:
		EditorInterface.open_scene_from_path(path)
	print("GenerateBattleTestArena: saved %s" % path)
