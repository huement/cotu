extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _make_controller(smooth_mode: bool = false, step_duration: float = 0.03, turn_duration: float = 0.02) -> MovementController:
	var cfg := MovementConfig.new()
	cfg.smooth_mode = smooth_mode
	cfg.step_duration = step_duration
	cfg.turn_duration = turn_duration

	var state := GridState.new(Vector2i.ZERO, GridDefinitions.Facing.NORTH)

	var mc: MovementController = add_child_autofree(MovementController.new())
	mc.movement_config = cfg
	mc.grid_state = state
	return mc


func _wait_until_not_busy(mc: MovementController, max_frames: int = 240) -> void:
	for _i in range(max_frames):
		if not mc.is_busy:
			return
		await get_tree().process_frame
	fail_test("Timed out waiting for smooth command completion")


func _spawn_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.input_actions_enabled = true
	player.movement_config.smooth_mode = false
	return player


func _serialize_outcome(outcome: MovementOutcome) -> Dictionary:
	return {
		"command": int(outcome.command),
		"outcome_type": outcome.outcome_type,
		"phase": outcome.phase,
		"before_cell": outcome.state_before.cell,
		"before_facing": int(outcome.state_before.facing),
		"after_cell": outcome.state_after.cell,
		"after_facing": int(outcome.state_after.facing),
		"duration": outcome.duration,
	}


func test_blocked_step_emits_decision_and_preserves_state() -> void:
	var mc := _make_controller(false)
	mc.passability_fn = func(_cell: Vector2i) -> bool: return false

	var outcomes: Array[MovementOutcome] = []
	mc.movement_outcome.connect(func(outcome: MovementOutcome) -> void:
		outcomes.append(outcome)
	)

	var ok := mc.execute_command(GridCommand.Type.STEP_FORWARD)

	assert_false(ok)
	assert_eq(outcomes.size(), 1)
	assert_eq(outcomes[0].outcome_type, MovementOutcome.TYPE_BLOCKED)
	assert_eq(outcomes[0].phase, MovementOutcome.PHASE_DECISION)
	assert_eq(outcomes[0].duration, 0.0)
	assert_eq(outcomes[0].state_before.cell, Vector2i.ZERO)
	assert_eq(outcomes[0].state_after.cell, Vector2i.ZERO)
	assert_eq(outcomes[0].state_before.facing, GridDefinitions.Facing.NORTH)
	assert_eq(outcomes[0].state_after.facing, GridDefinitions.Facing.NORTH)
	assert_eq(mc.grid_state.cell, Vector2i.ZERO)
	assert_eq(mc.grid_state.facing, GridDefinitions.Facing.NORTH)


func test_snap_turn_emits_start_then_complete_with_stable_payload_shape() -> void:
	var mc := _make_controller(false)

	var outcomes: Array[MovementOutcome] = []
	mc.movement_outcome.connect(func(outcome: MovementOutcome) -> void:
		outcomes.append(outcome)
	)

	var ok := mc.execute_command(GridCommand.Type.TURN_RIGHT)

	assert_true(ok)
	assert_eq(outcomes.size(), 2)
	assert_eq(outcomes[0].phase, MovementOutcome.PHASE_START)
	assert_eq(outcomes[1].phase, MovementOutcome.PHASE_COMPLETE)
	assert_eq(outcomes[0].outcome_type, MovementOutcome.TYPE_TURNED)
	assert_eq(outcomes[1].outcome_type, MovementOutcome.TYPE_TURNED)
	var keys_a := _serialize_outcome(outcomes[0]).keys()
	var keys_b := _serialize_outcome(outcomes[1]).keys()
	keys_a.sort()
	keys_b.sort()
	assert_eq(keys_a, keys_b)
	assert_eq(outcomes[0].state_before.facing, GridDefinitions.Facing.NORTH)
	assert_eq(outcomes[1].state_after.facing, GridDefinitions.Facing.EAST)


func test_smooth_move_emits_start_then_complete() -> void:
	var mc := _make_controller(true, 0.04, 0.03)

	var phases: Array[String] = []
	mc.movement_outcome.connect(func(outcome: MovementOutcome) -> void:
		phases.append(outcome.phase)
	)

	assert_true(mc.execute_command(GridCommand.Type.STEP_FORWARD))
	await _wait_until_not_busy(mc)

	assert_eq(phases, [MovementOutcome.PHASE_START, MovementOutcome.PHASE_COMPLETE])


func _run_mixed_commands_with_seed(seed_value: int) -> Array[Dictionary]:
	var mc := _make_controller(false)
	var blocked_cells := {
		Vector2i(1, 0): true,
		Vector2i(-1, 0): true,
		Vector2i(0, -2): true,
		Vector2i(2, -1): true,
		Vector2i(-2, 1): true,
	}
	mc.passability_fn = func(cell: Vector2i) -> bool:
		return not blocked_cells.has(cell)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var commands: Array[GridCommand.Type] = [
		GridCommand.Type.STEP_FORWARD,
		GridCommand.Type.STEP_BACK,
		GridCommand.Type.MOVE_LEFT,
		GridCommand.Type.MOVE_RIGHT,
		GridCommand.Type.TURN_LEFT,
		GridCommand.Type.TURN_RIGHT,
	]

	var event_log: Array[Dictionary] = []
	mc.movement_outcome.connect(func(outcome: MovementOutcome) -> void:
		event_log.append(_serialize_outcome(outcome))
	)

	for _i in range(200):
		var cmd: GridCommand.Type = commands[rng.randi_range(0, commands.size() - 1)]
		mc.execute_command(cmd)

	return event_log


func test_200_mixed_actions_event_log_is_deterministic_and_blocked_preserves_state() -> void:
	var log_a := _run_mixed_commands_with_seed(1337)
	var log_b := _run_mixed_commands_with_seed(1337)

	assert_eq(log_a, log_b)
	assert_gt(log_a.size(), 0)

	for event in log_a:
		if event["outcome_type"] == MovementOutcome.TYPE_BLOCKED:
			assert_eq(event["before_cell"], event["after_cell"])
			assert_eq(event["before_facing"], event["after_facing"])


func test_player_blocked_feedback_animates_and_returns_to_canonical_position() -> void:
	var player := _spawn_player()
	player.movement_config.blocked_feedback_enabled = true
	player.movement_config.blocked_bump_distance = 0.1
	player.movement_config.blocked_bump_duration = 0.08
	player.movement_controller.passability_fn = func(_cell: Vector2i) -> bool: return false

	var canonical_pos := player.global_position
	var ok := player.execute_command(GridCommand.Type.STEP_FORWARD)

	assert_false(ok)
	assert_eq(player.grid_state.cell, Vector2i.ZERO)
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.NORTH)

	await get_tree().process_frame
	assert_true(player.global_position.distance_to(canonical_pos) > 0.0001)

	for _i in range(12):
		await get_tree().process_frame

	assert_eq(player.grid_state.cell, Vector2i.ZERO)
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.NORTH)
	assert_eq(player.global_position, canonical_pos)


func test_player_blocked_strafe_emits_cue_without_positional_bump() -> void:
	var player := _spawn_player()
	player.movement_config.blocked_feedback_enabled = true
	player.movement_config.blocked_bump_distance = 0.1
	player.movement_config.blocked_bump_duration = 0.08
	player.movement_controller.passability_fn = func(_cell: Vector2i) -> bool: return false

	var cue_commands: Array[GridCommand.Type] = []
	player.blocked_feedback_cue.connect(func(cmd: GridCommand.Type) -> void:
		cue_commands.append(cmd)
	)

	var canonical_pos := player.global_position
	var ok := player.execute_command(GridCommand.Type.MOVE_LEFT)

	assert_false(ok)
	assert_eq(cue_commands.size(), 1)
	assert_eq(cue_commands[0], GridCommand.Type.MOVE_LEFT)
	assert_eq(player.global_position, canonical_pos)
	assert_eq(player.grid_state.cell, Vector2i.ZERO)
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.NORTH)
