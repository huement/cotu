extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _spawn_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	return player


func _make_item(item_name: String, effects: Dictionary, item_type: int = ItemData.ItemType.CONSUMABLE):
	var item := ItemData.new()
	item.item_name = item_name
	item.stat_effect = effects
	item.item_type = item_type as ItemData.ItemType
	return item


func test_player_initializes_inventory() -> void:
	var player := _spawn_player()
	assert_not_null(player.inventory)
	assert_eq(player.inventory.size(), 0)


func test_add_and_remove_item_through_player() -> void:
	var player := _spawn_player()
	var potion: Variant = _make_item("Potion", {"heal": 2})

	assert_true(player.add_item(potion))
	assert_eq(player.inventory.size(), 1)
	assert_true(player.remove_item(potion))
	assert_eq(player.inventory.size(), 0)


func test_use_consumable_heals_and_is_removed() -> void:
	var player := _spawn_player()
	player.stats.take_damage(5)
	assert_eq(player.stats.health, 5)

	var potion: Variant = _make_item("Potion", {"heal": 3})
	player.add_item(potion)

	assert_true(player.use_item(0))
	assert_eq(player.stats.health, 8)
	assert_eq(player.inventory.size(), 0)


func test_use_item_can_modify_combat_stats() -> void:
	var player := _spawn_player()
	var tonic: Variant = _make_item("Tonic", {"attack": 2, "defence": 1}, ItemData.ItemType.EQUIPMENT)
	player.add_item(tonic)

	assert_true(player.use_item(0))
	assert_eq(player.stats.attack, 4)
	assert_eq(player.stats.defence, 1)
	assert_eq(player.inventory.size(), 1)


func test_use_item_invalid_index_returns_false() -> void:
	var player := _spawn_player()
	assert_false(player.use_item(0))
