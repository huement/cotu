class_name WorldExit
extends Node3D

const EXIT_GROUP := &"world_exit_cells"

@export var grid_cell: Vector2i = Vector2i.ZERO
@export var world_y: float = 0.0
@export var requires_cleared_floor: bool = true


func _ready() -> void:
	add_to_group(EXIT_GROUP)
	_sync_world_position()


func matches_cell(cell: Vector2i) -> bool:
	return cell == grid_cell


func can_trigger(has_remaining_enemies: bool) -> bool:
	return not requires_cleared_floor or not has_remaining_enemies


func _sync_world_position() -> void:
	global_position = GridMapper.cell_to_world(grid_cell, 1.0, world_y)