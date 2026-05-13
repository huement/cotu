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


func test_world_starts_in_gameplay_state_by_default() -> void:
	var world := await _spawn_world()
	assert_eq(world.current_game_state(), &"gameplay")
	assert_true(world.is_gameplay_state_active())


func test_menu_state_blocks_exploration_commands_until_gameplay() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	player.movement_config.smooth_mode = false

	world.go_to_menu()
	assert_eq(world.current_game_state(), &"menu")
	assert_false(world.is_gameplay_state_active())

	var start_cell := player.grid_state.cell
	assert_false(player.execute_action(&"move_forward"))
	assert_eq(player.grid_state.cell, start_cell)

	world.start_gameplay()
	assert_eq(world.current_game_state(), &"gameplay")
	assert_true(player.execute_action(&"move_forward"))


func test_failure_and_success_states_disable_exploration() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	player.movement_config.smooth_mode = false

	world.finish_with_failure()
	assert_eq(world.current_game_state(), &"gameover_failure")
	assert_eq(world.active_overlay_kind(), &"defeat")
	assert_true(world.has_active_overlay())
	assert_false(player.execute_action(&"move_forward"))

	world.start_gameplay()
	assert_true(player.execute_action(&"move_forward"))

	world.finish_with_success()
	assert_eq(world.current_game_state(), &"gameover_success")
	assert_eq(world.active_overlay_kind(), &"victory")
	assert_true(world.has_active_overlay())
	assert_false(player.execute_action(&"move_forward"))


func test_non_gameplay_state_replaces_overlay_with_gameover_overlay() -> void:
	var world := await _spawn_world()
	world.open_inventory_overlay()
	assert_true(world.has_active_overlay())
	assert_eq(world.active_overlay_kind(), &"inventory")

	world.finish_with_failure()
	assert_true(world.has_active_overlay())
	assert_eq(world.active_overlay_kind(), &"defeat")
	assert_eq(world.current_game_state(), &"gameover_failure")


func test_gameover_overlay_restart_signal_returns_to_gameplay() -> void:
	var world := await _spawn_world()
	world.finish_with_failure()
	assert_eq(world.current_game_state(), &"gameover_failure")

	var overlay := world.get_node_or_null("OverlayLayer/OverlayMount/DefeatOverlay") as Control
	assert_not_null(overlay)
	var parent := world.get_parent()
	overlay.emit_signal("restart_requested")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(is_instance_valid(world))
	var replacement := parent.get_node_or_null("Main") as Node3D
	assert_not_null(replacement)
	assert_eq(replacement.current_game_state(), &"gameplay")
	assert_false(replacement.has_active_overlay())
