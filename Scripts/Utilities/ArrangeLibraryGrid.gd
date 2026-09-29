@tool
extends EditorScript

# Adjust columns per row and spacing distance as needed
const COLUMNS: int = 6
const SPACING: float = 4.0

func _run() -> void:
	var scene_root: Node = get_scene()
	if not scene_root:
		push_warning("ArrangeLibraryGrid: No active scene found in the editor.")
		return

	var index: int = 0
	for child in scene_root.get_children():
		if not child is Node3D:
			continue

		var col: int = index % COLUMNS
		var row: int = index / COLUMNS

		child.position = Vector3(col * SPACING, 0.0, row * SPACING)
		index += 1

	print("ArrangeLibraryGrid: Successfully arranged %d nodes into a %d-column grid." % [index, COLUMNS])
