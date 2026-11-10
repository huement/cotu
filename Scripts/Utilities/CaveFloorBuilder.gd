# res://Scripts/Utilities/CaveFloorBuilder.gd
class_name CaveFloorBuilder
extends RefCounted
## Builds one cave level from a settings Dictionary and saves it as a .tscn - the same scene
## GenerateCaveLevel makes (CaveGenerator layout, auto walls, crystals, stairs / crypt hole,
## arrival markers, dark environment), plus:
##   * chests with loot (only on cells whose 8 neighbours are open, so they never block a path),
##   * a mix of enemy types, each with its own pack-size range and stat_multiplier,
##   * an optional level title banner.
## Driven by e.g. Scripts/Utilities/GenerateWindmillCaves.gd - see that file for the settings.

const CAVE_LEVEL_SCRIPT: String = "res://Scripts/Environment/CaveLevel.gd"
const INITIALIZER_SCRIPT: String = "res://Scripts/WorldSceneInitializerModule.gd"
const FLOOR_LIBRARY: String = "res://resources/mesh_library/cave_floor_mesh_library.tres"
const WALL_LIBRARY: String = "res://resources/mesh_library/cave_wall_mesh_library.tres"
const STAIRS_SCENE: String = "res://Scenes/Objects/Stairs.tscn"
const CRYPT_SCENE: String = "res://Scenes/Environment/CryptHole.tscn"
const ENEMY_SCENE: String = "res://Scenes/Enemies/enemy.tscn"
const CHEST_SCENE: String = "res://Scenes/Objects/chest.tscn"
const LEVEL_TITLE_SCENE: String = "res://Scenes/UI/LevelTitleTrigger.tscn"
const CELL_SIZE: float = 2.0
const CRYPT_SCALE: float = 0.17
const CRYPT_LIFT: float = 0.101


## Builds and saves the level. Returns the saved path, or "" on failure.
static func build_and_save(cfg: Dictionary) -> String:
	var level_name: String = str(cfg.get("name", ""))
	if level_name.is_empty():
		push_error("CaveFloorBuilder: settings need a 'name'.")
		return ""
	var exit_is_stairs: bool = bool(cfg.get("exit_is_stairs", false))
	var layout: CaveGenerator.CaveLayout = CaveGenerator.generate(int(cfg.get("seed", 1)), cfg.get("grid_size", Vector2i(28, 28)),
		int(cfg.get("room_count", 8)), int(cfg.get("enemy_count", 4)), exit_is_stairs, bool(cfg.get("start_at_west_end", false)))
	if layout == null:
		return ""
	var root: Node3D = _build(cfg, layout)
	_set_owner_recursive(root, root)
	var chest_count: int = int(root.get_meta("chest_count", 0))
	root.remove_meta("chest_count")

	var save_dir: String = str(cfg.get("save_dir", "res://Scenes/Caves"))
	DirAccess.make_dir_recursive_absolute(save_dir)
	var save_path: String = save_dir.path_join(level_name + ".tscn")
	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(root)
	root.free()
	if pack_err != OK:
		push_error("CaveFloorBuilder: failed to pack %s (error %d)." % [level_name, pack_err])
		return ""
	var save_err: Error = ResourceSaver.save(packed, save_path)
	if save_err != OK:
		push_error("CaveFloorBuilder: failed to save %s (error %d)." % [save_path, save_err])
		return ""
	var steps: int = CaveGenerator.bfs(layout.open_cells, layout.spawn_cell, layout.blocked).get(layout.arrival_cell, -1)
	print("CaveFloorBuilder: saved %s (%d floor cells, %d enemies, %d chests, exit %d steps from the entrance)." % [
		save_path, layout.floor_cells.size(), layout.enemies.size(), chest_count, steps])
	return save_path


static func _build(cfg: Dictionary, layout: CaveGenerator.CaveLayout) -> Node3D:
	var level_name: String = str(cfg["name"])
	var exit_is_stairs: bool = bool(cfg.get("exit_is_stairs", false))
	var root := Node3D.new()
	root.name = level_name
	root.set_script(load(CAVE_LEVEL_SCRIPT))
	root.set("map_type", "dungeon")
	root.set("bgm_track_name", str(cfg.get("bgm", "Environment/dungeon-creepy-quite")))
	root.set("level_seed", int(cfg.get("seed", 1)))
	root.set("grid_size", cfg.get("grid_size", Vector2i(28, 28)))
	root.set("room_count", int(cfg.get("room_count", 8)))
	root.set("enemy_count", int(cfg.get("enemy_count", 4)))

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.01, 0.014)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = cfg.get("ambient_color", Color(0.34, 0.27, 0.24))
	env.ambient_light_energy = float(cfg.get("ambient_energy", 0.9))
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.015, 0.012, 0.016)
	env.fog_density = 1.0
	env.fog_depth_begin = float(cfg.get("fog_begin", 6.0))
	env.fog_depth_end = float(cfg.get("fog_end", 24.0))
	world_env.environment = env
	root.add_child(world_env)

	var initializer := Node3D.new()
	initializer.name = "WorldSceneInitializer"
	initializer.set_script(load(INITIALIZER_SCRIPT))
	initializer.set("create_floor", false)
	initializer.set("create_ceiling", false)
	initializer.set("setup_dark_retro_environment", false)
	initializer.set("attach_torch_to_player", true)
	initializer.set("particle_color", Color(1.0, 0.88, 0.7, 0.35))
	root.add_child(initializer)

	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.unique_name_in_owner = true
	spawn.transform = _cell_transform(layout.spawn_cell, layout.spawn_angle + 180)
	spawn.set_meta("eye_height", 1.5)
	spawn.set_meta("battle_vertical_offset", -0.5)
	root.add_child(spawn)

	var title_text: String = str(cfg.get("title", ""))
	if not title_text.is_empty():
		var title: Node3D = _instance(LEVEL_TITLE_SCENE)
		title.name = "LevelTitle"
		title.position = spawn.position
		title.set("level_title", title_text)
		title.set("play_new_area_sound", true)
		root.add_child(title)

	var arrival := Marker3D.new()
	arrival.name = "ExitArrival"
	arrival.transform = _cell_transform(layout.arrival_cell, layout.arrival_angle + 180)
	root.add_child(arrival)

	root.add_child(_build_grid("FloorMap", FLOOR_LIBRARY, layout.floor_cells))
	root.add_child(_build_grid("WallMap", WALL_LIBRARY, layout.wall_cells))

	var entry: Node3D = _instance(STAIRS_SCENE)
	entry.name = "EntryStairs"
	entry.transform = _cell_transform(layout.stairs_cell, layout.stairs_angle)
	entry.set("object_id", level_name.to_snake_case() + "_entry_stairs")
	entry.set("snap_to_floor_center", false)
	entry.set("prompt_message", str(cfg.get("entry_prompt", "Climb back up?")))
	entry.set("target_scene", str(cfg.get("previous_scene", "")))
	entry.set("use_map_manager", true)
	entry.set("arrival_point_name", str(cfg.get("previous_arrival", "SpawnPoint")))
	root.add_child(entry)

	var next_scene: String = str(cfg.get("next_scene", ""))
	var exit_node: Node3D
	if exit_is_stairs:
		exit_node = _instance(STAIRS_SCENE)
		exit_node.transform = _cell_transform(layout.exit_cell, layout.exit_angle)
		exit_node.set("object_id", level_name.to_snake_case() + "_exit_stairs")
		exit_node.set("prompt_message", str(cfg.get("exit_prompt", "Climb the stairs?")))
		exit_node.set("target_scene", next_scene)
		exit_node.set("use_map_manager", true)
	else:
		exit_node = _instance(CRYPT_SCENE)
		exit_node.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * CRYPT_SCALE), _cell_center(layout.exit_cell, CRYPT_LIFT))
		exit_node.set("object_id", level_name.to_snake_case() + "_crypthole")
		exit_node.set("prompt_text", str(cfg.get("exit_prompt", "Climb down deeper?")))
		exit_node.set("target_dungeon_scene", next_scene)
	exit_node.name = "Exit"
	exit_node.set("snap_to_floor_center", false)
	exit_node.set("arrival_point_name", str(cfg.get("next_arrival", "SpawnPoint")))
	root.add_child(exit_node)
	if next_scene.is_empty():
		push_warning("CaveFloorBuilder: %s has no next_scene - set the Exit's target in the Inspector." % level_name)

	var lights := Node3D.new()
	lights.name = "Lights"
	root.add_child(lights)
	lights.add_child(_omni("EntryLight", _cell_center(layout.stairs_cell, 3.2), Color(1.0, 0.78, 0.5), 1.4, 7.0))
	if exit_is_stairs:
		lights.add_child(_omni("ExitLight", _cell_center(layout.exit_cell, 3.5), Color(1.0, 0.95, 0.8), 2.2, 9.0))
	else:
		lights.add_child(_omni("ExitLight", _cell_center(layout.exit_cell, 1.2), Color(0.65, 0.35, 1.0), 1.6, 6.0))
	for i: int in range(layout.crystals.size()):
		lights.add_child(_omni("CrystalLight%d" % (i + 1), _cell_center(layout.crystals[i], 1.3), Color(0.3, 1.0, 0.85), 1.3, 6.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 1)) + 5

	# Enemies: cycle through the "enemies" list; each entry has its own pack range + multiplier.
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	root.add_child(enemies)
	var specs: Array = cfg.get("enemies", [])
	for i: int in range(layout.enemies.size()):
		if specs.is_empty():
			break
		var spec: Dictionary = specs[i % specs.size()] as Dictionary
		var data: EnemyData = load(str(spec["data"])) as EnemyData
		var enemy: Node3D = _instance(ENEMY_SCENE)
		enemy.name = "Enemy%d" % (i + 1)
		enemy.position = _cell_center(layout.enemies[i], 0.0)
		enemy.set("data", data)
		var pack: Vector2i = spec.get("pack", Vector2i(1, 1))
		enemy.set("pack_size", rng.randi_range(pack.x, pack.y))
		enemy.set("stat_multiplier", float(spec.get("multiplier", 1.0)))
		enemy.set("model_scale", Vector3.ONE * float(spec.get("world_scale", 1.0)))
		enemy.set("vertical_offset", -1.0)
		enemy.set("enemy_type", data.enemy_type if data != null and not data.enemy_type.is_empty() else "zombie")
		enemies.add_child(enemy)

	# Chests: open "room" cells (all 8 neighbours walkable) away from the entrance and enemies.
	var chest_cfgs: Array = cfg.get("chests", [])
	var chest_cells: Array[Vector2i] = _pick_chest_cells(layout, chest_cfgs.size(), rng)
	var chests := Node3D.new()
	chests.name = "Chests"
	root.add_child(chests)
	var chest_scene: PackedScene = load(CHEST_SCENE) as PackedScene
	for i: int in range(chest_cells.size()):
		var chest_cfg: Dictionary = chest_cfgs[i] as Dictionary
		var chest: Node3D = chest_scene.instantiate() as Node3D
		chest.name = "Chest%d" % (i + 1)
		chest.transform = _cell_transform(chest_cells[i], [0, 90, 180, 270][rng.randi_range(0, 3)])
		chest.set("object_id", "%s_chest_%d" % [level_name.to_snake_case(), i + 1])
		chest.set("gold_amount", int(chest_cfg.get("gold", 0)))
		var items: Array[ItemData] = []
		for path: Variant in chest_cfg.get("items", []):
			var item: ItemData = load(str(path)) as ItemData
			if item == null:
				push_warning("CaveFloorBuilder: chest item not found: %s" % path)
				continue
			items.append(item)
		chest.set("guaranteed_items", items)
		chests.add_child(chest)
	if chest_cells.size() < chest_cfgs.size():
		push_warning("CaveFloorBuilder: %s only had room for %d of %d chests - try a bigger grid or another seed." % [
			level_name, chest_cells.size(), chest_cfgs.size()])
	root.set_meta("chest_count", chest_cells.size())
	return root


## Chest cells: room-like open cells (at least 5 of 8 neighbours open, so chests sit in rooms or
## against walls, not in 1-wide tunnels), away from the stairs / exit and spread out. Every chest is
## checked with a flood fill so it can never cut off any part of the cave.
static func _pick_chest_cells(layout: CaveGenerator.CaveLayout, count: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var picked: Array[Vector2i] = []
	if count <= 0:
		return picked
	var specials: Array[Vector2i] = [layout.spawn_cell, layout.stairs_cell, layout.exit_cell, layout.arrival_cell]
	var dist: Dictionary[Vector2i, int] = CaveGenerator.bfs(layout.open_cells, layout.spawn_cell, layout.blocked)
	var reachable_count: int = dist.size()
	var candidates: Array[Vector2i] = []
	var sorted_open: Array[Vector2i] = []
	sorted_open.assign(layout.open_cells.keys())
	sorted_open.sort()
	for c: Vector2i in sorted_open:
		if layout.blocked.has(c) or not dist.has(c) or dist[c] < 4 or layout.enemies.has(c):
			continue
		var near_special: bool = false
		for sp: Vector2i in specials:
			if absi(c.x - sp.x) + absi(c.y - sp.y) <= 2:
				near_special = true
		if near_special:
			continue
		var open_neighbours: int = 0
		for dz: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var n := Vector2i(c.x + dx, c.y + dz)
				if n != c and layout.open_cells.has(n) and not layout.blocked.has(n):
					open_neighbours += 1
		if open_neighbours >= 5:
			candidates.append(c)
	for i: int in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var blocked: Dictionary[Vector2i, bool] = layout.blocked.duplicate()
	for spacing: int in [6, 4]: # spread out first; squeeze a little if the cave is small
		for c: Vector2i in candidates:
			if picked.size() >= count:
				return picked
			if picked.has(c):
				continue
			var spaced: bool = true
			for other: Vector2i in picked:
				if absi(c.x - other.x) + absi(c.y - other.y) < spacing:
					spaced = false
					break
			for e: Vector2i in layout.enemies:
				if absi(c.x - e.x) + absi(c.y - e.y) < 3:
					spaced = false
					break
			if not spaced:
				continue
			# Everything reachable before must stay reachable with this chest in place.
			blocked[c] = true
			if CaveGenerator.bfs(layout.open_cells, layout.spawn_cell, blocked).size() < reachable_count - picked.size() - 1:
				blocked.erase(c)
				continue
			picked.append(c)
	return picked


static func _build_grid(grid_name: String, library_path: String, cells: Array[Vector4i]) -> GridMap:
	var grid := GridMap.new()
	grid.name = grid_name
	grid.unique_name_in_owner = true
	grid.mesh_library = load(library_path) as MeshLibrary
	grid.cell_size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)
	grid.cell_center_y = false
	for c: Vector4i in cells:
		grid.set_cell_item(Vector3i(c.x, 0, c.y), c.z, c.w)
	return grid


static func _instance(scene_path: String) -> Node3D:
	return (load(scene_path) as PackedScene).instantiate() as Node3D


static func _omni(light_name: String, pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	return light


static func _cell_center(cell: Vector2i, height: float) -> Vector3:
	return Vector3(cell.x * CELL_SIZE + CELL_SIZE * 0.5, height, cell.y * CELL_SIZE + CELL_SIZE * 0.5)


static func _cell_transform(cell: Vector2i, angle_degrees: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(angle_degrees))), _cell_center(cell, 0.0))


static func _set_owner_recursive(node: Node, root_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root_node
		if child.scene_file_path.is_empty():
			_set_owner_recursive(child, root_node)
