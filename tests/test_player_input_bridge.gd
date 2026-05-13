extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _spawn_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.input_actions_enabled = true
	player.debug_log_input_actions = false
	player.movement_config.smooth_mode = false
	return player


func _press_action(player: Player, action_name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	player._unhandled_input(event)


func _wait_until_not_busy(player: Player, max_frames: int = 180) -> void:
	for _i in range(max_frames):
		if not player.movement_controller.is_busy:
			return
		await get_tree().process_frame
	fail_test("Timed out waiting for smooth input action completion")


func test_input_action_move_forward_executes_player_command() -> void:
	var player := _spawn_player()

	_press_action(player, &"move_forward")

	assert_eq(player.grid_state.cell, Vector2i(0, -1))
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.NORTH)


func test_input_action_turn_right_updates_facing_only() -> void:
	var player := _spawn_player()

	_press_action(player, &"turn_right")

	assert_eq(player.grid_state.cell, Vector2i.ZERO)
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.EAST)


func test_smooth_input_queues_overlap_and_preserves_order() -> void:
	var player := _spawn_player()
	player.movement_config.smooth_mode = true
	player.movement_config.step_duration = 0.06
	player.movement_config.turn_duration = 0.04

	_press_action(player, &"move_forward")
	var during_busy_cell := player.grid_state.cell
	_press_action(player, &"turn_right")
	_press_action(player, &"turn_left")

	assert_true(player.movement_controller.is_busy)
	assert_eq(player.grid_state.cell, during_busy_cell)
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.NORTH)

	await _wait_until_not_busy(player)
	assert_eq(player.grid_state.cell, Vector2i(0, -1))
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.EAST)
