class_name GridEntity
extends Node3D

signal command_completed(cmd: GridCommand.Type, new_state: GridState)

const INVALID_COMMAND := -1

@export var movement_config: MovementConfig
@export var initial_cell: Vector2i = Vector2i.ZERO
@export var initial_facing: GridDefinitions.Facing = GridDefinitions.Facing.NORTH

var grid_state: GridState
var movement_controller: MovementController
var stats: CharacterStats

var command_processing_enabled: bool = true
var _queued_command: int = INVALID_COMMAND


func _ready() -> void:
	if movement_config == null:
		movement_config = MovementConfig.new()

	if stats == null:
		stats = CharacterStats.new()

	grid_state = GridState.new(initial_cell, initial_facing)
	_apply_canonical_transform()

	movement_controller = MovementController.new()
	movement_controller.grid_state = grid_state
	movement_controller.movement_config = movement_config
	add_child(movement_controller)

	movement_controller.action_completed.connect(_on_action_completed)


func execute_command(cmd: GridCommand.Type) -> bool:
	if movement_controller == null:
		return false

	if not command_processing_enabled:
		return false

	if movement_controller.is_busy:
		return _enqueue_command(cmd)

	return movement_controller.execute_command(cmd)


func pause_commands() -> void:
	command_processing_enabled = false


func resume_commands() -> void:
	command_processing_enabled = true
	_drain_queued_command()


func _apply_canonical_transform() -> void:
	if grid_state == null or movement_config == null:
		return
	var world_pos := GridMapper.cell_to_world(grid_state.cell, movement_config.cell_size, 0.0)
	global_position = world_pos
	rotation_degrees.y = -float(grid_state.facing) * 90.0


# Virtual — subclasses must call super()
func _on_action_completed(cmd: GridCommand.Type, new_state: GridState) -> void:
	grid_state = new_state
	_apply_canonical_transform()
	command_completed.emit(cmd, new_state)
	_drain_queued_command()


func _enqueue_command(cmd: GridCommand.Type) -> bool:
	if _queued_command != INVALID_COMMAND:
		return false
	_queued_command = int(cmd)
	return true


func _drain_queued_command() -> void:
	if _queued_command == INVALID_COMMAND:
		return

	if not command_processing_enabled:
		return

	if movement_controller == null or movement_controller.is_busy:
		return

	var queued_cmd := _queued_command
	_queued_command = INVALID_COMMAND
	movement_controller.execute_command(queued_cmd as GridCommand.Type)
