extends Node3D
class_name MapManager

## The main GridMap node containing your painted dungeon architecture.
@export var dungeon_grid: GridMap

## Maps out standard cardinal direction vectors to help calculate steps.
const DIRECTION_MAP: Dictionary = {
	"NORTH": Vector3i(0, 0, -1),
	"SOUTH": Vector3i(0, 0, 1),
	"EAST": Vector3i(1, 0, 0),
	"WEST": Vector3i(-1, 0, 0)
}

func _ready() -> void:
	if not dungeon_grid:
		push_error("MapManager: GridMap reference is missing in the Inspector!")
	else:
		print("MapManager: Space-Dungeon grid system online.")

## Converts an absolute 3D world position into 3D GridMap integer coordinates.
func world_to_grid(world_position: Vector3) -> Vector3i:
	if not dungeon_grid:
		return Vector3i.ZERO
	return dungeon_grid.local_to_map(dungeon_grid.to_local(world_position))

## Converts 3D GridMap integer coordinates back into absolute 3D world positions.
func grid_to_world(grid_position: Vector3i) -> Vector3:
	if not dungeon_grid:
		return Vector3.ZERO
	return dungeon_grid.to_global(dungeon_grid.map_to_local(grid_position))

## Checks if a target grid cell contains a blocking wall tile index.
func is_tile_blocked(grid_position: Vector3i) -> bool:
	if not dungeon_grid:
		return true
		
	var item_index: int = dungeon_grid.get_cell_item(grid_position)
	
	# In Godot GridMaps, -1 means the cell is empty/air (walkable path)
	if item_index == GridMap.INVALID_CELL_ITEM:
		return false
		
	# TODO: Expand this later to look up your data Resource files 
	# to check if the tile is a destructible wall, a closed door, or an interaction.
	return true

## Convenience helper to check if the space cat party can step forward based on direction.
func can_party_move(current_world_pos: Vector3, facing_direction: String) -> bool:
	var current_grid: Vector3i = world_to_grid(current_world_pos)
	
	if not DIRECTION_MAP.has(facing_direction):
		push_warning("MapManager: Invalid direction string passed: " + facing_direction)
		return false
		
	var direction_vector: Vector3i = DIRECTION_MAP[facing_direction]
	var target_grid: Vector3i = current_grid + direction_vector
	
	return not is_tile_blocked(target_grid)
