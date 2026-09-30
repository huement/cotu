@tool
extends EditorScript

func _run() -> void:
	var scene_root: Node = get_scene()
	if not scene_root:
		push_warning("GenerateTileCollisions: No active scene found in the editor.")
		return

	var count: int = 0
	for tile in scene_root.get_children():
		var mesh_inst: MeshInstance3D = null
		for child in tile.get_children():
			if child is MeshInstance3D:
				mesh_inst = child
				break
		
		if not mesh_inst or not mesh_inst.mesh:
			continue

		# Skip if collision body already exists
		var has_collision: bool = false
		for child in mesh_inst.get_children():
			if child is StaticBody3D:
				has_collision = true
				break
		if has_collision:
			continue

		# Generate Trimesh StaticBody3D & CollisionShape3D automatically
		mesh_inst.create_trimesh_collision()
		_assign_owner_recursive(mesh_inst, scene_root)
		count += 1

	print("GenerateTileCollisions: Successfully generated collisions for %d tiles." % count)

func _assign_owner_recursive(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_assign_owner_recursive(child, scene_root)
