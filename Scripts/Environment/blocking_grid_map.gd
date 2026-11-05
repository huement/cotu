# res://Scripts/Environment/blocking_grid_map.gd
class_name BlockingGridMap
extends GridMap

## Attach to any extra wall GridMap (e.g. a "MesaWallMap" painted with
## mesa_wall_mesh_library). Every painted cell is registered as blocked in
## MapManager on load, so the party can't walk through it.
##
## Only the GridMap named "WallMap" blocks automatically. Other GridMaps need this.

## Item IDs that should NOT block (e.g. a gate or a fallen pine you can walk past).
@export var walkable_item_ids: Array[int] = []


func _ready() -> void:
	_register_blocked_cells()


func _register_blocked_cells() -> void:
	var map_manager: MapManager = get_parent() as MapManager
	if not map_manager:
		map_manager = get_tree().root.find_child("MapManager", true, false) as MapManager
	if not is_instance_valid(map_manager):
		push_warning("BlockingGridMap '%s': no MapManager found, cells won't block." % name)
		return

	for cell: Vector3i in get_used_cells():
		if walkable_item_ids.has(get_cell_item(cell)):
			continue
		# Converts through world space, so this layer may be scaled/offset freely
		map_manager.register_blocked_grid_cell(self, cell)
