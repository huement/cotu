extends Node3D

@export var floor_map: GridMap
@export var grass_mesh: Mesh
@export var valid_floor_item_ids: Array[int] = [1, 8] # Tile IDs in MeshLibrary corresponding to green grass floor
@export var tufts_per_tile: int = 6
@export var position_jitter: float = 0.8 # Random scatter radius inside each cell
@export var min_scale: Vector3 = Vector3(0.8, 0.8, 0.8)
@export var max_scale: Vector3 = Vector3(1.2, 1.5, 1.2)

var multimesh_instance: MultiMeshInstance3D

func _ready() -> void:
	if not floor_map:
		floor_map = get_node_or_null("%FloorMap") as GridMap
		
	if not floor_map or not grass_mesh:
		return

	generate_grass()

func generate_grass() -> void:
	var used_cells: Array[Vector3i] = floor_map.get_used_cells()
	var target_cells: Array[Vector3i] = []

	for cell in used_cells:
		var item_id: int = floor_map.get_cell_item(cell)
		if item_id in valid_floor_item_ids:
			target_cells.append(cell)

	if target_cells.is_empty():
		return

	var total_instances: int = target_cells.size() * tufts_per_tile

	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = grass_mesh
	multimesh.instance_count = total_instances

	var instance_idx: int = 0

	for cell in target_cells:
		var tile_center: Vector3 = floor_map.map_to_local(cell)

		for i in range(tufts_per_tile):
			var offset_x: float = randf_range(-position_jitter, position_jitter)
			var offset_z: float = randf_range(-position_jitter, position_jitter)
			var pos: Vector3 = tile_center + Vector3(offset_x, 0.0, offset_z)

			var rot_y: float = randf_range(0.0, TAU)
			var scale_factor: Vector3 = Vector3(
				randf_range(min_scale.x, max_scale.x),
				randf_range(min_scale.y, max_scale.y),
				randf_range(min_scale.z, max_scale.z)
			)

			var xform: Transform3D = Transform3D()
			xform = xform.scaled(scale_factor)
			xform = xform.rotated(Vector3.UP, rot_y)
			xform.origin = pos

			multimesh.set_instance_transform(instance_idx, xform)
			instance_idx += 1

	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.multimesh = multimesh
	add_child(multimesh_instance)