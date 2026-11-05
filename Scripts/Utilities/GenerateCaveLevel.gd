# res://Scripts/Utilities/GenerateCaveLevel.gd
@tool
extends EditorScript
## Builds a complete, playable cave level and saves it as SAVE_DIR/LEVEL_NAME.tscn:
## floors + auto-placed walls, entrance stairs (lead back up), an exit (crypt hole down,
## or stairs out), arrival markers, crystal rocks with glow lights, enemies and a dark
## cave environment. Layout logic lives in CaveGenerator.gd.
##
## Use: edit the CONFIGURATION block -> open this script -> File -> Run (Ctrl/Cmd+Shift+X).
## Re-running with the same LEVEL_NAME overwrites that file (an open copy is reloaded).
## Change LEVEL_SEED for a different cave with the same settings.

# --- CONFIGURATION (edit before File -> Run) ----------------------------------
const LEVEL_NAME: String = "CaveLevel4"
const SAVE_DIR: String = "res://Scenes/Caves"
const LEVEL_SEED: int = 4404
const GRID_SIZE: Vector2i = Vector2i(30, 30) # cells (2 m each); at least 12 x 12
const ROOM_COUNT: int = 8
const ENEMY_COUNT: int = 3
const ENEMY_DATA: Array[String] = [
	"res://Data/Enemies/EnZombieGuard.tres",
	"res://Data/Enemies/EnZombieKnight.tres",
]

## Entrance stairs lead back UP to this map, arriving on this marker.
const PREVIOUS_SCENE: String = "res://Scenes/Caves/CaveLevel3.tscn"
const PREVIOUS_ARRIVAL: String = "ExitArrival"
const ENTRY_PROMPT: String = "Climb back up to the caves above?"

## The exit leads to this map, arriving on this marker.
## false = crypt hole in the floor (go deeper), true = stairs in an alcove (way out).
const EXIT_IS_STAIRS: bool = false
const NEXT_SCENE: String = ""
const NEXT_ARRIVAL: String = "SpawnPoint"
const EXIT_PROMPT: String = "A cold draft rises from a shaft in the floor. Climb down deeper?"
# ------------------------------------------------------------------------------

const CAVE_LEVEL_SCRIPT: String = "res://Scripts/Environment/CaveLevel.gd"
const INITIALIZER_SCRIPT: String = "res://Scripts/WorldSceneInitializerModule.gd"
const FLOOR_LIBRARY: String = "res://resources/mesh_library/cave_floor_mesh_library.tres"
const WALL_LIBRARY: String = "res://resources/mesh_library/cave_wall_mesh_library.tres"
const STAIRS_SCENE: String = "res://Scenes/Objects/Stairs.tscn"
const CRYPT_SCENE: String = "res://Scenes/Environment/CryptHole.tscn"
const ENEMY_SCENE: String = "res://Scenes/Enemies/enemy.tscn"

const CELL_SIZE: float = 2.0
## crypthole.glb is ~13 m wide: 0.17 fits one 2 m cell; the lift puts its base on the floor.
const CRYPT_SCALE: float = 0.17
const CRYPT_LIFT: float = 0.101


func _run() -> void:
	var layout: CaveGenerator.CaveLayout = CaveGenerator.generate(LEVEL_SEED, GRID_SIZE, ROOM_COUNT, ENEMY_COUNT, EXIT_IS_STAIRS)
	if layout == null:
		return

	var root: Node3D = _build_level(layout)
	_set_owner_recursive(root, root)

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var save_path: String = SAVE_DIR.path_join(LEVEL_NAME + ".tscn")
	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(root)
	root.free()
	if pack_err != OK:
		push_error("GenerateCaveLevel: failed to pack the scene (error %d)." % pack_err)
		return
	var save_err: Error = ResourceSaver.save(packed, save_path)
	if save_err != OK:
		push_error("GenerateCaveLevel: failed to save %s (error %d)." % [save_path, save_err])
		return

	EditorInterface.get_resource_filesystem().scan()
	if EditorInterface.get_open_scenes().has(save_path):
		EditorInterface.reload_scene_from_path(save_path)
	else:
		EditorInterface.open_scene_from_path(save_path)
	print("GenerateCaveLevel: saved %s (%d floor, %d wall cells, %d enemies, exit %d steps from the entrance)." % [
		save_path, layout.floor_cells.size(), layout.wall_cells.size(), layout.enemies.size(),
		CaveGenerator.bfs(layout.open_cells, layout.spawn_cell, layout.blocked).get(layout.arrival_cell, -1)])


func _build_level(layout: CaveGenerator.CaveLayout) -> Node3D:
	var root := Node3D.new()
	root.name = LEVEL_NAME
	root.set_script(load(CAVE_LEVEL_SCRIPT))
	root.set("map_type", "dungeon")
	root.set("bgm_track_name", "Environment/dungeon-creepy-quite")
	root.set("level_seed", LEVEL_SEED)
	root.set("grid_size", GRID_SIZE)
	root.set("room_count", ROOM_COUNT)
	root.set("enemy_count", ENEMY_COUNT)

	# Environment: black sky, warm low ambient, depth fog into darkness.
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.01, 0.014)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.27, 0.24)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.015, 0.012, 0.016)
	env.fog_density = 1.0
	env.fog_depth_begin = 6.0
	env.fog_depth_end = 24.0
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

	# Markers face their -Z axis, so their Y rotation is the facing angle + 180.
	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.unique_name_in_owner = true
	spawn.transform = _cell_transform(layout.spawn_cell, layout.spawn_angle + 180)
	spawn.set_meta("eye_height", 1.5)
	spawn.set_meta("battle_vertical_offset", -0.5)
	root.add_child(spawn)

	var arrival := Marker3D.new()
	arrival.name = "ExitArrival"
	arrival.transform = _cell_transform(layout.arrival_cell, layout.arrival_angle + 180)
	root.add_child(arrival)

	root.add_child(_build_grid("FloorMap", FLOOR_LIBRARY, layout.floor_cells))
	root.add_child(_build_grid("WallMap", WALL_LIBRARY, layout.wall_cells))

	# Entrance stairs (model's low end faces +Z, so rotate by the angle into the room).
	var entry: Node3D = _instance(STAIRS_SCENE)
	entry.name = "EntryStairs"
	entry.transform = _cell_transform(layout.stairs_cell, layout.stairs_angle)
	entry.set("object_id", LEVEL_NAME.to_snake_case() + "_entry_stairs")
	entry.set("snap_to_floor_center", false)
	entry.set("prompt_message", ENTRY_PROMPT)
	entry.set("target_scene", PREVIOUS_SCENE)
	entry.set("use_map_manager", true)
	entry.set("arrival_point_name", PREVIOUS_ARRIVAL)
	root.add_child(entry)

	var exit_node: Node3D
	if EXIT_IS_STAIRS:
		exit_node = _instance(STAIRS_SCENE)
		exit_node.transform = _cell_transform(layout.exit_cell, layout.exit_angle)
		exit_node.set("object_id", LEVEL_NAME.to_snake_case() + "_exit_stairs")
		exit_node.set("prompt_message", EXIT_PROMPT)
		exit_node.set("target_scene", NEXT_SCENE)
		exit_node.set("use_map_manager", true)
	else:
		exit_node = _instance(CRYPT_SCENE)
		exit_node.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * CRYPT_SCALE), _cell_center(layout.exit_cell, CRYPT_LIFT))
		exit_node.set("object_id", LEVEL_NAME.to_snake_case() + "_crypthole")
		exit_node.set("prompt_text", EXIT_PROMPT)
		exit_node.set("target_dungeon_scene", NEXT_SCENE)
	exit_node.name = "Exit"
	exit_node.set("snap_to_floor_center", false)
	exit_node.set("arrival_point_name", NEXT_ARRIVAL)
	root.add_child(exit_node)
	if NEXT_SCENE.is_empty():
		push_warning("GenerateCaveLevel: NEXT_SCENE is empty - set the Exit's target in the Inspector.")

	# Lights: warm light down the entrance stairs, exit glow, teal glow on every crystal.
	var lights := Node3D.new()
	lights.name = "Lights"
	root.add_child(lights)
	lights.add_child(_omni("EntryLight", _cell_center(layout.stairs_cell, 3.2), Color(1.0, 0.78, 0.5), 1.4, 7.0))
	if EXIT_IS_STAIRS:
		lights.add_child(_omni("ExitLight", _cell_center(layout.exit_cell, 3.5), Color(1.0, 0.95, 0.8), 2.2, 9.0))
	else:
		lights.add_child(_omni("ExitLight", _cell_center(layout.exit_cell, 1.2), Color(0.65, 0.35, 1.0), 1.6, 6.0))
	for i: int in range(layout.crystals.size()):
		lights.add_child(_omni("CrystalLight%d" % (i + 1), _cell_center(layout.crystals[i], 1.3), Color(0.3, 1.0, 0.85), 1.3, 6.0))

	var enemies := Node3D.new()
	enemies.name = "Enemies"
	root.add_child(enemies)
	for i: int in range(layout.enemies.size()):
		var enemy: Node3D = _instance(ENEMY_SCENE)
		enemy.name = "Enemy%d" % (i + 1)
		enemy.position = _cell_center(layout.enemies[i], 0.0)
		if not ENEMY_DATA.is_empty():
			enemy.set("data", load(ENEMY_DATA[i % ENEMY_DATA.size()]))
		enemy.set("model_scale", Vector3.ONE)
		enemy.set("vertical_offset", -1.0)
		enemy.set("enemy_type", "zombie")
		enemies.add_child(enemy)

	return root


func _build_grid(grid_name: String, library_path: String, cells: Array[Vector4i]) -> GridMap:
	var grid := GridMap.new()
	grid.name = grid_name
	grid.unique_name_in_owner = true
	grid.mesh_library = load(library_path) as MeshLibrary
	grid.cell_size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)
	grid.cell_center_y = false
	for c: Vector4i in cells: # (x, z, item, orientation)
		grid.set_cell_item(Vector3i(c.x, 0, c.y), c.z, c.w)
	return grid


func _instance(scene_path: String) -> Node3D:
	var scene: PackedScene = load(scene_path) as PackedScene
	return scene.instantiate() as Node3D


func _omni(light_name: String, pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	return light


func _cell_center(cell: Vector2i, height: float) -> Vector3:
	return Vector3(cell.x * CELL_SIZE + CELL_SIZE * 0.5, height, cell.y * CELL_SIZE + CELL_SIZE * 0.5)


func _cell_transform(cell: Vector2i, angle_degrees: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(angle_degrees))), _cell_center(cell, 0.0))


## Owns every node except the insides of instanced sub-scenes (same as forest_level_generator).
func _set_owner_recursive(node: Node, root_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root_node
		if child.scene_file_path.is_empty():
			_set_owner_recursive(child, root_node)
