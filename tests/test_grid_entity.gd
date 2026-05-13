extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _spawn_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	return player


func _wait_until_not_busy(entity: GridEntity, max_frames: int = 180) -> void:
	for _i in range(max_frames):
		if not entity.movement_controller.is_busy:
			return
		await get_tree().process_frame
	fail_test("Timed out waiting for entity to finish command")


# --- GridEntity base behaviour via Player ---

func test_stats_initialised_on_ready() -> void:
	var player := _spawn_player()
	assert_not_null(player.stats)
	assert_eq(player.stats.health, player.stats.max_health)


func test_execute_command_moves_cell() -> void:
	var player := _spawn_player()
	assert_true(player.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_eq(player.grid_state.cell, Vector2i(0, -1))


func test_execute_command_blocked_while_paused() -> void:
	var player := _spawn_player()
	player.pause_commands()
	assert_false(player.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_eq(player.grid_state.cell, Vector2i.ZERO)


func test_resume_commands_re_enables_execution() -> void:
	var player := _spawn_player()
	player.pause_commands()
	player.resume_commands()
	assert_true(player.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_eq(player.grid_state.cell, Vector2i(0, -1))


func test_queue_accepts_one_command_while_busy() -> void:
	var player := _spawn_player()
	player.movement_config.smooth_mode = true
	player.movement_config.step_duration = 0.05
	player.movement_config.turn_duration = 0.04

	assert_true(player.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_true(player.movement_controller.is_busy)

	var queued := player.execute_command(GridCommand.Type.TURN_RIGHT)
	var dropped := player.execute_command(GridCommand.Type.TURN_LEFT)

	assert_true(queued)
	assert_false(dropped)

	await _wait_until_not_busy(player)
	assert_eq(player.grid_state.cell, Vector2i(0, -1))
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.EAST)


func test_canonical_transform_applied_after_command() -> void:
	var player := _spawn_player()
	player.execute_command(GridCommand.Type.STEP_FORWARD)
	var expected_pos := GridMapper.cell_to_world(player.grid_state.cell, player.movement_config.cell_size, 0.0)
	assert_eq(player.global_position, expected_pos)


func test_command_completed_signal_emitted() -> void:
	var player := _spawn_player()
	watch_signals(player)
	player.execute_command(GridCommand.Type.TURN_RIGHT)
	assert_signal_emitted(player, "command_completed")


func test_pause_exploration_commands_blocks_input_and_execution() -> void:
	var player := _spawn_player()
	player.pause_exploration_commands()
	assert_false(player.input_actions_enabled)
	assert_false(player.command_processing_enabled)


func test_resume_exploration_commands_restores_input_and_execution() -> void:
	var player := _spawn_player()
	player.pause_exploration_commands()
	player.resume_exploration_commands()
	assert_true(player.input_actions_enabled)
	assert_true(player.command_processing_enabled)
