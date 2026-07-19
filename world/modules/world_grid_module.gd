extends Node
class_name WorldGridModule

var _occupancy: GridOccupancyMap


func build_occupancy(grid_map: GridMap, wall_layer: int, auto_align: bool) -> void:
	if auto_align:
		_align_gridmap_to_player_grid(grid_map)
	_occupancy = GridOccupancyMap.from_grid_map(grid_map, wall_layer)
	print("[Occupancy] layer=%d wired %d blocked cells" % [wall_layer, _occupancy._blocked.size()])


func occupancy() -> GridOccupancyMap:
	return _occupancy


func is_player_cell_passable(cell: Vector2i, enemies: Array) -> bool:
	if _occupancy != null and not _occupancy.is_passable(cell):
		return false

	for enemy in enemies:
		if enemy == null or enemy.grid_state == null:
			continue
		if enemy.stats != null and enemy.stats.is_dead():
			continue
		if enemy.grid_state.cell == cell:
			return false

	return true


func is_enemy_cell_passable(enemy, cell: Vector2i, enemies: Array) -> bool:
	if _occupancy != null and not _occupancy.is_passable(cell):
		return false

	for other in enemies:
		if other == null or other == enemy or other.grid_state == null:
			continue
		if other.stats != null and other.stats.is_dead():
			continue
		if other.grid_state.cell == cell:
			return false

	return true


func _align_gridmap_to_player_grid(gm: GridMap) -> void:
	# Keep painted visuals aligned with integer world cells used by player movement.
	var x_offset := -gm.cell_size.x * 0.5 if gm.cell_center_x else 0.0
	var y_offset := 0.0
	var z_offset := -gm.cell_size.z * 0.5 if gm.cell_center_z else 0.0
	gm.position = Vector3(x_offset, y_offset, z_offset)
