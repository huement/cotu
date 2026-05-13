extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ACTION_SCRIPT: Array[StringName] = [
	&"move_forward",
	&"turn_right",
	&"move_forward",
	&"move_left",
	&"turn_left",
	&"move_back",
	&"move_right",
]


func _spawn_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.input_actions_enabled = true
	player.debug_log_input_actions = false
	player.movement_config.smooth_mode = false
	return player


func _snapshot_state(player: Player) -> Dictionary:
	return {
		"cell": player.grid_state.cell,
		"facing": player.grid_state.facing,
	}


func _keycode_for_action(action: StringName) -> Key:
	match action:
		&"move_forward":
			return KEY_W
		&"move_back":
			return KEY_S
		&"move_left":
			return KEY_A
		&"move_right":
			return KEY_D
		&"turn_left":
			return KEY_Q
		&"turn_right":
			return KEY_E
		_:
			return KEY_NONE


func _joypad_button_for_action(action: StringName) -> JoyButton:
	match action:
		&"move_forward":
			return JOY_BUTTON_DPAD_UP
		&"move_back":
			return JOY_BUTTON_DPAD_DOWN
		&"move_left":
			return JOY_BUTTON_DPAD_LEFT
		&"move_right":
			return JOY_BUTTON_DPAD_RIGHT
		&"turn_left":
			return JOY_BUTTON_LEFT_SHOULDER
		&"turn_right":
			return JOY_BUTTON_RIGHT_SHOULDER
		_:
			return JOY_BUTTON_INVALID


func _press_keyboard_action(player: Player, action: StringName) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = _keycode_for_action(action)
	event.physical_keycode = event.keycode
	player._unhandled_input(event)


func _press_gamepad_action(player: Player, action: StringName) -> void:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = _joypad_button_for_action(action)
	player._unhandled_input(event)


func _run_script_with_keyboard(player: Player) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for action in ACTION_SCRIPT:
		_press_keyboard_action(player, action)
		states.append(_snapshot_state(player))
	return states


func _run_script_with_gamepad(player: Player) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for action in ACTION_SCRIPT:
		_press_gamepad_action(player, action)
		states.append(_snapshot_state(player))
	return states


func _run_script_with_ui_harness(player: Player) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for action in ACTION_SCRIPT:
		assert_true(player.execute_action(action), "UI harness failed action: %s" % [action])
		states.append(_snapshot_state(player))
	return states


func test_keyboard_gamepad_and_ui_harness_share_identical_state_history() -> void:
	var keyboard_player := _spawn_player()
	var gamepad_player := _spawn_player()
	var ui_player := _spawn_player()

	var keyboard_states := _run_script_with_keyboard(keyboard_player)
	var gamepad_states := _run_script_with_gamepad(gamepad_player)
	var ui_states := _run_script_with_ui_harness(ui_player)

	assert_eq(gamepad_states, keyboard_states)
	assert_eq(ui_states, keyboard_states)
	assert_eq(keyboard_player.grid_state.cell, Vector2i(2, -1))
	assert_eq(keyboard_player.grid_state.facing, GridDefinitions.Facing.NORTH)


func test_input_actions_enabled_false_blocks_keyboard_gamepad_and_ui_harness() -> void:
	var keyboard_player := _spawn_player()
	keyboard_player.input_actions_enabled = false
	_press_keyboard_action(keyboard_player, &"move_forward")
	assert_eq(keyboard_player.grid_state.cell, Vector2i.ZERO)
	assert_eq(keyboard_player.grid_state.facing, GridDefinitions.Facing.NORTH)

	var gamepad_player := _spawn_player()
	gamepad_player.input_actions_enabled = false
	_press_gamepad_action(gamepad_player, &"move_forward")
	assert_eq(gamepad_player.grid_state.cell, Vector2i.ZERO)
	assert_eq(gamepad_player.grid_state.facing, GridDefinitions.Facing.NORTH)

	var ui_player := _spawn_player()
	ui_player.input_actions_enabled = false
	assert_false(ui_player.execute_action(&"move_forward"))
	assert_eq(ui_player.grid_state.cell, Vector2i.ZERO)
	assert_eq(ui_player.grid_state.facing, GridDefinitions.Facing.NORTH)
