extends Node3D
class_name DungeonPlayer

## Cardinal direction state tracking for retro grid exploration.
enum Facing { NORTH, WEST, SOUTH, EAST }

@onready var camera: Camera3D = $Camera3D as Camera3D

var grid_map: GridMap
var map_manager: MapManager

var current_grid_pos: Vector2i = Vector2i.ZERO
var current_facing: Facing = Facing.NORTH
var is_moving: bool = false
var _is_in_combat: bool = false

@export var initial_cell: Vector2i = Vector2i(2, 1)
@export var use_editor_spawn: bool = false
@export var movement_duration: float = 0.2
@export var rotation_duration: float = 0.15
@export var eye_height: float = 1.5

func _ready() -> void:
	call_deferred("_initialize_player")
	_connect_to_signal_bus()

func _connect_to_signal_bus() -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb):
		if not sb.combat_started.is_connected(_on_combat_started):
			sb.combat_started.connect(_on_combat_started)
		if not sb.combat_ended.is_connected(_on_combat_ended):
			sb.combat_ended.connect(_on_combat_ended)

func _initialize_player() -> void:
	var world_root: Node3D = get_parent() as Node3D
	grid_map = world_root.get_node_or_null("GridMap") as GridMap
	map_manager = world_root.get_node_or_null("MapManager") as MapManager

	if not grid_map:
		push_error("Player: GridMap sibling node could not be resolved from World root!")
		return

	rotation_degrees.x = 0.0
	rotation_degrees.z = 0.0

	if use_editor_spawn:
		current_grid_pos = _world_to_cell(global_position)
	else:
		current_grid_pos = initial_cell

	_apply_canonical_transform()

	camera.position = Vector3(0.0, eye_height, 0.0)
	camera.rotation_degrees = Vector3.ZERO
	
	# FORCE Godot to display this camera view on the main screen on launch!
	camera.make_current()

func _physics_process(_delta: float) -> void:
	if not grid_map:
		return

	rotation_degrees.x = 0.0
	rotation_degrees.z = 0.0
	if not is_moving:
		_apply_canonical_transform()

func _input(event: InputEvent) -> void:
	# 🛑 LOCKOUT GUARD: Block forward, strafe, backward, and turning while in combat
	if _is_in_combat or is_moving or not grid_map:
		return

	if event.is_action_pressed("move_forward"):
		_execute_grid_step(Vector3.FORWARD)
	elif event.is_action_pressed("move_backward"):
		_execute_grid_step(Vector3.BACK)
	elif event.is_action_pressed("strafe_left"):
		_execute_grid_step(Vector3.LEFT)
	elif event.is_action_pressed("strafe_right"):
		_execute_grid_step(Vector3.RIGHT)
	elif event.is_action_pressed("turn_left"):
		_execute_grid_rotation(90.0)
	elif event.is_action_pressed("turn_right"):
		_execute_grid_rotation(-90.0)

# ==============================================================================
# COMBAT SIGNAL CALLBACKS
# ==============================================================================
func _on_combat_started(_enemy_data: Resource, _player_party: Array) -> void:
	_is_in_combat = true

func _on_combat_ended(_victory: bool) -> void:
	_is_in_combat = false

# ==============================================================================
# MOVEMENT HELPERS
# ==============================================================================
func _get_movement_offset(input_direction: Vector3) -> Vector2i:
	var forward_vector: Vector2i = Vector2i.ZERO
	var right_vector: Vector2i = Vector2i.ZERO

	match current_facing:
		Facing.NORTH:
			forward_vector = Vector2i(0, -1)
			right_vector = Vector2i(1, 0)
		Facing.WEST:
			forward_vector = Vector2i(-1, 0)
			right_vector = Vector2i(0, -1)
		Facing.SOUTH:
			forward_vector = Vector2i(0, 1)
			right_vector = Vector2i(-1, 0)
		Facing.EAST:
			forward_vector = Vector2i(1, 0)
			right_vector = Vector2i(0, 1)

	if input_direction == Vector3.FORWARD:
		return forward_vector
	if input_direction == Vector3.BACK:
		return -forward_vector
	if input_direction == Vector3.RIGHT:
		return right_vector
	if input_direction == Vector3.LEFT:
		return -right_vector
	return Vector2i.ZERO

func _execute_grid_step(input_direction: Vector3) -> void:
	var coordinate_offset: Vector2i = _get_movement_offset(input_direction)
	var target_grid_pos: Vector2i = current_grid_pos + coordinate_offset
	var target_grid_3d: Vector3i = Vector3i(target_grid_pos.x, 0, target_grid_pos.y)

	if _is_cell_blocked(target_grid_3d):
		print("Movement blocked by structural layout block.")
		return

	is_moving = true

	var target_world_pos: Vector3 = _cell_to_world(target_grid_pos)
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", target_world_pos, movement_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	current_grid_pos = target_grid_pos
	_apply_canonical_transform()
	is_moving = false

	if get_tree().root.has_node("SignalBus"):
		get_tree().root.get_node("SignalBus").party_moved.emit(
			Vector3i(current_grid_pos.x, 0, current_grid_pos.y),
			_get_cardinal_string()
		)

func _execute_grid_rotation(angle_offset: float) -> void:
	is_moving = true

	var target_rotation: float = rotation_degrees.y + angle_offset
	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation_degrees:y", target_rotation, rotation_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	rotation_degrees.y = wrapf(rotation_degrees.y, 0.0, 360.0)
	var rounded_angle: int = roundi(rotation_degrees.y)

	match rounded_angle:
		0, 360:
			current_facing = Facing.NORTH
		90:
			current_facing = Facing.WEST
		180:
			current_facing = Facing.SOUTH
		270:
			current_facing = Facing.EAST

	is_moving = false

func _apply_canonical_transform() -> void:
	global_position = _cell_to_world(current_grid_pos)
	rotation_degrees.x = 0.0
	rotation_degrees.z = 0.0

func _cell_to_world(cell: Vector2i) -> Vector3:
	var local_pos: Vector3 = grid_map.map_to_local(Vector3i(cell.x, 0, cell.y))
	# FORCE local Y down to the floor baseline of the 3D grid cell cube
	local_pos.y = 0.0
	return grid_map.to_global(local_pos)

func _world_to_cell(world_pos: Vector3) -> Vector2i:
	var local_pos: Vector3 = grid_map.to_local(world_pos)
	var map_pos: Vector3i = grid_map.local_to_map(local_pos)
	return Vector2i(map_pos.x, map_pos.z)

func _is_cell_blocked(grid_pos: Vector3i) -> bool:
	if map_manager:
		return map_manager.is_tile_blocked(grid_pos)

	var item_index: int = grid_map.get_cell_item(grid_pos)
	return item_index != GridMap.INVALID_CELL_ITEM

func _get_cardinal_string() -> String:
	match current_facing:
		Facing.NORTH:
			return "NORTH"
		Facing.WEST:
			return "WEST"
		Facing.SOUTH:
			return "SOUTH"
		Facing.EAST:
			return "EAST"
	return "NORTH"
