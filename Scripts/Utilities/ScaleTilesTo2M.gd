@tool
extends EditorScript

func _run() -> void:
	var scene_root: Node = get_scene()
	if not scene_root:
		push_warning("ScaleTilesTo2M: No active scene found in the editor.")
		return

	var count: int = 0
	for tile in scene_root.get_children():
		if not tile is Node3D:
			continue
		
		# Space out tile parent nodes in the viewport grid to prevent visual overlap
		tile.position *= 2.0

		# Scale each MeshInstance3D and its child collision shape to 2x2x2 units
		for child in tile.get_children():
			if child is MeshInstance3D:
				child.scale = Vector3(2.0, 2.0, 2.0)
				count += 1

	print("ScaleTilesTo2M: Successfully scaled %d tiles to 2x2x2 units." % count)
