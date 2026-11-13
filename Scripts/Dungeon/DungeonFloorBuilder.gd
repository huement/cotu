# res://Scripts/Dungeon/DungeonFloorBuilder.gd
class_name DungeonFloorBuilder
extends RefCounted
## Builds one dungeon floor from a settings Dictionary and saves it as a .tscn.
## Same layout engine and look as GenerateDungeonLevel (DungeonGenerator), plus:
##   * chests with loot on open room cells,
##   * ghost haunts (invisible ghosts with a GhostAmbushComponent),
##   * per-enemy difficulty: pack size and stat_multiplier for every enemy type,
##   * an enemy boss (enemy.tscn + BossEnemy.gd, with minions) standing in the boss chamber.
## Driven by GenerateFeroShawDungeon.gd / GenerateVeroWoodDungeon.gd - see those for settings.

const LEVEL_SCRIPT: String = "res://Scripts/Dungeon/DungeonLevel.gd"
const INITIALIZER_SCRIPT: String = "res://Scripts/WorldSceneInitializerModule.gd"
const EDITOR_WORK_LIGHT_SCRIPT: String = "res://Scripts/Environment/EditorWorkLight.gd"
const NAV_BLOCKER_LIBRARY: String = "res://resources/mesh_library/nav_blocker_mesh_library.tres"
const CORRIDOR_DIR: String = "res://resources/tile_sets/dungeon"
const STAIRS_SCENE: String = "res://Scenes/Objects/Stairs.tscn"
const ENEMY_SCENE: String = "res://Scenes/Enemies/enemy.tscn"
const CHEST_SCENE: String = "res://Scenes/Objects/chest.tscn"
const CRYPT_SCENE: String = "res://Scenes/Environment/CryptHole.tscn"
const BOSS_ENEMY_SCRIPT: String = "res://Scripts/Enemies/BossEnemy.gd"
const GHOST_AMBUSH_SCRIPT: String = "res://Scripts/Enemies/GhostAmbushComponent.gd"
const BOSS_SCENE: String = "res://Scenes/Dungeons/Parts/BossChamber.tscn"
const LEVEL_TITLE_SCENE: String = "res://Scenes/UI/LevelTitleTrigger.tscn"
const DEFAULT_ROOM_SCENES: Array[String] = [
	"res://Scenes/Dungeons/Parts/SmallRoom.tscn",
	"res://Scenes/Dungeons/Parts/WideRoom.tscn",
	"res://Scenes/Dungeons/Parts/LargeRoom.tscn",
	"res://Scenes/Dungeons/Parts/CornerRoom.tscn",
]
## crypthole.glb is ~13 m wide: 0.17 fits one 2 m cell; the lift puts its base on the floor.
const CRYPT_SCALE: float = 0.17
const CRYPT_LIFT: float = 0.101
const CELL_SIZE: float = 2.0
## chest.tscn's model is authored at 4×. Half of that fits a 2 m cell.
const CHEST_SCALE: float = 0.5
## Generated dungeon floors sit at y = 0; enemy models need this to stand on them.
const ENEMY_VERTICAL_OFFSET: float = -1.0


## Builds and saves the floor. Returns the saved path, or "" on failure (errors are printed).
static func build_and_save(cfg: Dictionary) -> String:
	var level_name: String = str(cfg.get("name", ""))
	if level_name.is_empty():
		push_error("DungeonFloorBuilder: settings need a 'name'.")
		return ""
	var room_scenes: Array = cfg.get("room_scenes", DEFAULT_ROOM_SCENES)
	var room_weights: Array[int] = []
	for w: Variant in cfg.get("room_weights", [3, 2, 2, 2]):
		room_weights.append(int(w))
	if room_scenes.size() != room_weights.size():
		push_error("DungeonFloorBuilder: room_scenes and room_weights must be the same length.")
		return ""

	var templates: Array[DungeonGenerator.RoomTemplate] = []
	for path: Variant in room_scenes:
		var t: DungeonGenerator.RoomTemplate = DungeonGenerator.load_template(str(path), false)
		if t == null:
			return ""
		templates.append(t)
	var has_boss: bool = bool(cfg.get("has_boss", false))
	var boss_template: DungeonGenerator.RoomTemplate = null
	if has_boss:
		boss_template = DungeonGenerator.load_template(str(cfg.get("boss_room_scene", BOSS_SCENE)), true)
		if boss_template == null:
			return ""

	var enemy_count: int = int(cfg.get("enemy_count", 6))
	var chest_count: int = (cfg.get("chests", []) as Array).size()
	var ghost_count: int = int(cfg.get("ghost_count", 2))
	var spots_wanted: int = enemy_count + chest_count + ghost_count
	var layout: DungeonGenerator.Layout = DungeonGenerator.generate(int(cfg.get("seed", 1)), int(cfg.get("room_count", 6)),
		templates, room_weights, boss_template, spots_wanted)
	if layout == null:
		return ""
	if layout.enemies.size() < spots_wanted:
		push_warning("DungeonFloorBuilder: %s only had room for %d of %d enemies/chests/ghosts - add rooms or try another seed." % [
			level_name, layout.enemies.size(), spots_wanted])

	var root: Node3D = _build(cfg, layout)
	var inject: Variant = cfg.get("inject", null)
	if inject is Callable:
		(inject as Callable).call(root, layout)
	_set_owner_recursive(root, root)
	for extra: Node in root.get_meta("extra_owned", []) as Array:
		extra.owner = root
	root.remove_meta("extra_owned")

	var save_dir: String = str(cfg.get("save_dir", "res://Scenes/Dungeons"))
	DirAccess.make_dir_recursive_absolute(save_dir)
	var save_path: String = save_dir.path_join(level_name + ".tscn")
	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(root)
	root.free()
	if pack_err != OK:
		push_error("DungeonFloorBuilder: failed to pack %s (error %d)." % [level_name, pack_err])
		return ""
	var save_err: Error = ResourceSaver.save(packed, save_path)
	if save_err != OK:
		push_error("DungeonFloorBuilder: failed to save %s (error %d)." % [save_path, save_err])
		return ""
	print("DungeonFloorBuilder: saved %s (seed %d, %d rooms%s, %d corridor tiles, %d reachable cells)." % [
		save_path, layout.seed_used, layout.rooms.size() - (1 if has_boss else 0), " + boss" if has_boss else "",
		layout.corridors.size(), layout.reachable.size()])
	return save_path


static func _build(cfg: Dictionary, layout: DungeonGenerator.Layout) -> Node3D:
	var level_name: String = str(cfg["name"])
	var extra_owned: Array[Node] = []
	var root := Node3D.new()
	root.name = level_name
	root.set_script(load(LEVEL_SCRIPT))
	root.set("map_type", "dungeon")
	root.set("bgm_track_name", str(cfg.get("bgm", "Environment/dungeon-creepy")))
	root.set("level_seed", layout.seed_used)
	root.set("room_count", int(cfg.get("room_count", 6)))
	root.set("enemy_count", int(cfg.get("enemy_count", 6)))

	# Environment: same dark look as the other dungeons; fog starts a bit further out (more open).
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
	env.fog_depth_begin = float(cfg.get("fog_begin", 10.0))
	env.fog_depth_end = float(cfg.get("fog_end", 36.0))
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

	# Arrival banner text (without it the banner shows the scene's node name).
	if not str(cfg.get("title", "")).is_empty():
		var title: Node3D = (load(LEVEL_TITLE_SCENE) as PackedScene).instantiate() as Node3D
		title.name = "LevelTitle"
		title.position = spawn.position
		title.set("level_title", str(cfg["title"]))
		title.set("play_new_area_sound", true)
		root.add_child(title)

	var floor_map := GridMap.new()
	floor_map.name = "FloorMap"
	floor_map.unique_name_in_owner = true
	floor_map.cell_size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)
	floor_map.cell_center_y = false
	root.add_child(floor_map)

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
	var boss_node: Node3D = null
	var boss_room: DungeonGenerator.Placement = null
	for room: DungeonGenerator.Placement in layout.rooms:
		var node: Node3D = room.template.scene.instantiate() as Node3D
		if room.template.is_boss:
			node.name = "BossChamber"
			node.set("boss_id", int(cfg.get("boss_id", 0)))
			boss_node = node
			boss_room = room
		else:
			node.name = "Room%d_%s" % [room.index + 1, room.template.scene_path.get_file().get_basename()]
		node.transform = _xform(DungeonGenerator.module_center(room.origin), room.deg, 0.0)
		node.set("open_doors", room.used)
		node.set("removed_nodes", room.removed)
		node.set("id_prefix", (level_name + "_" + String(node.name)).to_lower())
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
			push_error("DungeonFloorBuilder: no corridor piece for openings '%s'." % layout.corridors[m])
			continue
		if not corridor_scenes.has(piece.x):
			corridor_scenes[piece.x] = load(CORRIDOR_DIR.path_join(DungeonGenerator.PIECE_FILES[piece.x] + ".glb")) as PackedScene
		var tile: Node3D = corridor_scenes[piece.x].instantiate() as Node3D
		tile.name = "Corridor%d" % (corridors.get_child_count() + 1)
		tile.transform = _xform(DungeonGenerator.module_center(m), piece.y, 0.0)
		corridors.add_child(tile)

	# Entrance stairs in the dead end lead back up.
	var stairs: Node3D = (load(STAIRS_SCENE) as PackedScene).instantiate() as Node3D
	stairs.name = "EntryStairs"
	stairs.transform = _xform(layout.stairs_cell, 90, 0.0)
	stairs.set("object_id", level_name.to_lower() + "_entry_stairs")
	stairs.set("snap_to_floor_center", false)
	stairs.set("prompt_message", str(cfg.get("entry_prompt", "Climb the stairs back up?")))
	stairs.set("target_scene", str(cfg.get("previous_scene", "")))
	stairs.set("use_map_manager", true)
	stairs.set("arrival_point_name", str(cfg.get("previous_arrival", "SpawnPoint")))
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
		_build_exit(cfg, root, lights, layout)

	if boss_room != null:
		var boss_spawn := Marker3D.new()
		boss_spawn.name = "BossSpawn"
		boss_spawn.transform = _xform(DungeonGenerator.module_center(boss_room.origin), boss_room.deg, 0.0)
		root.add_child(boss_spawn)
		var boss_cfg: Dictionary = cfg.get("boss_enemy", {})
		if not boss_cfg.is_empty():
			extra_owned.append(_build_boss_enemy(boss_cfg, boss_node, boss_room))

	# Open room cells from the layout engine: chests first, then ghosts, then enemies.
	var spots: Array[Vector2i] = layout.enemies.duplicate()
	var chest_cfgs: Array = cfg.get("chests", [])
	var ghost_count: int = int(cfg.get("ghost_count", 0))
	var next_spot: int = 0

	var chests := Node3D.new()
	chests.name = "Chests"
	root.add_child(chests)
	var chest_scene: PackedScene = load(CHEST_SCENE) as PackedScene
	for i: int in range(chest_cfgs.size()):
		if next_spot >= spots.size():
			break
		chests.add_child(_build_chest(chest_scene, chest_cfgs[i] as Dictionary, spots[next_spot], i, level_name))
		next_spot += 1

	var enemy_scene: PackedScene = load(ENEMY_SCENE) as PackedScene
	var ghosts := Node3D.new()
	ghosts.name = "Ghosts"
	root.add_child(ghosts)
	var ghost_cfg: Dictionary = cfg.get("ghost", {})
	for i: int in range(ghost_count):
		if next_spot >= spots.size():
			break
		var ghost: Node3D = _build_ghost(enemy_scene, ghost_cfg, spots[next_spot], i)
		ghosts.add_child(ghost)
		extra_owned.append(ghost.get_node("GhostAmbushComponent")) # child of an instance: own it explicitly
		next_spot += 1

	var enemies := Node3D.new()
	enemies.name = "Enemies"
	root.add_child(enemies)
	var enemy_types: Array = cfg.get("enemies", [])
	var enemy_count: int = int(cfg.get("enemy_count", 6))
	for i: int in range(enemy_count):
		if next_spot >= spots.size() or enemy_types.is_empty():
			break
		var spec: Dictionary = enemy_types[i % enemy_types.size()] as Dictionary
		var enemy: Node3D = enemy_scene.instantiate() as Node3D
		enemy.name = "Enemy%d" % (i + 1)
		enemy.position = Vector3(spots[next_spot].x, 0.0, spots[next_spot].y)
		enemy.set("data", load(str(spec["data"])))
		enemy.set("pack_size", int(spec.get("pack", 1)))
		enemy.set("stat_multiplier", float(spec.get("multiplier", 1.0)))
		enemy.set("model_scale", Vector3.ONE)
		enemy.set("vertical_offset", ENEMY_VERTICAL_OFFSET)
		enemy.set("enemy_type", str(spec.get("type", ""))) # empty = use the data's own type
		enemies.add_child(enemy)
		next_spot += 1

	root.set_meta("extra_owned", extra_owned)
	return root


## enemy.tscn with the BossEnemy script, standing in the middle of the chamber facing its door.
static func _build_boss_enemy(boss_cfg: Dictionary, chamber: Node3D, room: DungeonGenerator.Placement) -> Node3D:
	var boss: Node3D = (load(ENEMY_SCENE) as PackedScene).instantiate() as Node3D
	boss.set_script(load(BOSS_ENEMY_SCRIPT))
	boss.name = "Boss"
	boss.position = Vector3.ZERO # chamber centre (BossChamber.boss_spawn_position)
	boss.set("data", load(str(boss_cfg["data"])))
	if boss_cfg.has("minion_data"):
		boss.set("minion_data", load(str(boss_cfg["minion_data"])))
	boss.set("minion_count", int(boss_cfg.get("minion_count", 2)))
	boss.set("model_scale_multiplier", float(boss_cfg.get("model_scale_multiplier", 1.5)))
	boss.set("stat_multiplier", float(boss_cfg.get("multiplier", 1.0)))
	boss.set("model_scale", Vector3.ONE)
	boss.set("vertical_offset", ENEMY_VERTICAL_OFFSET)
	boss.set("enemy_type", str(boss_cfg.get("type", "")))
	# The chamber's only doorway is its local south (+Z): face that way in world space.
	var door_dir: Vector2i = DungeonGenerator.rot(Vector2i(0, 1), room.deg)
	boss.set("default_facing", _facing_index(door_dir))
	chamber.add_child(boss)
	return boss


static func _build_chest(scene: PackedScene, chest_cfg: Dictionary, cell: Vector2i, index: int, level_name: String) -> Node3D:
	var chest: Node3D = scene.instantiate() as Node3D
	chest.name = "Chest%d" % (index + 1)
	var placed: Transform3D = _xform(cell, [0, 90, 180, 270][index % 4], 0.0)
	placed.basis = placed.basis.scaled(Vector3.ONE * CHEST_SCALE)
	chest.transform = placed
	chest.set("object_id", "%s_chest_%d" % [level_name.to_lower(), index + 1])
	chest.set("gold_amount", int(chest_cfg.get("gold", 0)))
	var items: Array[ItemData] = []
	for path: Variant in chest_cfg.get("items", []):
		var item: ItemData = load(str(path)) as ItemData
		if item == null:
			push_warning("DungeonFloorBuilder: chest item not found: %s" % path)
			continue
		items.append(item)
	chest.set("guaranteed_items", items)
	return chest


static func _build_ghost(scene: PackedScene, ghost_cfg: Dictionary, cell: Vector2i, index: int) -> Node3D:
	var ghost: Node3D = scene.instantiate() as Node3D
	ghost.name = "Ghost%d" % (index + 1)
	ghost.position = Vector3(cell.x, 0.0, cell.y)
	ghost.set("data", load(str(ghost_cfg.get("data", "res://Data/Enemies/EnGhost.tres"))))
	ghost.set("pack_size", 1)
	ghost.set("stat_multiplier", float(ghost_cfg.get("multiplier", 1.0)))
	ghost.set("model_scale", Vector3.ONE)
	ghost.set("vertical_offset", ENEMY_VERTICAL_OFFSET)
	ghost.set("enemy_type", "ghost")
	var ambush := Node.new()
	ambush.name = "GhostAmbushComponent"
	ambush.set_script(load(GHOST_AMBUSH_SCRIPT))
	ambush.set("ghost_level", int(ghost_cfg.get("level", 1)))
	ambush.set("haunt_radius_tiles", int(ghost_cfg.get("haunt_radius", 3)))
	ghost.add_child(ambush)
	return ghost


## Crypt hole in the dead end + ExitArrival one cell back, facing up the corridor.
static func _build_exit(cfg: Dictionary, root: Node3D, lights: Node3D, layout: DungeonGenerator.Layout) -> void:
	var level_name: String = str(cfg["name"])
	var hole_cell: Vector2i = DungeonGenerator.module_center(layout.exit_module)
	var arrival_cell: Vector2i = hole_cell - layout.exit_dir * 2
	var exit_node: Node3D = (load(CRYPT_SCENE) as PackedScene).instantiate() as Node3D
	exit_node.name = "Exit"
	exit_node.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * CRYPT_SCALE), Vector3(hole_cell.x, CRYPT_LIFT, hole_cell.y))
	exit_node.set("object_id", level_name.to_lower() + "_crypthole")
	exit_node.set("snap_to_floor_center", false)
	exit_node.set("prompt_text", str(cfg.get("exit_prompt", "Climb down to the floor below?")))
	exit_node.set("target_dungeon_scene", str(cfg.get("next_scene", "")))
	exit_node.set("arrival_point_name", str(cfg.get("next_arrival", "SpawnPoint")))
	root.add_child(exit_node)

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


## WorldEnemy.Facing index (NORTH 0, EAST 1, SOUTH 2, WEST 3) for a grid direction.
static func _facing_index(dir: Vector2i) -> int:
	if absi(dir.x) > absi(dir.y):
		return 1 if dir.x > 0 else 3
	return 2 if dir.y > 0 else 0


static func _xform(cell: Vector2i, angle_degrees: int, height: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(angle_degrees))), Vector3(cell.x, height, cell.y))


## Owns every node except the insides of instanced sub-scenes (rooms, corridors, stairs, enemies).
static func _set_owner_recursive(node: Node, root_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root_node
		if child.scene_file_path.is_empty():
			_set_owner_recursive(child, root_node)
