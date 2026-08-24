class_name CameraShake
extends Node

## Non-Destructive Camera Shake Component for Godot 4.
## Listens to SignalBus.camera_shake_requested and applies camera projection offsets
## via h_offset and v_offset without modifying the camera's position or transform.

@export_group("Target")
## The Camera3D or Control node to apply shake offsets to.
@export var target_node: Node

@export_group("Shake Configuration")
## How fast trauma decays per second.
@export var trauma_decay: float = 2.5
## Maximum horizontal offset (3D camera h_offset or 2D X pixels).
@export var max_h_offset: float = 0.2
## Maximum vertical offset (3D camera v_offset or 2D Y pixels).
@export var max_v_offset: float = 0.2
## Maximum Z-axis rotation roll (in degrees).
@export var max_roll_degrees: float = 2.0

var trauma: float = 0.0
var noise := FastNoiseLite.new()
var noise_time: float = 0.0

var _base_position_2d := Vector2.ZERO
var _base_rotation_z: float = 0.0
var _has_saved_base_2d: bool = false


func _ready() -> void:
	noise.seed = randi()
	noise.frequency = 0.2

	var sb: Node = SignalBus
	if is_instance_valid(sb):
		if not sb.camera_shake_requested.is_connected(add_trauma):
			sb.camera_shake_requested.connect(add_trauma)


func _process(delta: float) -> void:
	if not is_instance_valid(target_node):
		return

	if trauma <= 0.0:
		_reset_target()
		return

	# 1. Linear Trauma Decay
	trauma = maxf(0.0, trauma - trauma_decay * delta)

	# 2. Non-linear intensity curve (Trauma^2) for sharp impact and smooth rest
	var shake_amount: float = trauma * trauma

	# 3. Advance Noise Step
	noise_time += delta * 150.0

	# 4. Apply offsets non-destructively based on node type
	if target_node is Camera3D:
		var cam: Camera3D = target_node as Camera3D
		cam.h_offset = max_h_offset * shake_amount * noise.get_noise_2d(noise_time, 0.0)
		cam.v_offset = max_v_offset * shake_amount * noise.get_noise_2d(noise_time, 100.0)
		cam.rotation.z = deg_to_rad(max_roll_degrees * shake_amount * noise.get_noise_2d(noise_time, 200.0))

	elif target_node is Control or target_node is Node2D:
		if not _has_saved_base_2d:
			_base_position_2d = target_node.position
			_base_rotation_z = target_node.rotation if target_node is Node2D else 0.0
			_has_saved_base_2d = true

		var offset_x: float = max_h_offset * 50.0 * shake_amount * noise.get_noise_2d(noise_time, 0.0)
		var offset_y: float = max_v_offset * 50.0 * shake_amount * noise.get_noise_2d(noise_time, 100.0)
		var roll: float = deg_to_rad(max_roll_degrees * shake_amount * noise.get_noise_2d(noise_time, 200.0))

		target_node.position = _base_position_2d + Vector2(offset_x, offset_y)
		if "rotation" in target_node:
			target_node.rotation = _base_rotation_z + roll


## Resets target node offsets to exact rest state
func _reset_target() -> void:
	if not is_instance_valid(target_node):
		return

	if target_node is Camera3D:
		var cam: Camera3D = target_node as Camera3D
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		cam.rotation.z = 0.0

	elif (target_node is Control or target_node is Node2D) and _has_saved_base_2d:
		target_node.position = _base_position_2d
		if "rotation" in target_node:
			target_node.rotation = _base_rotation_z
		_has_saved_base_2d = false


## Adds trauma to the camera shake bucket (clamped between 0.0 and 1.0)
func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)
