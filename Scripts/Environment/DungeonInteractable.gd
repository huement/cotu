# res://Scripts/Environment/DungeonInteractable.gd
class_name DungeonInteractable
extends Node3D

## Unique identifier for save state tracking (e.g. "d1_chest_01")
@export var object_id: String = "interactable_01"

## If true, snaps global_position to the exact floor cell center.
## Set to false for wall-mounted objects (masks, terminals) to preserve editor height/offset.
@export var snap_to_floor_center: bool = true

## Optional manually assigned GridMap cell. If (0,0), cell position is auto-detected from 3D Editor placement.
@export var initial_cell: Vector2i = Vector2i.ZERO

## Does this object block party movement into its cell?
@export var is_blocking: bool = true

## Does this object reset its state upon dungeon reset?
@export var respawns: bool = false

var _grid_position: Vector2i = Vector2i.ZERO


func _ready() -> void:
	add_to_group(&"dungeon_interactables")
	call_deferred("_align_to_grid")


func get_grid_pos() -> Vector2i:
	return _grid_position


## Converts 3D Editor placement or initial_cell into GridMap cell coordinates and snaps position
func _align_to_grid() -> void:
	var map_mgr: Node3D = get_tree().current_scene.find_child("MapManager", true, false) as Node3D
	if not is_instance_valid(map_mgr):
		map_mgr = get_tree().root.find_child("MapManager", true, false) as Node3D

	var grid: GridMap = null
	if is_instance_valid(map_mgr) and "dungeon_grid" in map_mgr and is_instance_valid(map_mgr.dungeon_grid):
		grid = map_mgr.dungeon_grid as GridMap

	# 1. Resolve 2D grid cell coordinates for spatial lookup & player interaction
	if initial_cell != Vector2i.ZERO:
		_grid_position = initial_cell
	elif is_instance_valid(grid):
		var local_pos: Vector3 = grid.to_local(global_position)
		var map_cell: Vector3i = grid.local_to_map(local_pos)
		_grid_position = Vector2i(map_cell.x, map_cell.z)
	elif is_instance_valid(map_mgr) and map_mgr.has_method("world_to_grid"):
		var map_cell: Vector3i = map_mgr.world_to_grid(global_position)
		_grid_position = Vector2i(map_cell.x, map_cell.z)
	else:
		_grid_position = Vector2i(roundi((global_position.x - 1.0) / 2.0), roundi((global_position.z - 1.0) / 2.0))

	# 2. Only overwrite 3D transform if snapping is enabled (Chests/Loot)
	if snap_to_floor_center and is_instance_valid(grid):
		var cell_3d := Vector3i(_grid_position.x, 0, _grid_position.y)
		var local_pos: Vector3 = grid.map_to_local(cell_3d)
		global_position = grid.to_global(local_pos)


func interact(_player: Node3D) -> void:
	pass


## Helper to fetch active map ID
func _get_current_map_id() -> String:
	var scene: Node = get_tree().current_scene
	return str(scene.name) if is_instance_valid(scene) else "default_dungeon"
