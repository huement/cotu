# res://Scripts/Editor/ForestLevelGenerator.gd
@tool
extends EditorScript

func _run() -> void:
	# --- CONFIGURATION (Edit these values before selecting File -> Run) ---
	var scene_name: String = "StoneTrail"
	var include_chests: bool = true
	var include_minotaurs: bool = true

	_create_forest_level(scene_name, include_chests, include_minotaurs)

func _create_forest_level(scene_name: String, include_chests: bool, include_minotaurs: bool) -> void:
	var clean_name: String = scene_name.strip_edges()
	if clean_name.is_empty():
		push_error("ForestLevelGenerator: Please enter a valid 'scene_name'.")
		return

	var save_path: String = "res://Scenes/".path_join(clean_name + ".tscn")
	
	# Root Scene Node
	var root := Node3D.new()
	root.name = clean_name

	# 1. WorldEnvironment
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.62, 1.0, 0.85, 1.0)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_albedo = Color(0.38, 0.46, 0.44, 1.0)
	env.volumetric_fog_emission = Color(0.15, 0.25, 0.25, 1.0)
	world_env.environment = env
	root.add_child(world_env)

	# 2. SunLight
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.transform = Transform3D(
		Basis.from_euler(Vector3(-0.8, -0.5, 0)),
		Vector3.ZERO
	)
	root.add_child(sun)

	# 3. SpawnPoint
	var spawn_point := Marker3D.new()
	spawn_point.name = "SpawnPoint"
	spawn_point.unique_name_in_owner = true
	spawn_point.position = Vector3(-16.32, 0.0, -91.69)
	spawn_point.set_meta("eye_height", 1.0)
	root.add_child(spawn_point)

	# 4. Empty GridMaps (Ready for tile painting)
	var floor_mesh_lib = load("res://resources/mesh_library/knature_mesh_library.tres")
	var wall_mesh_lib = load("res://resources/mesh_library/forestwall_mesh_library.tres")
	var replacer_script = load("res://Scripts/Environment/forest_grid_map_replacer.gd")

	var floor_map := GridMap.new()
	floor_map.name = "FloorMap"
	floor_map.unique_name_in_owner = true
	floor_map.mesh_library = floor_mesh_lib
	floor_map.cell_scale = 2.0
	floor_map.cell_center_y = false
	root.add_child(floor_map)

	var wall_map := GridMap.new()
	wall_map.name = "WallMap"
	wall_map.unique_name_in_owner = true
	wall_map.mesh_library = wall_mesh_lib
	wall_map.cell_scale = 2.0
	wall_map.set_script(replacer_script)
	root.add_child(wall_map)

	var wall_map2 := GridMap.new()
	wall_map2.name = "WallMap2"
	wall_map2.mesh_library = wall_mesh_lib
	wall_map2.cell_scale = 2.0
	wall_map2.set_script(replacer_script)
	if ResourceLoader.exists("res://Scenes/Environment/forest_wall_chunk.tscn"):
		wall_map2.set("forest_chunk_scene", load("res://Scenes/Environment/forest_wall_chunk.tscn"))
	root.add_child(wall_map2)

	var wall_map3 := GridMap.new()
	wall_map3.name = "WallMap3"
	wall_map3.mesh_library = wall_mesh_lib
	wall_map3.cell_scale = 2.0
	wall_map3.set_script(replacer_script)
	if ResourceLoader.exists("res://Scenes/Environment/forest_wall_chunk_thick.tscn"):
		wall_map3.set("forest_chunk_scene", load("res://Scenes/Environment/forest_wall_chunk_thick.tscn"))
	root.add_child(wall_map3)

	# 5. Object Containers
	var wood_paths := Node3D.new()
	wood_paths.name = "WoodPaths"
	root.add_child(wood_paths)

	var big_timbers := Node3D.new()
	big_timbers.name = "BigTimbers"
	root.add_child(big_timbers)

	var shrooms := Node3D.new()
	shrooms.name = "Shrooms"
	root.add_child(shrooms)

	# 6. WorldSceneInitializer
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

	# 7. GroundMist Particles
	var ground_mist := CPUParticles3D.new()
	ground_mist.name = "GroundMist"
	ground_mist.position = Vector3(0.0, 0.4, 0.0)
	ground_mist.amount = 60
	ground_mist.lifetime = 8.0
	ground_mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ground_mist.emission_box_extents = Vector3(35.0, 0.3, 35.0)
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

	# 8. CloudLayer
	var cloud_layer := Node3D.new()
	cloud_layer.name = "CloudLayer"
	cloud_layer.position = Vector3(0.0, 15.0, 0.0)
	if ResourceLoader.exists("res://Scripts/Environment/cloud_layer.gd"):
		cloud_layer.set_script(load("res://Scripts/Environment/cloud_layer.gd"))
		cloud_layer.set("min_scale", 0.5)
		cloud_layer.set("max_scale", 0.65)
	root.add_child(cloud_layer)

	_add_cloud_instance(cloud_layer, "res://resources/OutdoorParts/low_poly_cloud.glb", Vector3(0, 15, -16.78), Vector3.ONE)
	_add_cloud_instance(cloud_layer, "res://resources/OutdoorParts/low_poly_cloud-2.glb", Vector3.ZERO, Vector3.ONE)
	_add_cloud_instance(cloud_layer, "res://resources/OutdoorParts/low_poly_cloud-3.glb", Vector3(18.68, -3.9, -14.17), Vector3(2, 2, 2))
	_add_cloud_instance(cloud_layer, "res://resources/OutdoorParts/low_poly_cloud-4.glb", Vector3(-10.7, 0, -19.97), Vector3(3, 3, 3))

	# 9. DayLightCycle & Moon
	var day_light_cycle := Node3D.new()
	day_light_cycle.name = "DayLightCycle"
	if ResourceLoader.exists("res://Scripts/Environment/day_night_cycle.gd"):
		day_light_cycle.set_script(load("res://Scripts/Environment/day_night_cycle.gd"))

	var moon_light := DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.light_color = Color(0.665, 0.798, 1.0, 1.0)
	day_light_cycle.add_child(moon_light)

	if ResourceLoader.exists("res://resources/OutdoorParts/moon.glb"):
		var moon_mesh = load("res://resources/OutdoorParts/moon.glb").instantiate()
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

	# 10. GrassScatter
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

	# 11. Optional Treasure
	if include_chests:
		var treasure := Node3D.new()
		treasure.name = "Treasure"
		root.add_child(treasure)
		if ResourceLoader.exists("res://Scenes/Objects/chest.tscn"):
			var chest_scene = load("res://Scenes/Objects/chest.tscn")
			var chest1 = chest_scene.instantiate()
			chest1.position = Vector3(22.37, -0.24, 11.4)
			treasure.add_child(chest1)

	# 12. Optional Minotaurs & Spawner
	if include_minotaurs:
		var enemies := Node3D.new()
		enemies.name = "Enemies"
		root.add_child(enemies)

		if ResourceLoader.exists("res://Scenes/Enemies/MinotaurWorldEnemy.tscn"):
			var minotaur_scene = load("res://Scenes/Enemies/MinotaurWorldEnemy.tscn")
			var manual_minotaur = minotaur_scene.instantiate()
			manual_minotaur.name = "MinotaurWorldEnemy"
			manual_minotaur.position = Vector3(-16.32, 0.0, -84.0)
			manual_minotaur.set("is_night_only", false)
			enemies.add_child(manual_minotaur)

		var spawner := Node3D.new()
		spawner.name = "NightEnemySpawner"
		if ResourceLoader.exists("res://Scripts/Environment/night_enemy_spawner.gd"):
			spawner.set_script(load("res://Scripts/Environment/night_enemy_spawner.gd"))
			spawner.set("floor_map", floor_map)
			spawner.set("wall_maps", [wall_map, wall_map2, wall_map3])
			spawner.set("spawn_point", spawn_point)
			if ResourceLoader.exists("res://Scenes/Enemies/MinotaurWorldEnemy.tscn"):
				spawner.set("enemy_scene", load("res://Scenes/Enemies/MinotaurWorldEnemy.tscn"))
		root.add_child(spawner)

	# Set recursive ownership safely (does NOT recurse into sub-scene instances)
	_set_owner_recursive(root, root)

	# Pack & Save Scene
	var packed_scene := PackedScene.new()
	if packed_scene.pack(root) == OK:
		if ResourceSaver.save(packed_scene, save_path) == OK:
			print("✅ Forest level created successfully at: ", save_path)
		else:
			push_error("Failed to save scene file at: " + save_path)
	else:
		push_error("Failed to pack scene root node.")

	root.queue_free()

func _add_cloud_instance(parent: Node, glb_path: String, pos: Vector3, scale_vec: Vector3) -> void:
	if ResourceLoader.exists(glb_path):
		var inst = load(glb_path).instantiate()
		inst.position = pos
		inst.scale = scale_vec
		parent.add_child(inst)

func _set_owner_recursive(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		if child != root_node:
			child.owner = root_node
			# Only recurse into children if this node is NOT an instantiated sub-scene (.glb / .tscn)
			if child.scene_file_path.is_empty():
				_set_owner_recursive(child, root_node)
