@tool
extends EditorScript

func _run() -> void:
	var scene_root: Node = get_scene()
	if not scene_root:
		push_warning("MakeNodesLocal: No active scene found in the editor.")
		return

	var converted_count: int = 0

	for child in scene_root.get_children():
		if not child.scene_file_path.is_empty():
			_make_local(child, scene_root)
			converted_count += 1

	print("MakeNodesLocal: Successfully made %d scene instances local in '%s'." % [converted_count, scene_root.name])

func _make_local(node: Node, scene_root: Node) -> void:
	# Clearing scene_file_path severs the link to the external GLB/TSCN file
	node.scene_file_path = ""
	_assign_owner_recursive(node, scene_root)

func _assign_owner_recursive(node: Node, scene_root: Node) -> void:
	# Assign all nested children's owner to the edited scene root so Godot saves them locally
	for child in node.get_children():
		child.owner = scene_root
		_assign_owner_recursive(child, scene_root)
