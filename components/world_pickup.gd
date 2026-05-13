class_name WorldPickup
extends Node3D

signal collected(item: ItemData)

@export var grid_cell: Vector2i = Vector2i.ZERO
@export var item_data: ItemData
@export var world_y: float = 0.0


func _ready() -> void:
	add_to_group(&"world_pickups")
	_sync_world_position()


func collect_if_player_on_cell(player, player_cell: Vector2i) -> bool:
	if item_data == null:
		return false
	if player == null:
		return false
	if player_cell != grid_cell:
		return false
	if not player.has_method("add_item"):
		return false
	if not bool(player.call("add_item", item_data)):
		return false

	collected.emit(item_data)
	queue_free()
	return true


func _sync_world_position() -> void:
	global_position = GridMapper.cell_to_world(grid_cell, 1.0, world_y)
