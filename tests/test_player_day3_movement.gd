extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _spawn_player(smooth_mode: bool = false, step_duration: float = 0.03, turn_duration: float = 0.02) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.movement_config.smooth_mode = smooth_mode
	player.movement_config.step_duration = step_duration
	player.movement_config.turn_duration = turn_duration
	return player


func _wait_until_not_busy(player: Player, max_frames: int = 180) -> void:
	for _i in range(max_frames):
		if not player.movement_controller.is_busy:
			return
		await get_tree().process_frame
	fail_test("Timed out waiting for smooth action completion")


func test_step_forward_advances_cell() -> void:
	var player := _spawn_player()

	var executed := player.execute_command(GridCommand.Type.STEP_FORWARD)

	assert_true(executed)
	assert_eq(player.grid_state.cell, Vector2i(0, -1))


func test_step_back_retreats_cell() -> void:
	var player := _spawn_player()

	var executed := player.execute_command(GridCommand.Type.STEP_BACK)

	assert_true(executed)
	assert_eq(player.grid_state.cell, Vector2i(0, 1))


func test_strafe_left_moves_perpendicular() -> void:
	var player := _spawn_player()

	var executed := player.execute_command(GridCommand.Type.MOVE_LEFT)

	assert_true(executed)
	assert_eq(player.grid_state.cell, Vector2i(-1, 0))


func test_strafe_right_moves_perpendicular() -> void:
	var player := _spawn_player()

	var executed := player.execute_command(GridCommand.Type.MOVE_RIGHT)

	assert_true(executed)
	assert_eq(player.grid_state.cell, Vector2i(1, 0))


func test_turn_left_updates_facing() -> void:
	var player := _spawn_player()

	var executed := player.execute_command(GridCommand.Type.TURN_LEFT)

	assert_true(executed)
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.WEST)


func test_turn_right_updates_facing() -> void:
	var player := _spawn_player()

	var executed := player.execute_command(GridCommand.Type.TURN_RIGHT)

	assert_true(executed)
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.EAST)


func test_transform_sync_after_command() -> void:
	var player := _spawn_player()

	var executed := player.execute_command(GridCommand.Type.STEP_FORWARD)
	var expected_pos := GridMapper.cell_to_world(player.grid_state.cell, player.movement_config.cell_size, 0.0)

	assert_true(executed)
	assert_eq(player.global_position, expected_pos)


func test_scripted_sequence_yields_expected_final_state() -> void:
	var player := _spawn_player()

	assert_true(player.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_true(player.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_true(player.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_true(player.execute_command(GridCommand.Type.TURN_LEFT))
	assert_true(player.execute_command(GridCommand.Type.STEP_BACK))

	assert_eq(player.grid_state.cell, Vector2i(1, 0))
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.NORTH)
	assert_eq(player.global_position, Vector3(1.0, 0.0, 0.0))


func test_execute_command_queues_one_command_while_busy() -> void:
	var player := _spawn_player()

	player.movement_controller.is_busy = true
	var before_cell := player.grid_state.cell
	var before_facing := player.grid_state.facing

	var accepted := player.execute_command(GridCommand.Type.STEP_FORWARD)
	var dropped := player.execute_command(GridCommand.Type.TURN_RIGHT)

	assert_true(accepted)
	assert_false(dropped)
	assert_eq(player.grid_state.cell, before_cell)
	assert_eq(player.grid_state.facing, before_facing)


func test_smooth_mode_single_step_reaches_expected_state() -> void:
	var player := _spawn_player(true)

	var executed := player.execute_command(GridCommand.Type.STEP_FORWARD)

	assert_true(executed)
	assert_true(player.movement_controller.is_busy)
	await _wait_until_not_busy(player)
	assert_eq(player.grid_state.cell, Vector2i(0, -1))
	assert_eq(player.global_position, Vector3(0.0, 0.0, -1.0))


func test_smooth_mode_turn_reaches_expected_facing_and_yaw() -> void:
	var player := _spawn_player(true)

	var executed := player.execute_command(GridCommand.Type.TURN_LEFT)

	assert_true(executed)
	assert_true(player.movement_controller.is_busy)
	await _wait_until_not_busy(player)
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.WEST)
	assert_eq(player.rotation_degrees.y, -270.0)


func test_smooth_mode_queues_overlap_and_executes_in_order() -> void:
	var player := _spawn_player(true, 0.06, 0.04)

	assert_true(player.execute_command(GridCommand.Type.STEP_FORWARD))
	var queued_execute := player.execute_command(GridCommand.Type.TURN_RIGHT)
	var dropped_execute := player.execute_command(GridCommand.Type.TURN_LEFT)

	assert_true(queued_execute)
	assert_false(dropped_execute)
	await _wait_until_not_busy(player)
	assert_eq(player.grid_state.cell, Vector2i(0, -1))
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.EAST)


func test_snap_and_smooth_modes_match_for_scripted_sequence() -> void:
	var snap_player := _spawn_player(false)
	var smooth_player := _spawn_player(true)
	var script: Array[GridCommand.Type] = [
		GridCommand.Type.STEP_FORWARD,
		GridCommand.Type.TURN_RIGHT,
		GridCommand.Type.STEP_FORWARD,
		GridCommand.Type.TURN_LEFT,
		GridCommand.Type.STEP_BACK,
	]

	for cmd in script:
		assert_true(snap_player.execute_command(cmd))
		assert_true(smooth_player.execute_command(cmd))
		await _wait_until_not_busy(smooth_player)

	assert_eq(smooth_player.grid_state.cell, snap_player.grid_state.cell)
	assert_eq(smooth_player.grid_state.facing, snap_player.grid_state.facing)
	assert_eq(smooth_player.global_position, snap_player.global_position)
	assert_eq(smooth_player.rotation_degrees.y, snap_player.rotation_degrees.y)
