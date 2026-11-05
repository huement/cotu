# res://Scripts/Utilities/RebuildCaveWalls.gd
@tool
extends EditorScript
## Rebuilds the WallMap of the OPEN cave level from its FloorMap.
## Paint (or erase) floor cells by hand, then File -> Run this script: every rock cell
## next to a floor cell gets the matching wall piece (straight, corner, double, end or
## pillar) and rotation. Crystal rocks already on the WallMap are kept.
## Nothing is saved automatically - press Ctrl/Cmd+S afterwards.


func _run() -> void:
	var root: Node = get_scene()
	if root == null:
		push_error("RebuildCaveWalls: open a cave level scene first.")
		return

	var floor_map: GridMap = root.get_node_or_null("FloorMap") as GridMap
	var wall_map: GridMap = root.get_node_or_null("WallMap") as GridMap
	if floor_map == null or wall_map == null:
		push_error("RebuildCaveWalls: the open scene needs FloorMap and WallMap GridMaps.")
		return

	# Open cells = every painted floor cell (y = 0 layer).
	var open_cells: Dictionary[Vector2i, bool] = {}
	var min_cell := Vector2i(1 << 20, 1 << 20)
	var max_cell := Vector2i(-(1 << 20), -(1 << 20))
	for cell: Vector3i in floor_map.get_used_cells():
		if cell.y != 0:
			continue
		var c := Vector2i(cell.x, cell.z)
		open_cells[c] = true
		min_cell = Vector2i(mini(min_cell.x, c.x), mini(min_cell.y, c.y))
		max_cell = Vector2i(maxi(max_cell.x, c.x), maxi(max_cell.y, c.y))
	if open_cells.is_empty():
		push_error("RebuildCaveWalls: the FloorMap is empty.")
		return

	# Keep crystal rocks (props standing on floor cells).
	var crystals: Array[Vector3i] = []
	var crystal_orients: Array[int] = []
	for cell: Vector3i in wall_map.get_used_cells():
		if wall_map.get_cell_item(cell) == CaveGenerator.CRYSTAL and open_cells.has(Vector2i(cell.x, cell.z)):
			crystals.append(cell)
			crystal_orients.append(wall_map.get_cell_item_orientation(cell))

	# Same seed -> same wall variants every rebuild.
	var rng := RandomNumberGenerator.new()
	var seed_value: Variant = root.get("level_seed")
	rng.seed = int(seed_value) if seed_value != null else 0

	var region := Rect2i(min_cell - Vector2i.ONE, max_cell - min_cell + Vector2i(3, 3))
	var walls: Array[Vector4i] = CaveGenerator.autowall(open_cells, region, rng)

	wall_map.clear()
	for w: Vector4i in walls: # (x, z, item, orientation)
		wall_map.set_cell_item(Vector3i(w.x, 0, w.y), w.z, w.w)
	for i: int in range(crystals.size()):
		wall_map.set_cell_item(crystals[i], CaveGenerator.CRYSTAL, crystal_orients[i])

	EditorInterface.mark_scene_as_unsaved()
	print("RebuildCaveWalls: placed %d wall pieces around %d floor cells (%d crystals kept). Save with Ctrl/Cmd+S." % [
		walls.size(), open_cells.size(), crystals.size()])
