extends GutTest

const WORLD_SCENE := preload("res://scenes/world/main.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const WORLD_EXIT_SCRIPT := preload("res://components/world_exit.gd")


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


func _clear_world_enemies(world: Node3D) -> void:
	for enemy in world.get_enemies():
		if enemy == null:
			continue
		enemy.queue_free()
	await get_tree().process_frame
	world._wire_enemies()
	await get_tree().process_frame


func _spawn_enemy_at(cell: Vector2i) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.initial_cell = cell
	return enemy


func _add_exit(world: Node3D, cell: Vector2i, requires_cleared_floor: bool = true) -> Node3D:
	var exit := WORLD_EXIT_SCRIPT.new()
	exit.grid_cell = cell
	exit.requires_cleared_floor = requires_cleared_floor
	world.add_child(exit)
	return exit


func test_reaching_active_exit_triggers_victory_overlay() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	player.movement_config.smooth_mode = false
	player.movement_controller.passability_fn = Callable()
	await _clear_world_enemies(world)

	_add_exit(world, Vector2i(0, -1))
	world.failure_goal_cell = Vector2i(99, 99)
	world.start_gameplay()

	assert_true(player.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_eq(world.current_game_state(), &"gameover_success")
	assert_eq(world.active_overlay_kind(), &"victory")
	assert_true(world.has_active_overlay())


func test_exit_stays_locked_while_any_enemy_remains() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	player.movement_config.smooth_mode = false
	player.movement_controller.passability_fn = Callable()
	await _clear_world_enemies(world)

	world.add_child(_spawn_enemy_at(Vector2i(4, 4)))
	_add_exit(world, Vector2i(0, -1))
	world.failure_goal_cell = Vector2i(99, 99)
	world._wire_enemies()
	await get_tree().process_frame
	world.start_gameplay()

	assert_true(player.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_eq(world.current_game_state(), &"gameplay")
	assert_false(world.has_active_overlay())


func test_reaching_failure_goal_cell_triggers_defeat_overlay() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	player.movement_config.smooth_mode = false
	player.movement_controller.passability_fn = Callable()
	await _clear_world_enemies(world)

	world.failure_goal_cell = Vector2i(0, 1)
	world.start_gameplay()

	assert_true(player.execute_command(GridCommand.Type.STEP_BACK))
	assert_eq(world.current_game_state(), &"gameover_failure")
	assert_eq(world.active_overlay_kind(), &"defeat")
	assert_true(world.has_active_overlay())


func test_disabled_end_conditions_do_not_change_state() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	player.movement_config.smooth_mode = false
	player.movement_controller.passability_fn = Callable()
	await _clear_world_enemies(world)

	world.enable_cell_end_conditions = false
	_add_exit(world, Vector2i(0, -1))
	world.failure_goal_cell = Vector2i(0, 1)
	world.start_gameplay()

	assert_true(player.execute_command(GridCommand.Type.STEP_FORWARD))
	assert_eq(world.current_game_state(), &"gameplay")
	assert_false(world.has_active_overlay())
