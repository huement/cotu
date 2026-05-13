extends GutTest

const WORLD_SCENE := preload("res://scenes/world/main.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")


func _spawn_world() -> Node3D:
	var world := WORLD_SCENE.instantiate() as Node3D
	add_child_autofree(world)
	return world


func _spawn_enemy_at(cell: Vector2i, facing: GridDefinitions.Facing = GridDefinitions.Facing.WEST) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.initial_cell = cell
	enemy.initial_facing = facing
	return enemy


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _wait_until_not_busy(entity: GridEntity, max_frames: int = 240) -> void:
	for _i in range(max_frames):
		if entity.movement_controller != null and not entity.movement_controller.is_busy:
			return
		await get_tree().process_frame
	fail_test("Timed out waiting for entity command completion")


func _press_world_action(world: Node3D, action_name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	world._unhandled_input(event)


func test_player_passability_blocks_enemy_occupied_cell() -> void:
	var world := _spawn_world()
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player)

	var enemy := _spawn_enemy_at(Vector2i(0, -1))
	world.add_child(enemy)
	await _wait_frames(1)
	world._wire_enemies()
	world._wire_end_conditions()
	await _wait_frames(1)
	assert_true(world.get_enemies().size() > 0)
	assert_eq(enemy.grid_state.cell, Vector2i(0, -1))

	var ok := player.execute_command(GridCommand.Type.STEP_FORWARD)
	assert_false(ok)
	assert_eq(player.grid_state.cell, Vector2i.ZERO)


func test_adjacent_enemy_triggers_combat_state_on_player_action() -> void:
	var world := _spawn_world()
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player)

	var enemy := _spawn_enemy_at(Vector2i(1, 0))
	world.add_child(enemy)
	await _wait_frames(1)
	world._wire_enemies()
	world._wire_end_conditions()
	await _wait_frames(1)
	assert_true(world.get_enemies().size() > 0)
	assert_eq(enemy.grid_state.cell, Vector2i(1, 0))

	assert_true(player.execute_command(GridCommand.Type.TURN_RIGHT))
	await _wait_until_not_busy(player)
	assert_eq(world.current_game_state(), &"combat")
	assert_eq(world.active_overlay_kind(), &"combat")


func test_step_echo_enemy_ai_ticks_after_player_action() -> void:
	var world := _spawn_world()
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player)

	var enemy := _spawn_enemy_at(Vector2i(0, -2), GridDefinitions.Facing.SOUTH)
	world.add_child(enemy)
	await _wait_frames(1)
	world._wire_enemies()
	world._wire_end_conditions()
	await _wait_frames(1)
	assert_true(world.get_enemies().size() > 0)
	assert_eq(enemy.grid_state.cell, Vector2i(0, -2))

	assert_true(player.execute_command(GridCommand.Type.TURN_LEFT))
	await _wait_until_not_busy(player)
	assert_eq(enemy.grid_state.cell, Vector2i(0, -1))


func test_combat_input_submits_intent_and_round_continues_when_enemy_alive() -> void:
	var world := _spawn_world()
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player)

	var enemy := _spawn_enemy_at(Vector2i(1, 0))
	world.add_child(enemy)
	await _wait_frames(1)
	world._wire_enemies()
	world._wire_end_conditions()
	await _wait_frames(1)

	assert_true(player.execute_command(GridCommand.Type.TURN_RIGHT))
	await _wait_until_not_busy(player)
	assert_eq(world.current_game_state(), &"combat")

	_press_world_action(world, &"combat_attack")
	await _wait_frames(1)

	assert_eq(world.current_game_state(), &"combat")
	assert_eq(world.active_overlay_kind(), &"combat")


func test_combat_attack_can_kill_enemy_and_exit_combat() -> void:
	var world := _spawn_world()
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player)

	var enemy := _spawn_enemy_at(Vector2i(1, 0))
	world.add_child(enemy)
	await _wait_frames(1)
	world._wire_enemies()
	world._wire_end_conditions()
	await _wait_frames(1)

	enemy.stats.max_health = 1
	enemy.stats.health = 1
	player.stats.attack = 2

	assert_true(player.execute_command(GridCommand.Type.TURN_RIGHT))
	await _wait_until_not_busy(player)
	assert_eq(world.current_game_state(), &"combat")
	assert_eq(world.active_overlay_kind(), &"combat")

	_press_world_action(world, &"combat_attack")
	await _wait_frames(1)

	assert_true(enemy.stats.is_dead())
	assert_eq(world.current_game_state(), &"gameplay")
	assert_false(world.has_active_overlay())


func test_combat_enemy_attack_can_kill_player_and_fail_run() -> void:
	var world := _spawn_world()
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player)

	var enemy := _spawn_enemy_at(Vector2i(1, 0))
	world.add_child(enemy)
	await _wait_frames(1)
	world._wire_enemies()
	world._wire_end_conditions()
	await _wait_frames(1)

	player.stats.max_health = 1
	player.stats.health = 1
	enemy.stats.attack = 2

	assert_true(player.execute_command(GridCommand.Type.TURN_RIGHT))
	await _wait_until_not_busy(player)
	assert_eq(world.current_game_state(), &"combat")

	_press_world_action(world, &"combat_attack")
	await _wait_frames(1)

	assert_true(player.stats.is_dead())
	assert_eq(world.current_game_state(), &"gameover_failure")


func test_combat_defend_reduces_enemy_damage() -> void:
	var world := _spawn_world()
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player)

	var enemy := _spawn_enemy_at(Vector2i(1, 0))
	world.add_child(enemy)
	await _wait_frames(1)
	world._wire_enemies()
	world._wire_end_conditions()
	await _wait_frames(1)

	player.stats.max_health = 5
	player.stats.health = 5
	enemy.stats.attack = 4

	assert_true(player.execute_command(GridCommand.Type.TURN_RIGHT))
	await _wait_until_not_busy(player)
	assert_eq(world.current_game_state(), &"combat")

	_press_world_action(world, &"combat_defend")
	await _wait_frames(1)

	assert_eq(player.stats.health, 3)


func test_combat_use_item_heals_player_during_round() -> void:
	var world := _spawn_world()
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player)

	var enemy := _spawn_enemy_at(Vector2i(1, 0))
	world.add_child(enemy)
	await _wait_frames(1)
	world._wire_enemies()
	world._wire_end_conditions()
	await _wait_frames(1)

	player.stats.max_health = 8
	player.stats.health = 4
	enemy.stats.attack = 2

	assert_true(player.execute_command(GridCommand.Type.TURN_RIGHT))
	await _wait_until_not_busy(player)
	assert_eq(world.current_game_state(), &"combat")

	_press_world_action(world, &"combat_use_item")
	await _wait_frames(1)

	# use item heals 2, then enemy attack applies 2 damage in same round.
	assert_eq(player.stats.health, 4)
