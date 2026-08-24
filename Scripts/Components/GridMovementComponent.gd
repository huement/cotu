# res://Scripts/Components/GridMovementComponent.gd
class_name GridMovementComponent
extends Node3D

signal step_started(target_position: Vector3)
signal step_completed(current_position: Vector3)
signal turn_completed(cardinal_direction: Vector3)

@export var tile_size: float = 2.0
@export var step_duration: float = 0.25
@export var turn_duration: float = 0.15

@onready var ray_front: RayCast3D = %RayFront

var is_moving: bool = false
var current_heading: Vector3 = Vector3.FORWARD
var map_manager: MapManager


func _ready() -> void:
	var world_root: Node3D = get_tree().root.get_node_or_null("World") as Node3D
	if is_instance_valid(world_root):
		map_manager = world_root.get_node_or_null("MapManager") as MapManager
	if ray_front != null:
		ray_front.target_position = Vector3.FORWARD * tile_size


## Attempts a cardinal step relative to parent orientation.
func try_step(parent_node: Node3D, local_input_dir: Vector3, _current_facing: String) -> bool:
	GameLogger.nav('try_step FIRED')
	if is_moving or not parent_node:
		return false

	var world_dir: Vector3 = Vector3.ZERO
	if local_input_dir == Vector3.FORWARD:
		world_dir = -parent_node.global_transform.basis.z
	elif local_input_dir == Vector3.BACK:
		world_dir = parent_node.global_transform.basis.z
	elif local_input_dir == Vector3.RIGHT:
		world_dir = parent_node.global_transform.basis.x
	elif local_input_dir == Vector3.LEFT:
		world_dir = -parent_node.global_transform.basis.x

	var target_world_pos: Vector3 = parent_node.global_position + (world_dir.normalized() * tile_size)

	if map_manager:
		var target_grid_pos: Vector3i = map_manager.world_to_grid(target_world_pos)
		if map_manager.is_tile_blocked(target_grid_pos):
			GameLogger.nav('try_step BLOCKED INSTANCE')
			var enemy_node: Node3D = map_manager.get_enemy_at_grid_pos(target_grid_pos)
			if is_instance_valid(enemy_node):
				var enemy_data: Variant = enemy_node.get("data") if "data" in enemy_node else null

				var party_members: Array = []
				var gs: Node = get_tree().root.get_node_or_null("GameState")
				if is_instance_valid(gs) and "current_party" in gs and gs.current_party:
					if "slots" in gs.current_party:
						party_members = gs.current_party.get("slots") as Array

				if is_instance_valid(SignalBus):
					SignalBus.combat_started.emit(enemy_data, party_members)
			else:
				if is_instance_valid(SignalBus):
					SignalBus.audio_effect_requested.emit(&"wall_bump")
			return false

	_animate_step(parent_node, target_world_pos)
	return true


func try_turn(parent_node: Node3D, angle_degrees: float) -> void:
	if is_moving:
		return

	is_moving = true
	var target_rotation: Vector3 = parent_node.rotation + Vector3(0.0, deg_to_rad(angle_degrees), 0.0)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(parent_node, "rotation", target_rotation, turn_duration)
	tween.finished.connect(
		func() -> void:
			is_moving = false
			current_heading = -parent_node.global_transform.basis.z
			turn_completed.emit(current_heading),
	)


func _animate_step(parent_node: Node3D, target_pos: Vector3) -> void:
	is_moving = true
	step_started.emit(target_pos)

	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(parent_node, "global_position", target_pos, step_duration)
	tween.finished.connect(
		func() -> void:
			is_moving = false
			step_completed.emit(parent_node.global_position),
	)
