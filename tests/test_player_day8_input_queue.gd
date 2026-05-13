extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _spawn_player(step_duration: float = 0.05, turn_duration: float = 0.04) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.input_actions_enabled = true
	player.debug_log_input_actions = false
	player.movement_config.smooth_mode = true
	player.movement_config.step_duration = step_duration
	player.movement_config.turn_duration = turn_duration
	return player


func _wait_until_not_busy(player: Player, max_frames: int = 240) -> void:
	for _i in range(max_frames):
		if not player.movement_controller.is_busy:
			return
		await get_tree().process_frame
	fail_test("Timed out waiting for queued commands to finish")


func _press_action(player: Player, action_name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	player._unhandled_input(event)


func test_busy_state_accepts_one_queued_and_drops_extra_inputs() -> void:
	var player := _spawn_player()

	assert_true(player.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_true(player.execute_command(GridCommand.Type.TURN_RIGHT))
	assert_false(player.execute_command(GridCommand.Type.TURN_LEFT))

	await _wait_until_not_busy(player)
	assert_eq(player.grid_state.cell, Vector2i(0, -1))
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.EAST)


func test_input_actions_held_stress_keeps_order_without_double_executes() -> void:
	var player := _spawn_player(0.04, 0.03)
	var completed: Array[GridCommand.Type] = []
	player.movement_controller.action_completed.connect(func(cmd: GridCommand.Type, _new_state: GridState) -> void:
		completed.append(cmd)
	)

	_press_action(player, &"move_forward")
	_press_action(player, &"turn_right")
	_press_action(player, &"move_forward")
	_press_action(player, &"turn_left")

	await _wait_until_not_busy(player)

	var expected: Array[GridCommand.Type] = [
		GridCommand.Type.STEP_FORWARD,
		GridCommand.Type.TURN_RIGHT,
	]

	assert_eq(completed, expected)
	assert_eq(player.grid_state.cell, Vector2i(0, -1))
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.EAST)
