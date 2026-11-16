# res://Scripts/Utilities/GenerateDungeonLevel.gd
@tool
extends EditorScript
## Builds a complete, playable dungeon level from the room parts in Scenes/Dungeons/Parts and
## saves it as SAVE_DIR/LEVEL_NAME.tscn: entrance stairs (lead back up), rooms joined by corridors
## (rooms rotated to fit, unused doorways closed by their gates, dressing randomly removed), the
## boss chamber at the far end, invisible corridor-wall blockers, enemies and a dark environment.
## Layout logic lives in Scripts/Dungeon/DungeonGenerator.gd.
##
## Use: edit the CONFIGURATION block -> open this script -> File -> Run (Ctrl/Cmd+Shift+X).
## Re-running with the same LEVEL_NAME overwrites that file (an open copy is reloaded).
## Change LEVEL_SEED for a different dungeon with the same settings.

# --- CONFIGURATION (edit before File -> Run) ----------------------------------
const LEVEL_NAME: String = "DungeonLevel2"
const SAVE_DIR: String = "res://Scenes/Dungeons"
const LEVEL_SEED: int = 3
const ROOM_COUNT: int = 6 # rooms before the boss chamber
const ENEMY_COUNT: int = 6 # never in the boss chamber, at most 2 per room
const ENEMY_DATA: Array[String] = [
	"res://Data/Enemies/EnZombieGuard.tres",
	"res://Data/Enemies/EnZombieKnight.tres",
	"res://Data/Enemies/EnZombieSaber.tres",
]

## Room parts and how often each is picked (same order).
const ROOM_SCENES: Array[String] = [
	"res://Scenes/Dungeons/Parts/SmallRoom.tscn",
	"res://Scenes/Dungeons/Parts/WideRoom.tscn",
	"res://Scenes/Dungeons/Parts/LargeRoom.tscn",
	"res://Scenes/Dungeons/Parts/CornerRoom.tscn",
]
const ROOM_WEIGHTS: Array[int] = [3, 2, 2, 2]
const BOSS_SCENE: String = "res://Scenes/Dungeons/Parts/BossChamber.tscn"
## Row of Data/Lore/Bosses.csv for this level's boss (boss, reward side, chest loot, north exit).
const BOSS_ID: int = 2

## true = bottom floor (boss chamber). false = upper floor: it ends in a crypt hole leading down
## to NEXT_SCENE, with an "ExitArrival" marker beside it for the party coming back up.
const HAS_BOSS: bool = true
const NEXT_SCENE: String = ""
const NEXT_ARRIVAL: String = "SpawnPoint"
const EXIT_PROMPT: String = "A dark shaft drops away beneath a loose slab. Climb down to the floor below?"

## Entrance stairs lead back UP to this map, arriving on this marker.
const PREVIOUS_SCENE: String = "res://Scenes/GloomReach.tscn"
const PREVIOUS_ARRIVAL: String = "DungeonExitArrival"
const ENTRY_PROMPT: String = "Climb the stairs back up to Gloom Reach?"
# ------------------------------------------------------------------------------

const LEVEL_SCRIPT: String = "res://Scripts/Dungeon/DungeonLevel.gd"
const INITIALIZER_SCRIPT: String = "res://Scripts/WorldSceneInitializerModule.gd"
const EDITOR_WORK_LIGHT_SCRIPT: String = "res://Scripts/Environment/EditorWorkLight.gd"
const NAV_BLOCKER_LIBRARY: String = "res://resources/mesh_library/nav_blocker_mesh_library.tres"
const CORRIDOR_DIR: String = "res://resources/tile_sets/dungeon"
const STAIRS_SCENE: String = "res://Scenes/Objects/Stairs.tscn"
const ENEMY_SCENE: String = "res://Scenes/Enemies/enemy.tscn"
const CRYPT_SCENE: String = "res://Scenes/Environment/CryptHole.tscn"
## crypthole.glb is ~13 m wide: 0.17 fits one 2 m cell; the lift puts its base on the floor.
const CRYPT_SCALE: float = 0.17
const CRYPT_LIFT: float = 0.101

const CELL_SIZE: float = 2.0


func _run() -> void:
	if ROOM_SCENES.size() != ROOM_WEIGHTS.size():
		push_error("GenerateDungeonLevel: ROOM_SCENES and ROOM_WEIGHTS must be the same length.")
		return
	var templates: Array[DungeonGenerator.RoomTemplate] = []
	for path: String in ROOM_SCENES:
		var t: DungeonGenerator.RoomTemplate = DungeonGenerator.load_template(path, false)
		if t == null:
			return
		templates.append(t)
	var boss: DungeonGenerator.RoomTemplate = null
	if HAS_BOSS:
		boss = DungeonGenerator.load_template(BOSS_SCENE, true)
		if boss == null:
			return

	var layout: DungeonGenerator.Layout = DungeonGenerator.generate(LEVEL_SEED, ROOM_COUNT, templates, ROOM_WEIGHTS, boss, ENEMY_COUNT)
	if layout == null:
		return
	for room: DungeonGenerator.Placement in layout.rooms:
		if not _room_reachable(layout, room):
			push_warning("GenerateDungeonLevel: %s can't be reached from the entrance - try another LEVEL_SEED." % room.template.scene_path.get_file())

	var root: Node3D = _build_level(layout)
	_set_owner_recursive(root, root)

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var save_path: String = SAVE_DIR.path_join(LEVEL_NAME + ".tscn")
	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(root)
	root.free()
	if pack_err != OK:
		push_error("GenerateDungeonLevel: failed to pack the scene (error %d)." % pack_err)
		return
	var save_err: Error = ResourceSaver.save(packed, save_path)
	if save_err != OK:
		push_error("GenerateDungeonLevel: failed to save %s (error %d)." % [save_path, save_err])
		return

	EditorInterface.get_resource_filesystem().scan()
	if EditorInterface.get_open_scenes().has(save_path):
		EditorInterface.reload_scene_from_path(save_path)
	else:
		EditorInterface.open_scene_from_path(save_path)
	print("GenerateDungeonLevel: saved %s (seed %d, %d rooms + boss, %d corridor tiles, %d enemies, %d reachable cells)." % [
		save_path, layout.seed_used, layout.rooms.size() - 1, layout.corridors.size(), layout.enemies.size(), layout.reachable.size()])


func _build_level(layout: DungeonGenerator.Layout) -> Node3D:
	var root := Node3D.new()
	root.name = LEVEL_NAME
	root.set_script(load(LEVEL_SCRIPT))
	root.set("map_type", "dungeon")
	root.set("bgm_track_name", "Environment/dungeon-creepy")
	root.set("level_seed", layout.seed_used)
	root.set("room_count", ROOM_COUNT)
	root.set("enemy_count", ENEMY_COUNT)

	# Environment: near-black background, cool low ambient, depth fog into darkness.
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.26, 0.27, 0.34)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.012, 0.012, 0.018)
	env.fog_density = 1.0
	env.fog_depth_begin = 8.0
	env.fog_depth_end = 30.0
	world_env.environment = env
	root.add_child(world_env)

	var work_light := Node3D.new()
	work_light.name = "EditorWorkLight"
	work_light.set_script(load(EDITOR_WORK_LIGHT_SCRIPT))
	root.add_child(work_light)

	var initializer := Node3D.new()
	initializer.name = "WorldSceneInitializer"
	initializer.set_script(load(INITIALIZER_SCRIPT))
	initializer.set("create_floor", false)
	initializer.set("create_ceiling", false)
	initializer.set("setup_dark_retro_environment", false)
	initializer.set("attach_torch_to_player", true)
	initializer.set("particle_color", Color(0.85, 0.85, 1.0, 0.3))
	root.add_child(initializer)

	# The party starts one cell east of the stairs, facing east (markers face -Z: rotation 270).
	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.unique_name_in_owner = true
	spawn.transform = _xform(layout.spawn_cell, 270, 0.0)
	spawn.set_meta("eye_height", 1.5)
	spawn.set_meta("battle_vertical_offset", -0.5)
	root.add_child(spawn)

	# FloorMap: the 2 m movement grid (rooms and corridors bring their own floors).
	var floor_map := GridMap.new()
	floor_map.name = "FloorMap"
	floor_map.unique_name_in_owner = true
	floor_map.cell_size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)
	floor_map.cell_center_y = false
	root.add_child(floor_map)

	# WallMap: invisible blockers on corridor walls (cell centre 2i + 1 -> index i).
	var wall_map := GridMap.new()
	wall_map.name = "WallMap"
	wall_map.unique_name_in_owner = true
	wall_map.visible = false
	wall_map.mesh_library = load(NAV_BLOCKER_LIBRARY) as MeshLibrary
	wall_map.cell_size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)
	wall_map.cell_center_y = false
	for c: Vector2i in layout.blocked_cells:
		wall_map.set_cell_item(Vector3i(floori((c.x - 1) / 2.0), 0, floori((c.y - 1) / 2.0)), 0)
	root.add_child(wall_map)

	var rooms := Node3D.new()
	rooms.name = "Rooms"
	root.add_child(rooms)
	var boss_room: DungeonGenerator.Placement = null
	for room: DungeonGenerator.Placement in layout.rooms:
		var node: Node3D = room.template.scene.instantiate() as Node3D
		if room.template.is_boss:
			node.name = "BossChamber"
			node.set("boss_id", BOSS_ID)
			boss_room = room
		else:
			node.name = "Room%d_%s" % [room.index + 1, room.template.scene_path.get_file().get_basename()]
		node.transform = _xform(DungeonGenerator.module_center(room.origin), room.deg, 0.0)
		node.set("open_doors", room.used)
		node.set("removed_nodes", room.removed)
		node.set("id_prefix", (LEVEL_NAME + "_" + String(node.name)).to_lower())
		rooms.add_child(node)

	var corridors := Node3D.new()
	corridors.name = "Corridors"
	root.add_child(corridors)
	var corridor_scenes: Dictionary[int, PackedScene] = {}
	var keys: Array[Vector2i] = []
	for m: Vector2i in layout.corridors:
		keys.append(m)
	keys.sort()
	for m: Vector2i in keys:
		var piece: Vector2i = DungeonGenerator.piece_for(layout.corridors[m])
		if piece.x < 0:
			push_error("GenerateDungeonLevel: no corridor piece for openings '%s'." % layout.corridors[m])
			continue
		if not corridor_scenes.has(piece.x):
			corridor_scenes[piece.x] = load(CORRIDOR_DIR.path_join(DungeonGenerator.PIECE_FILES[piece.x] + ".glb")) as PackedScene
		var tile: Node3D = corridor_scenes[piece.x].instantiate() as Node3D
		tile.name = "Corridor%d" % (corridors.get_child_count() + 1)
		tile.transform = _xform(DungeonGenerator.module_center(m), piece.y, 0.0)
		corridors.add_child(tile)

	# Entrance stairs in the dead end: the model's low end (+Z) faces east (rotation 90).
	var stairs: Node3D = (load(STAIRS_SCENE) as PackedScene).instantiate() as Node3D
	stairs.name = "EntryStairs"
	stairs.transform = _xform(layout.stairs_cell, 90, 0.0)
	stairs.set("object_id", LEVEL_NAME.to_lower() + "_entry_stairs")
	stairs.set("snap_to_floor_center", false)
	stairs.set("prompt_message", ENTRY_PROMPT)
	stairs.set("target_scene", PREVIOUS_SCENE)
	stairs.set("use_map_manager", true)
	stairs.set("arrival_point_name", PREVIOUS_ARRIVAL)
	root.add_child(stairs)

	var lights := Node3D.new()
	lights.name = "Lights"
	root.add_child(lights)
	var entry_light := OmniLight3D.new()
	entry_light.name = "EntryLight"
	entry_light.position = Vector3(layout.stairs_cell.x, 3.2, layout.stairs_cell.y)
	entry_light.light_color = Color(1.0, 0.8, 0.55)
	entry_light.light_energy = 1.4
	entry_light.omni_range = 8.0
	lights.add_child(entry_light)

	if layout.has_exit:
		_build_exit(root, lights, layout)

	if boss_room != null:
		var boss_spawn := Marker3D.new()
		boss_spawn.name = "BossSpawn"
		boss_spawn.transform = _xform(DungeonGenerator.module_center(boss_room.origin), boss_room.deg, 0.0)
		root.add_child(boss_spawn)

	var enemies := Node3D.new()
	enemies.name = "Enemies"
	root.add_child(enemies)
	var enemy_scene: PackedScene = load(ENEMY_SCENE) as PackedScene
	for i: int in range(layout.enemies.size()):
		var enemy: Node3D = enemy_scene.instantiate() as Node3D
		enemy.name = "Enemy%d" % (i + 1)
		enemy.position = Vector3(layout.enemies[i].x, 0.0, layout.enemies[i].y)
		if not ENEMY_DATA.is_empty():
			enemy.set("data", load(ENEMY_DATA[i % ENEMY_DATA.size()]))
		enemy.set("model_scale", Vector3.ONE)
		enemy.set("vertical_offset", -1.0)
		enemy.set("enemy_type", "zombie")
		enemies.add_child(enemy)

	return root


## Crypt hole in the dead end + ExitArrival one cell back, facing up the corridor.
func _build_exit(root: Node3D, lights: Node3D, layout: DungeonGenerator.Layout) -> void:
	var hole_cell: Vector2i = DungeonGenerator.module_center(layout.exit_module)
	var arrival_cell: Vector2i = hole_cell - layout.exit_dir * 2
	var exit_node: Node3D = (load(CRYPT_SCENE) as PackedScene).instantiate() as Node3D
	exit_node.name = "Exit"
	exit_node.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * CRYPT_SCALE), Vector3(hole_cell.x, CRYPT_LIFT, hole_cell.y))
	exit_node.set("object_id", LEVEL_NAME.to_lower() + "_crypthole")
	exit_node.set("snap_to_floor_center", false)
	exit_node.set("prompt_text", EXIT_PROMPT)
	exit_node.set("target_dungeon_scene", NEXT_SCENE)
	exit_node.set("arrival_point_name", NEXT_ARRIVAL)
	root.add_child(exit_node)
	if NEXT_SCENE.is_empty():
		push_warning("GenerateDungeonLevel: NEXT_SCENE is empty - set the Exit's target in the Inspector.")

	# Markers face -Z: Y rotation that points -Z back up the corridor (= -exit_dir).
	var face := Vector2(-layout.exit_dir.x, -layout.exit_dir.y)
	var arrival := Marker3D.new()
	arrival.name = "ExitArrival"
	arrival.transform = Transform3D(Basis(Vector3.UP, atan2(-face.x, -face.y)), Vector3(arrival_cell.x, 0.0, arrival_cell.y))
	root.add_child(arrival)

	var glow := OmniLight3D.new()
	glow.name = "ExitLight"
	glow.position = Vector3(hole_cell.x, 1.2, hole_cell.y)
	glow.light_color = Color(0.65, 0.35, 1.0)
	glow.light_energy = 1.6
	glow.omni_range = 6.0
	lights.add_child(glow)


func _room_reachable(layout: DungeonGenerator.Layout, room: DungeonGenerator.Placement) -> bool:
	for m: Vector2i in room.template.modules:
		var mc: Vector2i = DungeonGenerator.module_center(room.origin + DungeonGenerator.rot(m, room.deg))
		for dx: int in [-2, 0, 2]:
			for dz: int in [-2, 0, 2]:
				if layout.reachable.has(mc + Vector2i(dx, dz)):
					return true
	return false


## Y rotation + position on a world cell (x, z in metres).
func _xform(cell: Vector2i, angle_degrees: int, height: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(angle_degrees))), Vector3(cell.x, height, cell.y))


## Owns every node except the insides of instanced sub-scenes (rooms, corridors, stairs, enemies).
func _set_owner_recursive(node: Node, root_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root_node
		if child.scene_file_path.is_empty():
			_set_owner_recursive(child, root_node)
