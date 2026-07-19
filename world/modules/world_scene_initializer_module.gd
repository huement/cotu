extends Node

class_name WorldSceneInitializerModule

const GRID_PLANE_SUBDIVISIONS := 9
const GRID_PLANE_SIZE := Vector2(64, 64)
const CEILING_HEIGHT := 1.0


func add_environment(root: Node3D) -> void:
	_add_floor(root)
	_add_ceiling(root)


func _add_floor(root: Node3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DebugFloor"
	mesh_instance.position = _get_grid_visual_offset(root)

	var plane := PlaneMesh.new()
	plane.size = GRID_PLANE_SIZE
	plane.subdivide_depth = GRID_PLANE_SUBDIVISIONS
	plane.subdivide_width = GRID_PLANE_SUBDIVISIONS
	mesh_instance.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.75, 0.75)
	mat.albedo_texture = _make_floor_texture()
	mat.texture_repeat = 1
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = _uv_scale_for_grid(root, plane.size)
	mat.emission_enabled = true
	mat.emission = Color(0.06, 0.06, 0.06)
	mesh_instance.material_override = mat

	root.add_child(mesh_instance)


func _add_ceiling(root: Node3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DebugCeiling"
	mesh_instance.position = _get_grid_visual_offset(root) + Vector3(0.0, CEILING_HEIGHT, 0.0)
	mesh_instance.rotate_x(PI)

	var plane := PlaneMesh.new()
	plane.size = GRID_PLANE_SIZE
	plane.subdivide_depth = GRID_PLANE_SUBDIVISIONS
	plane.subdivide_width = GRID_PLANE_SUBDIVISIONS
	mesh_instance.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.26, 0.26, 0.26)
	mat.albedo_texture = _make_ceiling_texture()
	mat.texture_repeat = 1
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = _uv_scale_for_grid(root, plane.size)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat

	root.add_child(mesh_instance)


func _make_floor_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.52, 0.52, 0.52))

	for x in range(size):
		img.set_pixel(x, 0, Color(0.2, 0.2, 0.2))
		img.set_pixel(x, size - 1, Color(0.2, 0.2, 0.2))

	for y in range(size):
		img.set_pixel(0, y, Color(0.2, 0.2, 0.2))
		img.set_pixel(size - 1, y, Color(0.2, 0.2, 0.2))

	var tex := ImageTexture.create_from_image(img)
	return tex


func _make_ceiling_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.18, 0.18, 0.18))

	for y in range(size):
		var dark_band := y % 32 < 2
		for x in range(size):
			if dark_band:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.08))
			elif x % 32 == 0:
				img.set_pixel(x, y, Color(0.28, 0.28, 0.28))

	var tex := ImageTexture.create_from_image(img)
	return tex


func _get_grid_visual_offset(root: Node3D) -> Vector3:
	var gm := root.get_node_or_null("GridMap") as GridMap
	if gm == null:
		return Vector3.ZERO

	var x_offset := -gm.cell_size.x * 0.5 if gm.cell_center_x else 0.0
	var z_offset := -gm.cell_size.z * 0.5 if gm.cell_center_z else 0.0
	return Vector3(x_offset, 0.0, z_offset)


func _uv_scale_for_grid(root: Node3D, plane_size: Vector2) -> Vector3:
	var gm := root.get_node_or_null("GridMap") as GridMap
	if gm == null:
		return Vector3(plane_size.x, plane_size.y, 1.0)

	var cell_x: float = max(0.001, gm.cell_size.x)
	var cell_z: float = max(0.001, gm.cell_size.z)
	var tiles_x: float = plane_size.x / cell_x
	var tiles_y: float = plane_size.y / cell_z
	return Vector3(tiles_x, tiles_y, 1.0)
