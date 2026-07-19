extends Node
#class_name WorldSceneInitializerModule

const GRID_PLANE_SUBDIVISIONS: int = 9
const GRID_PLANE_SIZE: Vector2 = Vector2(64, 64)
const CEILING_HEIGHT: float = 2.0 

func _ready() -> void:
	var world_root: Node3D = get_parent() as Node3D
	if world_root:
		_align_gridmap_to_player_grid(world_root)
		_add_floor(world_root)
		_add_ceiling(world_root)
		# 🎯 AUTOMATION HOOK: Run ambient calibration on bootup
		_setup_retro_environment(world_root)
	else:
		push_error("SceneInitializerModule: Parent must be a Node3D root!")

func _align_gridmap_to_player_grid(root: Node3D) -> void:
	var gm: GridMap = root.get_node_or_null("GridMap") as GridMap
	if gm == null:
		return

	var x_offset: float = -gm.cell_size.x * 0.5 if gm.cell_center_x else 0.0
	var z_offset: float = -gm.cell_size.z * 0.5 if gm.cell_center_z else 0.0
	gm.position = Vector3(x_offset, 0.0, z_offset)

## Programmatically injects ambient space lighting and a player-centered torch
func _setup_retro_environment(root: Node3D) -> void:
	# 1. Spawn a WorldEnvironment to break up solid zero-value black shadows
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = "GeneratedWorldEnvironment"
	
	var env: Environment = Environment.new()
	
	# Setup Ambient Light: Forces unlit wall faces to retain a faint, deep-space glow
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.08, 0.12) # Deep, atmospheric sci-fi charcoal blue
	env.ambient_light_energy = 0.25
	
	# Setup Classic Distance Falloff Fog: Smoothly vignettes remote corridors into the darkness
	env.fog_enabled = true
	env.fog_light_color = Color.BLACK
	env.fog_density = 0.0 # Bypasses modern volumetric fog for authentic retro rendering
	env.fog_depth_begin = 5.0
	env.fog_depth_end = 15.0 # Cutoff threshold matching your grid visibility array
	
	world_env.environment = env
	root.add_child.call_deferred(world_env)
	
	# 2. Automatically locate the Player camera and attach a flashlight spell/torch node
	var player: Node3D = root.get_node_or_null("Player") as Node3D
	if player:
		# Search child nodes for your primary viewing camera perspective
		var camera: Camera3D = player.get_node_or_null("Camera3D") as Camera3D
		if not camera:
			for child in player.get_children():
				if child is Camera3D:
					camera = child as Camera3D
					break
		
		# If the camera is resolved, mount a localized exploration torch light directly to it
		if camera and not camera.has_node("FelineTorch"):
			var torch: OmniLight3D = OmniLight3D.new()
			torch.name = "FelineTorch"
			torch.light_energy = 0.85
			torch.omni_range = 14.0       # Extends down a couple of structural grid segments
			torch.omni_attenuation = 1.6  # Smoothly drops off light intensity over distance
			camera.add_child.call_deferred(torch)
			print("SceneInitializerModule: Tactical torch successfully mounted to Player Camera3D.")

func _add_floor(root: Node3D) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "GeneratedFloor"
	mesh_instance.position = _get_grid_visual_offset(root)

	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = GRID_PLANE_SIZE
	plane.subdivide_depth = GRID_PLANE_SUBDIVISIONS
	plane.subdivide_width = GRID_PLANE_SUBDIVISIONS
	mesh_instance.mesh = plane

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.75, 0.75)
	mat.albedo_texture = _make_floor_texture()
	mat.texture_repeat = 1
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = _uv_scale_for_grid(root, plane.size)
	mat.emission_enabled = true
	mat.emission = Color(0.06, 0.06, 0.06)
	mesh_instance.material_override = mat

	root.add_child.call_deferred(mesh_instance)

func _add_ceiling(root: Node3D) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "GeneratedCeiling"
	mesh_instance.position = _get_grid_visual_offset(root) + Vector3(0.0, CEILING_HEIGHT, 0.0)
	mesh_instance.rotate_x(PI)
	mesh_instance.layers = 2 

	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = GRID_PLANE_SIZE
	plane.subdivide_depth = GRID_PLANE_SUBDIVISIONS
	plane.subdivide_width = GRID_PLANE_SUBDIVISIONS
	mesh_instance.mesh = plane

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.26, 0.26, 0.26)
	mat.albedo_texture = _make_ceiling_texture()
	mat.texture_repeat = 1
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = _uv_scale_for_grid(root, plane.size)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat

	root.add_child.call_deferred(mesh_instance)

func _make_floor_texture() -> ImageTexture:
	var size: int = 128
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.52, 0.52, 0.52))

	for x in range(size):
		img.set_pixel(x, 0, Color(0.2, 0.2, 0.2))
		img.set_pixel(x, size - 1, Color(0.2, 0.2, 0.2))

	for y in range(size):
		img.set_pixel(0, y, Color(0.2, 0.2, 0.2))
		img.set_pixel(size - 1, y, Color(0.2, 0.2, 0.2))

	return ImageTexture.create_from_image(img)

func _make_ceiling_texture() -> ImageTexture:
	var size: int = 128
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.18, 0.18, 0.18))

	for y in range(size):
		var dark_band: bool = y % 32 < 2
		for x in range(size):
			if dark_band:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.08))
			elif x % 32 == 0:
				img.set_pixel(x, y, Color(0.28, 0.28, 0.28))

	return ImageTexture.create_from_image(img)

func _get_grid_visual_offset(root: Node3D) -> Vector3:
	var gm: GridMap = root.get_node_or_null("GridMap") as GridMap
	if gm == null:
		return Vector3.ZERO

	var x_offset: float = -gm.cell_size.x * 0.5 if gm.cell_center_x else 0.0
	var z_offset: float = -gm.cell_size.z * 0.5 if gm.cell_center_z else 0.0
	return Vector3(x_offset, 0.0, z_offset)

func _uv_scale_for_grid(root: Node3D, plane_size: Vector2) -> Vector3:
	var gm: GridMap = root.get_node_or_null("GridMap") as GridMap
	if gm == null:
		return Vector3(plane_size.x, plane_size.y, 1.0)

	var cell_x: float = max(0.001, gm.cell_size.x)
	var cell_z: float = max(0.001, gm.cell_size.z)
	var tiles_x: float = plane_size.x / cell_x
	var tiles_y: float = plane_size.y / cell_z
	return Vector3(tiles_x, tiles_y, 1.0)
