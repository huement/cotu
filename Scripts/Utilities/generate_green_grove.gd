# res://Scripts/Utilities/generate_green_grove.gd
# One-shot: godot --path . --headless -s Scripts/Utilities/generate_green_grove.gd
extends SceneTree

## Every outdoor map uses the pixel sky. Use pixel_sky_overcast.tres for gloomier maps.
const PIXEL_SKY_MATERIAL: String = "res://resources/Environment/pixel_sky.tres"

## Builds a compact starter forest clearing:
## - Grass floor courtyard
## - Tree walls on North / West / East
## - Open South side with a StoneGate exit to Stone Trail
## - Safe on first visit; ReturnVisitEnemySpawner adds 3 Slime Drones later

const SAVE_PATH: String = "res://Scenes/GreenGrove.tscn"
const FLOOR_GRASS_ID: int = 1
const WALL_TREE_ID: int = 0

## Inclusive cell bounds for the walkable courtyard.
const FLOOR_MIN_X: int = -6
const FLOOR_MAX_X: int = 6
const FLOOR_MIN_Z: int = -8
const FLOOR_MAX_Z: int = 4

## Gate opening width (cells) on the south tree line.
const GATE_HALF_WIDTH: int = 2


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := Node3D.new()
	root.name = "GreenGrove"

	_add_environment(root)
	_add_spawn(root)
	var floor_map: GridMap = _add_floor_map(root)
	var wall_map: GridMap = _add_wall_map(root, "WallMap", 2.0, "")
	var wall_map2: GridMap = _add_wall_map(root, "WallMap2", 2.0, "res://Scenes/Environment/forest_wall_chunk.tscn")
	var wall_map3: GridMap = _add_wall_map(root, "WallMap3", 1.6, "res://Scenes/Environment/forest_wall_chunk_thick.tscn")

	_paint_floor(floor_map)
	_paint_tree_border(wall_map)
	_paint_accent_trees(wall_map2, wall_map3)

	_add_props(root)
	_add_initializer(root)
	_add_mist(root)
	_add_day_night(root)
	_add_grass(root, floor_map)
	_add_stone_gate(root)
	_add_level_title(root)
	_add_return_spawner(root, floor_map, wall_map, wall_map2, wall_map3)

	_set_owner_recursive(root, root)

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("GreenGrove: failed to pack scene.")
		root.queue_free()
		quit(1)
		return

	var err: Error = ResourceSaver.save(packed, SAVE_PATH)
	root.queue_free()
	if err != OK:
		push_error("GreenGrove: failed to save %s (err %d)" % [SAVE_PATH, err])
		quit(1)
		return

	print("✅ GreenGrove written to ", SAVE_PATH)
	quit(0)


func _add_environment(root: Node3D) -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	# Pixel-art sky (clouds + night stars live in the shader; DayNightCycle drives it).
	sky.sky_material = load(PIXEL_SKY_MATERIAL) if ResourceLoader.exists(PIXEL_SKY_MATERIAL) else ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.62, 1.0, 0.85, 1.0)
	world_env.environment = env
	root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.transform = Transform3D(Basis.from_euler(Vector3(-0.8, -0.5, 0.0)), Vector3.ZERO)
	root.add_child(sun)


func _add_spawn(root: Node3D) -> void:
	# Near the south gate, facing north into the clearing.
	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.unique_name_in_owner = true
	spawn.position = Vector3(0.0, 0.0, float(FLOOR_MAX_Z - 1) * 2.0)
	spawn.set_meta("eye_height", 1.0)
	root.add_child(spawn)


func _add_floor_map(root: Node3D) -> GridMap:
	var floor_map := GridMap.new()
	floor_map.name = "FloorMap"
	floor_map.unique_name_in_owner = true
	floor_map.mesh_library = load("res://resources/mesh_library/knature_mesh_library.tres")
	floor_map.cell_scale = 2.0
	floor_map.cell_center_y = false
	root.add_child(floor_map)
	return floor_map


func _add_wall_map(root: Node3D, node_name: String, cell_scale: float, chunk_path: String) -> GridMap:
	var wall_map := GridMap.new()
	wall_map.name = node_name
	if node_name == "WallMap":
		wall_map.unique_name_in_owner = true
	wall_map.mesh_library = load("res://resources/mesh_library/forestwall_mesh_library.tres")
	wall_map.cell_scale = cell_scale
	wall_map.set_script(load("res://Scripts/Environment/forest_grid_map_replacer.gd"))
	if not chunk_path.is_empty() and ResourceLoader.exists(chunk_path):
		wall_map.set("forest_chunk_scene", load(chunk_path))
	root.add_child(wall_map)
	return wall_map


func _paint_floor(floor_map: GridMap) -> void:
	for x: int in range(FLOOR_MIN_X, FLOOR_MAX_X + 1):
		for z: int in range(FLOOR_MIN_Z, FLOOR_MAX_Z + 1):
			floor_map.set_cell_item(Vector3i(x, 0, z), FLOOR_GRASS_ID)


func _paint_tree_border(wall_map: GridMap) -> void:
	# North edge
	for x: int in range(FLOOR_MIN_X - 1, FLOOR_MAX_X + 2):
		wall_map.set_cell_item(Vector3i(x, 0, FLOOR_MIN_Z - 1), WALL_TREE_ID)
	# West + East edges (full depth)
	for z: int in range(FLOOR_MIN_Z - 1, FLOOR_MAX_Z + 2):
		wall_map.set_cell_item(Vector3i(FLOOR_MIN_X - 1, 0, z), WALL_TREE_ID)
		wall_map.set_cell_item(Vector3i(FLOOR_MAX_X + 1, 0, z), WALL_TREE_ID)
	# South edge with a centered gate gap
	for x: int in range(FLOOR_MIN_X - 1, FLOOR_MAX_X + 2):
		if absi(x) <= GATE_HALF_WIDTH:
			continue
		wall_map.set_cell_item(Vector3i(x, 0, FLOOR_MAX_Z + 1), WALL_TREE_ID)


func _paint_accent_trees(wall_map2: GridMap, wall_map3: GridMap) -> void:
	# Sparse inner accents so the border feels thicker without boxing the player in.
	var accents2: Array[Vector3i] = [
		Vector3i(FLOOR_MIN_X, 0, FLOOR_MIN_Z),
		Vector3i(FLOOR_MAX_X, 0, FLOOR_MIN_Z),
		Vector3i(FLOOR_MIN_X, 0, 0),
		Vector3i(FLOOR_MAX_X, 0, 0),
		Vector3i(-3, 0, FLOOR_MIN_Z),
		Vector3i(3, 0, FLOOR_MIN_Z),
	]
	for cell: Vector3i in accents2:
		wall_map2.set_cell_item(cell, WALL_TREE_ID)

	var accents3: Array[Vector3i] = [
		Vector3i(FLOOR_MIN_X - 1, 0, FLOOR_MIN_Z - 1),
		Vector3i(FLOOR_MAX_X + 1, 0, FLOOR_MIN_Z - 1),
		Vector3i(FLOOR_MIN_X - 1, 0, FLOOR_MAX_Z),
		Vector3i(FLOOR_MAX_X + 1, 0, FLOOR_MAX_Z),
	]
	for cell: Vector3i in accents3:
		wall_map3.set_cell_item(cell, WALL_TREE_ID)


func _add_props(root: Node3D) -> void:
	var wood_paths := Node3D.new()
	wood_paths.name = "WoodPaths"
	root.add_child(wood_paths)

	var big_timbers := Node3D.new()
	big_timbers.name = "BigTimbers"
	root.add_child(big_timbers)

	if ResourceLoader.exists("res://Scenes/Objects/BigTimber.tscn"):
		var timber_scene: PackedScene = load("res://Scenes/Objects/BigTimber.tscn")
		var placements: Array[Dictionary] = [
			{"pos": Vector3(-8.0, 0.0, -10.0), "yaw": 0.4, "scale": 1.6, "type": 1},
			{"pos": Vector3(8.5, 0.0, -9.0), "yaw": -0.7, "scale": 1.8, "type": 5},
			{"pos": Vector3(-7.5, 0.0, 2.0), "yaw": 1.1, "scale": 1.5, "type": 1},
			{"pos": Vector3(7.0, 0.0, 1.5), "yaw": 2.2, "scale": 1.7, "type": 7},
		]
		for i: int in range(placements.size()):
			var entry: Dictionary = placements[i]
			var timber: Node3D = timber_scene.instantiate() as Node3D
			timber.name = "BigTimber%d" % (i + 1)
			timber.position = entry["pos"] as Vector3
			var s: float = float(entry["scale"])
			timber.scale = Vector3(s, s, s)
			timber.rotation.y = float(entry["yaw"])
			if timber.has_method("set") and "tree_type" in timber:
				timber.set("tree_type", int(entry["type"]))
			big_timbers.add_child(timber)

	var shrooms := Node3D.new()
	shrooms.name = "Shrooms"
	root.add_child(shrooms)

	var enemies := Node3D.new()
	enemies.name = "Enemies"
	root.add_child(enemies)


func _add_initializer(root: Node3D) -> void:
	var initializer := Node3D.new()
	initializer.name = "WorldSceneInitializer"
	if ResourceLoader.exists("res://Scripts/WorldSceneInitializerModule.gd"):
		initializer.set_script(load("res://Scripts/WorldSceneInitializerModule.gd"))
		initializer.set("create_floor", false)
		initializer.set("create_ceiling", false)
		initializer.set("setup_dark_retro_environment", false)
		initializer.set("attach_torch_to_player", false)
		initializer.set("particle_color", Color(0.94, 1.01, 0.77, 0.4))
	root.add_child(initializer)


func _add_mist(root: Node3D) -> void:
	var ground_mist := CPUParticles3D.new()
	ground_mist.name = "GroundMist"
	ground_mist.unique_name_in_owner = true
	ground_mist.position = Vector3(0.0, 0.4, -4.0)
	ground_mist.amount = 40
	ground_mist.lifetime = 8.0
	ground_mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ground_mist.emission_box_extents = Vector3(18.0, 0.3, 18.0)
	ground_mist.gravity = Vector3(0.0, -0.02, 0.0)
	ground_mist.scale_amount_min = 0.8
	ground_mist.scale_amount_max = 1.6
	ground_mist.color = Color(0.7, 0.8, 0.75, 0.3)

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(6, 6)
	var mist_mat := StandardMaterial3D.new()
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_mat.vertex_color_use_as_albedo = true
	mist_mat.albedo_color = Color(0.45, 0.55, 0.5, 0.18)
	mist_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad_mesh.material = mist_mat
	ground_mist.mesh = quad_mesh
	root.add_child(ground_mist)


func _add_day_night(root: Node3D) -> void:
	var sun: DirectionalLight3D = root.get_node("SunLight") as DirectionalLight3D
	var world_env: WorldEnvironment = root.get_node("WorldEnvironment") as WorldEnvironment

	var day_light_cycle := Node3D.new()
	day_light_cycle.name = "DayLightCycle"
	if ResourceLoader.exists("res://Scripts/Environment/day_night_cycle.gd"):
		day_light_cycle.set_script(load("res://Scripts/Environment/day_night_cycle.gd"))

	var moon_light := DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.light_color = Color(0.665, 0.798, 1.0, 1.0)
	day_light_cycle.add_child(moon_light)

	if ResourceLoader.exists("res://resources/OutdoorParts/moon.glb"):
		var moon_mesh: Node3D = load("res://resources/OutdoorParts/moon.glb").instantiate() as Node3D
		moon_mesh.name = "moon"
		moon_mesh.position = Vector3(0, 0, -200)
		moon_mesh.rotation_degrees = Vector3(0, 180, 0)
		moon_light.add_child(moon_mesh)

	root.add_child(day_light_cycle)
	day_light_cycle.set("sun_light", sun)
	day_light_cycle.set("moon_light", moon_light)
	day_light_cycle.set("world_environment", world_env)
	if moon_light.has_node("moon"):
		day_light_cycle.set("moon_mesh_node", moon_light.get_node("moon"))
	day_light_cycle.set("moon_rotation_degrees", Vector3(0, 180, 0))


func _add_grass(root: Node3D, floor_map: GridMap) -> void:
	var grass_scatter := Node3D.new()
	grass_scatter.name = "GrassScatter"
	if ResourceLoader.exists("res://Scripts/Environment/grass_scatter.gd"):
		grass_scatter.set_script(load("res://Scripts/Environment/grass_scatter.gd"))
		grass_scatter.set("floor_map", floor_map)
		if ResourceLoader.exists("res://resources/meshes/grass_tuft.tres"):
			grass_scatter.set("grass_mesh", load("res://resources/meshes/grass_tuft.tres"))
		grass_scatter.set("valid_floor_item_ids", [1, 46])
		grass_scatter.set("tufts_per_tile", 3)
	root.add_child(grass_scatter)


func _add_stone_gate(root: Node3D) -> void:
	if not ResourceLoader.exists("res://Scenes/Environment/StoneGate.tscn"):
		return
	var gate: Node3D = load("res://Scenes/Environment/StoneGate.tscn").instantiate() as Node3D
	gate.name = "StoneGate"
	# Face south out of the grove. Scale matches other outdoor gates.
	gate.transform = Transform3D(
		Basis.from_euler(Vector3(0.0, PI, 0.0)).scaled(Vector3(2.0, 2.0, 2.0)),
		Vector3(0.0, 0.0, float(FLOOR_MAX_Z + 1) * 2.0)
	)
	if ResourceLoader.exists("res://Scripts/Environment/StoneGate.gd"):
		gate.set_script(load("res://Scripts/Environment/StoneGate.gd"))
		gate.set("target_dungeon_scene", "res://Scenes/FeroShaw.tscn")
		gate.set("arrival_point_name", "SpawnPoint")
		gate.set("prompt_text", "Leave Green Grove and enter the FEROSHAW crossroads?")
	root.add_child(gate)
	_add_nine_intro_trigger(root, gate.global_position)


func _add_nine_intro_trigger(root: Node3D, gate_pos: Vector3) -> void:
	if not ResourceLoader.exists("res://Scripts/Triggers/NineVoiceTrigger.gd"):
		return
	var trigger := Area3D.new()
	trigger.name = "NineIntroTrigger"
	trigger.set_script(load("res://Scripts/Triggers/NineVoiceTrigger.gd"))
	# Sit just south of the gate (keeps SpawnPoint at ~z=4.8 outside the box).
	trigger.position = Vector3(gate_pos.x, 1.0, gate_pos.z - 1.5)
	trigger.set("object_id", "green_grove_nine_intro")
	trigger.set("clip_basename", "intro")
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 4.0, 3.0)
	col.shape = shape
	trigger.add_child(col)
	root.add_child(trigger)


func _add_level_title(root: Node3D) -> void:
	if not ResourceLoader.exists("res://Scenes/UI/LevelTitleTrigger.tscn"):
		return
	# Data marker only — MapManager presents the banner once per map load.
	var title: Node3D = load("res://Scenes/UI/LevelTitleTrigger.tscn").instantiate() as Node3D
	title.name = "LevelTitle"
	title.set("level_title", "GreenGrove")
	title.set("play_new_area_sound", true)
	root.add_child(title)


func _add_return_spawner(root: Node3D, floor_map: GridMap, wall_map: GridMap, wall_map2: GridMap, wall_map3: GridMap) -> void:
	var spawner := Node3D.new()
	spawner.name = "ReturnVisitEnemySpawner"
	spawner.set_script(load("res://Scripts/Environment/return_visit_enemy_spawner.gd"))
	spawner.set("map_id", "GreenGrove")
	spawner.set("floor_map", floor_map)
	spawner.set("wall_maps", [wall_map, wall_map2, wall_map3] as Array[GridMap])
	spawner.set("spawn_point", root.get_node("SpawnPoint"))
	spawner.set("enemy_scene", load("res://Scenes/Enemies/SlimeDroneWorldEnemy.tscn"))
	spawner.set("spawn_count", 3)
	spawner.set("player_safe_radius", 8.0)
	root.add_child(spawner)


func _set_owner_recursive(node: Node, root_node: Node) -> void:
	for child: Node in node.get_children():
		if child != root_node:
			child.owner = root_node
			if child.scene_file_path.is_empty():
				_set_owner_recursive(child, root_node)
