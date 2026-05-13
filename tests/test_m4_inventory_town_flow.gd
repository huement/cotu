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
		if player.movement_controller != null and not player.movement_controller.is_busy:
			return
		await get_tree().process_frame
	fail_test("Timed out waiting for movement controller to become idle")


func _make_item(item_name: String, effects: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.item_name = item_name
	item.stat_effect = effects
	item.item_type = ItemData.ItemType.CONSUMABLE
	return item


func test_world_pickup_collects_item_into_player_inventory() -> void:
	var world := await _spawn_world()
	var player := _player(world)
	player.movement_config.smooth_mode = false

	var pickup := WorldPickup.new()
	pickup.grid_cell = Vector2i(0, -1)
	pickup.item_data = _make_item("Potion", {"heal": 2})
	world.add_child(pickup)
	await get_tree().process_frame

	assert_eq(player.inventory.size(), 0)
	assert_true(player.execute_action(&"move_forward"))
	await _wait_until_not_busy(player)
	await get_tree().process_frame

	assert_eq(player.grid_state.cell, Vector2i(0, -1))
	assert_eq(player.inventory.size(), 1)
	assert_false(is_instance_valid(pickup))


func test_inventory_overlay_uses_selected_item() -> void:
	var world := await _spawn_world()
	var player := _player(world)

	player.stats.take_damage(5)
	assert_eq(player.stats.health, 5)
	assert_true(player.add_item(_make_item("Potion", {"heal": 3})))

	world.open_inventory_overlay()
	await get_tree().process_frame

	var item_list := world.get_node_or_null("OverlayLayer/OverlayMount/InventoryOverlay/InventoryCenter/InventoryPanel/InventoryMargin/InventoryVBox/InventoryItemList") as ItemList
	var use_button := world.get_node_or_null("OverlayLayer/OverlayMount/InventoryOverlay/InventoryCenter/InventoryPanel/InventoryMargin/InventoryVBox/InventoryActionsRow/InventoryUseButton") as Button
	assert_not_null(item_list)
	assert_not_null(use_button)
	assert_eq(item_list.item_count, 1)

	item_list.select(0)
	use_button.emit_signal("pressed")
	await get_tree().process_frame

	assert_eq(player.stats.health, 8)
	assert_eq(player.inventory.size(), 0)


func test_town_overlay_rest_restores_hp_to_max() -> void:
	var world := await _spawn_world()
	var player := _player(world)

	player.stats.take_damage(4)
	assert_eq(player.stats.health, 6)

	world.open_town_overlay()
	await get_tree().process_frame

	var rest_button := world.get_node_or_null("OverlayLayer/OverlayMount/TownOverlay/Center/Panel/Margin/VBox/Actions/TownRestButton") as Button
	assert_not_null(rest_button)
	rest_button.emit_signal("pressed")
	await get_tree().process_frame

	assert_eq(player.stats.health, player.stats.max_health)
