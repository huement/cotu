class_name MovementController
extends Node

signal action_started(cmd: GridCommand.Type, previous_state: GridState, new_state: GridState, duration: float)
signal action_completed(cmd: GridCommand.Type, new_state: GridState)
signal movement_outcome(outcome)

var grid_state: GridState
var movement_config: MovementConfig
var is_busy: bool = false
var passability_fn: Callable
var _smooth_timer: Timer

var _pending_cmd: GridCommand.Type = GridCommand.Type.STEP_FORWARD
var _pending_previous_state: GridState
var _pending_new_state: GridState
var _pending_outcome_type: String = ""
var _pending_duration: float = 0.0


func _ready() -> void:
	_ensure_smooth_timer()


func _exit_tree() -> void:
	if _smooth_timer != null:
		_smooth_timer.stop()


func execute_command(cmd: GridCommand.Type) -> bool:
	if is_busy or grid_state == null:
		return false

	var previous_state := _clone_state(grid_state)

	if not _is_command_passable(cmd):
		_emit_outcome(cmd, MovementOutcome.TYPE_BLOCKED, MovementOutcome.PHASE_DECISION, previous_state, previous_state, 0.0)
		return false

	is_busy = true
	var outcome_type := _outcome_type_for_command(cmd)

	match cmd:
		GridCommand.Type.STEP_FORWARD:
			grid_state.cell += GridDefinitions.facing_to_vec2i(grid_state.facing)
		GridCommand.Type.STEP_BACK:
			grid_state.cell -= GridDefinitions.facing_to_vec2i(grid_state.facing)
		GridCommand.Type.MOVE_LEFT:
			var left_facing := GridDefinitions.rotate_left(grid_state.facing)
			grid_state.cell += GridDefinitions.facing_to_vec2i(left_facing)
		GridCommand.Type.MOVE_RIGHT:
			var right_facing := GridDefinitions.rotate_right(grid_state.facing)
			grid_state.cell += GridDefinitions.facing_to_vec2i(right_facing)
		GridCommand.Type.TURN_LEFT:
			grid_state.facing = GridDefinitions.rotate_left(grid_state.facing)
		GridCommand.Type.TURN_RIGHT:
			grid_state.facing = GridDefinitions.rotate_right(grid_state.facing)

	var new_state := _clone_state(grid_state)
	var duration := _command_duration(cmd)
	_emit_outcome(cmd, outcome_type, MovementOutcome.PHASE_START, previous_state, new_state, duration)

	if _is_smooth_mode_enabled() and duration > 0.0:
		action_started.emit(cmd, previous_state, new_state, duration)
		_complete_smooth_command(cmd, previous_state, new_state, outcome_type, duration)
	else:
		is_busy = false
		_emit_outcome(cmd, outcome_type, MovementOutcome.PHASE_COMPLETE, previous_state, new_state, duration)
		action_completed.emit(cmd, new_state)

	return true


func _compute_target_cell(cmd: GridCommand.Type) -> Vector2i:
	match cmd:
		GridCommand.Type.STEP_FORWARD:
			return grid_state.cell + GridDefinitions.facing_to_vec2i(grid_state.facing)
		GridCommand.Type.STEP_BACK:
			return grid_state.cell - GridDefinitions.facing_to_vec2i(grid_state.facing)
		GridCommand.Type.MOVE_LEFT:
			return grid_state.cell + GridDefinitions.facing_to_vec2i(GridDefinitions.rotate_left(grid_state.facing))
		GridCommand.Type.MOVE_RIGHT:
			return grid_state.cell + GridDefinitions.facing_to_vec2i(GridDefinitions.rotate_right(grid_state.facing))
		_:
			return grid_state.cell  # turns stay in place


func _is_command_passable(cmd: GridCommand.Type) -> bool:
	match cmd:
		GridCommand.Type.TURN_LEFT, GridCommand.Type.TURN_RIGHT:
			return true
		_:
			if passability_fn.is_null() or not passability_fn.is_valid():
				return true
			return passability_fn.call(_compute_target_cell(cmd))


func _is_smooth_mode_enabled() -> bool:
	return movement_config != null and movement_config.smooth_mode


func _command_duration(cmd: GridCommand.Type) -> float:
	if movement_config == null:
		return 0.0

	match cmd:
		GridCommand.Type.TURN_LEFT, GridCommand.Type.TURN_RIGHT:
			return maxf(movement_config.turn_duration, 0.0)
		_:
			return maxf(movement_config.step_duration, 0.0)


func _clone_state(state: GridState) -> GridState:
	return GridState.new(state.cell, state.facing)


func _complete_smooth_command(
	cmd: GridCommand.Type,
	previous_state: GridState,
	new_state: GridState,
	outcome_type: String,
	duration: float
) -> void:
	_pending_cmd = cmd
	_pending_previous_state = previous_state
	_pending_new_state = new_state
	_pending_outcome_type = outcome_type
	_pending_duration = duration

	_ensure_smooth_timer()
	if _smooth_timer == null:
		return

	_smooth_timer.start(duration)


func _on_smooth_timer_timeout() -> void:
	var completed_cmd := _pending_cmd
	var completed_outcome_type := _pending_outcome_type
	var completed_previous_state := _pending_previous_state
	var completed_new_state := _pending_new_state
	var completed_duration := _pending_duration

	is_busy = false
	_emit_outcome(
		completed_cmd,
		completed_outcome_type,
		MovementOutcome.PHASE_COMPLETE,
		completed_previous_state,
		completed_new_state,
		completed_duration
	)
	action_completed.emit(completed_cmd, completed_new_state)


func _ensure_smooth_timer() -> void:
	if _smooth_timer != null:
		return

	_smooth_timer = Timer.new()
	_smooth_timer.one_shot = true
	add_child(_smooth_timer)
	_smooth_timer.timeout.connect(_on_smooth_timer_timeout)


func _outcome_type_for_command(cmd: GridCommand.Type) -> String:
	match cmd:
		GridCommand.Type.TURN_LEFT, GridCommand.Type.TURN_RIGHT:
			return MovementOutcome.TYPE_TURNED
		_:
			return MovementOutcome.TYPE_MOVED


func _emit_outcome(
	cmd: GridCommand.Type,
	outcome_type: String,
	phase: String,
	state_before: GridState,
	state_after: GridState,
	duration: float
) -> void:
	var outcome := MovementOutcome.new(cmd, outcome_type, phase, state_before, state_after, duration)
	movement_outcome.emit(outcome)
