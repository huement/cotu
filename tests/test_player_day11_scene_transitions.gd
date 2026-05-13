extends GutTest

const WORLD_SCENE := preload("res://scenes/world/main.tscn")


func _spawn_world() -> Node3D:
	var world := WORLD_SCENE.instantiate() as Node3D
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	return world


func _player(world: Node3D) -> Player:
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player, "Manual test world must include Player")
	return player


func _wait_until_not_busy(player: Player, max_frames: int = 240) -> void:
	for _i in range(max_frames):
		if not player.movement_controller.is_busy:
			return
		await get_tree().process_frame
	fail_test("Timed out waiting for movement controller to become idle")


func _press_action(target: Node, action_name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	target._unhandled_input(event)


func test_overlay_blocks_exploration_until_close() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	player.movement_config.smooth_mode = false

	world.open_inventory_overlay()
	assert_true(world.has_active_overlay())

	var start_cell := player.grid_state.cell
	assert_false(player.execute_action(&"move_forward"))
	assert_false(player.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_eq(player.grid_state.cell, start_cell)

	world.close_active_overlay()
	assert_false(world.has_active_overlay())

	assert_true(player.execute_action(&"move_forward"))
	assert_eq(player.grid_state.cell, Vector2i(0, -1))


func test_busy_queue_is_preserved_across_overlay_and_runs_once_on_resume() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	player.movement_config.smooth_mode = true
	player.movement_config.step_duration = 0.04
	player.movement_config.turn_duration = 0.03

	assert_true(player.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_true(player.execute_command(GridCommand.Type.TURN_RIGHT))

	world.open_inventory_overlay()
	assert_true(world.has_active_overlay())
	assert_false(player.execute_action(&"turn_left"))

	await _wait_until_not_busy(player)
	assert_eq(player.grid_state.cell, Vector2i(0, -1))
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.NORTH)

	world.close_active_overlay()
	await _wait_until_not_busy(player)

	assert_eq(player.grid_state.cell, Vector2i(0, -1))
	assert_eq(player.grid_state.facing, GridDefinitions.Facing.EAST)


func test_action_and_debug_button_triggers_open_expected_overlay() -> void:
	var world := await _spawn_world()

	_press_action(world, &"open_town")
	assert_true(world.has_active_overlay())
	assert_eq(world.active_overlay_kind(), &"town")

	world.close_active_overlay()
	assert_false(world.has_active_overlay())

	var open_inventory := world.get_node_or_null("OverlayLayer/DebugPanel/Margin/VBox/OpenInventory") as Button
	assert_not_null(open_inventory)
	open_inventory.emit_signal("pressed")

	assert_true(world.has_active_overlay())
	assert_eq(world.active_overlay_kind(), &"inventory")

	var close_overlay := world.get_node_or_null("OverlayLayer/DebugPanel/Margin/VBox/CloseOverlay") as Button
	assert_not_null(close_overlay)
	close_overlay.emit_signal("pressed")
	assert_false(world.has_active_overlay())


func test_minimap_remains_visible_while_modal_overlay_opens_and_closes() -> void:
	var world := await _spawn_world()
	var minimap := world.get_node_or_null("OverlayLayer/MinimapOverlay") as Control
	var toggle_minimap := world.get_node_or_null("OverlayLayer/DebugPanel/Margin/VBox/ToggleMinimap") as Button
	assert_not_null(minimap)
	assert_not_null(toggle_minimap)

	assert_false(minimap.visible)
	toggle_minimap.emit_signal("pressed")
	assert_true(minimap.visible)

	world.open_inventory_overlay()
	assert_true(world.has_active_overlay())
	assert_true(minimap.visible)

	world.close_active_overlay()
	assert_false(world.has_active_overlay())
	assert_true(minimap.visible)
