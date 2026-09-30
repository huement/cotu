@tool
extends EditorScript

# Destination path for the generated MeshLibrary
const OUTPUT_PATH: String = "res://resources/mesh_library/forest_mesh_kenny.tres"

func _run() -> void:
	var scene_root: Node = get_scene()
	if not scene_root:
		printerr("BuildMeshLibrary: Please open the scene containing your models first.")
		return

	var mesh_lib := MeshLibrary.new()
	var item_id: int = 0

	print("--- Building MeshLibrary from: %s ---" % scene_root.name)

	for child in scene_root.get_children():
		var mesh_instance: MeshInstance3D = _find_mesh_instance(child)
		if mesh_instance and mesh_instance.mesh:
			# 1. Calculate relative transform (handles 3D model rotation/scale)
			var relative_transform: Transform3D = (
				scene_root.global_transform.affine_inverse() * mesh_instance.global_transform
			)

			# 2. Calculate mesh bounding box and offset Y so the base sits at Y = 0
			var raw_aabb: AABB = mesh_instance.mesh.get_aabb()
			var transformed_aabb: AABB = relative_transform * raw_aabb
			relative_transform.origin.y -= transformed_aabb.position.y

			mesh_lib.create_item(item_id)
			mesh_lib.set_item_name(item_id, child.name)
			mesh_lib.set_item_mesh(item_id, mesh_instance.mesh)

			# 3. Apply Y-aligned transform to mesh
			mesh_lib.set_item_mesh_transform(item_id, relative_transform)

			# 4. Generate convex collision shape and apply the same Y-aligned transform
			var shape: Shape3D = mesh_instance.mesh.create_convex_shape()
			mesh_lib.set_item_shapes(item_id, [shape, relative_transform])

			print("Added item [%d]: %s (Auto-aligned Y base)" % [item_id, child.name])
			item_id += 1

	if item_id == 0:
		printerr("BuildMeshLibrary: No MeshInstance3D nodes found under scene root.")
		return

	var error := ResourceSaver.save(mesh_lib, OUTPUT_PATH)
	if error == OK:
		print("Successfully generated MeshLibrary with %d items at: %s" % [item_id, OUTPUT_PATH])
	else:
		printerr("Failed to save MeshLibrary. Error code: %d" % error)

# Helper function to find MeshInstance3D deeply in instanced subscenes
func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null
