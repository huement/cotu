class_name GridOccupancyMap
extends RefCounted

var _blocked: Dictionary  # Vector2i -> true


static func from_grid_map(gm: GridMap, wall_layer: int = 0) -> GridOccupancyMap:
	var om := GridOccupancyMap.new()
	for cell_3i: Vector3i in gm.get_used_cells():
		if cell_3i.y == wall_layer:
			om._blocked[Vector2i(cell_3i.x, cell_3i.z)] = true
	return om


func is_passable(cell: Vector2i) -> bool:
	return not _blocked.has(cell)


func set_blocked(cell: Vector2i, blocked: bool) -> void:
	if blocked:
		_blocked[cell] = true
	else:
		_blocked.erase(cell)
