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
	if enemy.stats == null:
		enemy.stats = CharacterStats.new()
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


func _enter_combat_with_single_enemy(world: Node3D, enemy: Enemy, player: Player) -> void:
	world.add_child(enemy)
	await _wait_frames(1)
	world._wire_enemies()
	world._wire_end_conditions()
	await _wait_frames(1)

	assert_true(player.execute_command(GridCommand.Type.TURN_RIGHT))
	await _wait_until_not_busy(player)
	assert_eq(world.current_game_state(), &"combat")
	assert_eq(world.active_overlay_kind(), &"combat")


func test_combat_overlay_displays_and_updates_player_hp() -> void:
	var world := _spawn_world()
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player)

	var enemy := _spawn_enemy_at(Vector2i(1, 0))
	enemy.stats.attack = 2
	await _enter_combat_with_single_enemy(world, enemy, player)

	var hp_label := world.get_node_or_null("OverlayLayer/OverlayMount/CombatOverlay/Center/Panel/Margin/VBox/PlayerHP") as Label
	assert_not_null(hp_label)
	assert_string_contains(hp_label.text, "10/10")

	_press_world_action(world, &"combat_attack")
	await _wait_frames(2)

	assert_string_contains(hp_label.text, "8/10")


func test_combat_win_returns_to_gameplay_and_resumes_exploration() -> void:
	var world := _spawn_world()
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player)

	var enemy := _spawn_enemy_at(Vector2i(1, 0))
	enemy.stats.max_health = 1
	enemy.stats.health = 1
	player.stats.attack = 2
	await _enter_combat_with_single_enemy(world, enemy, player)

	_press_world_action(world, &"combat_attack")
	await _wait_frames(1)

	assert_eq(world.current_game_state(), &"gameplay")
	assert_false(world.has_active_overlay())
	assert_true(player.execute_action(&"turn_left"))


func test_combat_loss_transitions_to_failure_state() -> void:
	var world := _spawn_world()
	var player := world.get_node_or_null("Player") as Player
	assert_not_null(player)

	var enemy := _spawn_enemy_at(Vector2i(1, 0))
	player.stats.max_health = 1
	player.stats.health = 1
	enemy.stats.attack = 2
	await _enter_combat_with_single_enemy(world, enemy, player)

	_press_world_action(world, &"combat_attack")
	await _wait_frames(1)

	assert_eq(world.current_game_state(), &"gameover_failure")
	assert_eq(world.active_overlay_kind(), &"defeat")
