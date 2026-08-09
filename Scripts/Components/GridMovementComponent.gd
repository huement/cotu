# res://Scripts/Components/GridMovementComponent.gd
# TODO: get this hooked up and working. 
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
var current_heading: Vector3 = Vector3.FORWARD # Defaulting North (-Z)

func _ready() -> void:
	if ray_front != null:
		ray_front.target_position = Vector3.FORWARD * tile_size


func try_move_forward(parent_node: Node3D) -> bool:
	if is_moving:
		return false

	ray_front.force_raycast_update()
	if ray_front.is_colliding():
		# Play bumped wall SFX or signal
		SignalBus.audio_effect_requested.emit(&"wall_bump")
		return false

	var target_pos: Vector3 = parent_node.global_position + (parent_node.global_transform.basis.z * -tile_size)
	_animate_step(parent_node, target_pos)
	return true


func try_move_backward(parent_node: Node3D) -> bool:
	if is_moving:
		return false

	var target_pos: Vector3 = parent_node.global_position + (parent_node.global_transform.basis.z * tile_size)
	_animate_step(parent_node, target_pos)
	return true


func try_turn(parent_node: Node3D, angle_degrees: float) -> void:
	if is_moving:
		return

	is_moving = true
	var target_rotation: Vector3 = parent_node.rotation + Vector3(0.0, deg_to_rad(angle_degrees), 0.0)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(parent_node, "rotation", target_rotation, turn_duration)
	tween.finished.connect(func() -> void:
		is_moving = false
		current_heading = -parent_node.global_transform.basis.z
		turn_completed.emit(current_heading)
	)


func _animate_step(parent_node: Node3D, target_pos: Vector3) -> void:
	is_moving = true
	step_started.emit(target_pos)

	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(parent_node, "global_position", target_pos, step_duration)
	tween.finished.connect(func() -> void:
		is_moving = false
		step_completed.emit(parent_node.global_position)
	)
