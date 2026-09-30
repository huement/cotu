@tool
extends EditorScript

const COLUMNS: int = 6
const SPACING: float = 4.0

func _run() -> void:
	var scene_root: Node = get_scene()
	if not scene_root:
		push_warning("PrepareMeshLibraryScene: No active scene found in the editor.")
		return

	print("--- Preparing Scene for MeshLibrary Export ---")

	# Step 1: Make imported scene instances local
	var local_count: int = _make_nodes_local(scene_root)
	print("1. Local Conversion: Made %d scene instances local." % local_count)

	# Step 2: Scale mesh instances to 2x2x2 units
	var scale_count: int = _scale_tile_meshes(scene_root)
	print("2. Mesh Scaling: Scaled %d MeshInstance3D nodes to (2, 2, 2)." % scale_count)

	# Step 3: Generate trimesh collision shapes
	var collision_count: int = _generate_collisions(scene_root)
	print("3. Collisions: Generated collision bodies for %d tiles." % collision_count)

	# Step 4: Arrange tile nodes in a clean 2D grid
	var arrange_count: int = _arrange_grid(scene_root)
	print("4. Grid Arrangement: Placed %d tiles into a %d-column grid." % [arrange_count, COLUMNS])

	print("--- Scene Preparation Complete! Save (Ctrl+S) and export as MeshLibrary. ---")

func _make_nodes_local(scene_root: Node) -> int:
	var count: int = 0
	for child in scene_root.get_children():
		if not child.scene_file_path.is_empty():
			child.scene_file_path = ""
			_assign_owner_recursive(child, scene_root)
			count += 1
	return count

func _scale_tile_meshes(scene_root: Node) -> int:
	var count: int = 0
	for tile in scene_root.get_children():
		if not tile is Node3D:
			continue
		for child in tile.get_children():
			if child is MeshInstance3D:
				child.scale = Vector3(2.0, 2.0, 2.0)
				count += 1
	return count

func _generate_collisions(scene_root: Node) -> int:
	var count: int = 0
	for tile in scene_root.get_children():
		var mesh_inst: MeshInstance3D = null
		for child in tile.get_children():
			if child is MeshInstance3D:
				mesh_inst = child
				break

		if not mesh_inst or not mesh_inst.mesh:
			continue

		var has_collision: bool = false
		for child in mesh_inst.get_children():
			if child is StaticBody3D:
				has_collision = true
				break

		if not has_collision:
			mesh_inst.create_trimesh_collision()
			_assign_owner_recursive(mesh_inst, scene_root)
			count += 1
	return count

func _arrange_grid(scene_root: Node) -> int:
	var index: int = 0
	for child in scene_root.get_children():
		if not child is Node3D:
			continue

		var col: int = index % COLUMNS
		var row: int = index / COLUMNS

		child.position = Vector3(col * SPACING, 0.0, row * SPACING)
		index += 1
	return index

func _assign_owner_recursive(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_assign_owner_recursive(child, scene_root)
