# res://Scripts/Testing/BattleTest.gd
class_name BattleTest
extends Node

## Standalone Debug Controller for testing combat triggers and UI feedback FX.
##
## Hotkeys:
##   [B] - Toggle Combat Encounter ON / OFF (Spawns 1 Scavenger Drone + 1 Zombie Cat)
##   [H] - Test Chevron Flash Damage FX

@export var enemy_a_path: String = "res://Data/Enemies/EnScavengerCyclops.tres"
@export var enemy_zombie_path: String = "res://Data/Enemies/EnZombieCat.tres"
@export var legacy_zombie_path: String = "res://Data/Enemies/ZombieCat_Base.tres"


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B:
				_toggle_combat_encounter()
			KEY_H:
				_test_chevron_flash()


func _toggle_combat_encounter() -> void:
	var sb: Node = SignalBus
	if not is_instance_valid(sb):
		return

	# 1. Terminate active battle if running
	var battle_hud: Node = get_tree().root.find_child("BattleHUD", true, false)
	if is_instance_valid(battle_hud) and battle_hud.get("visible") == true:
		print("BattleTest: [B Key] Ending active combat session...")
		if sb.has_signal("combat_ended"):
			sb.combat_ended.emit(true)
		return

	print("BattleTest: [B Key] Spawning Mixed Encounter (Scavenger Drone + Zombie Cat)...")

	# 2. Safely fetch active party slots from GameState
	var active_party: Array = []
	var game_state_node: Node = get_tree().root.get_node_or_null("GameState")

	if is_instance_valid(game_state_node) and "current_party" in game_state_node:
		var party_res: Resource = game_state_node.get("current_party") as Resource
		if is_instance_valid(party_res) and "slots" in party_res:
			active_party = party_res.get("slots") as Array

	# 3. Load Enemy A (Scavenger Drone)
	var enemy1: Resource = _load_enemy_resource(enemy_a_path, "Scavenger Cyclops", 60, 8.0, 20, 10)

	# 4. Load Enemy B (Zombie Cat) with fallback
	var enemy2_path: String = enemy_zombie_path if ResourceLoader.exists(enemy_zombie_path) else legacy_zombie_path
	var enemy2: Resource = _load_enemy_resource(enemy2_path, "Zombie Cat", 75, 7.0, 50, 25)

	# 5. Attach guaranteed test loot tables
	var test_loot_table: Resource = _build_test_loot_table(2)
	if is_instance_valid(enemy1) and test_loot_table != null:
		enemy1.set("loot_table", test_loot_table)

	var enemy_pack: Array[Resource] = [enemy1, enemy2]

	# 6. Broadcast combat start
	if sb.has_signal("combat_started"):
		sb.combat_started.emit(enemy_pack, active_party)


func _load_enemy_resource(res_path: String, fallback_name: String, fallback_hp: int, fallback_spd: float, xp: int, gold: int) -> Resource:
	if ResourceLoader.exists(res_path):
		return load(res_path) as Resource

	var fallback := EnemyData.new()
	fallback.set("enemy_name", fallback_name)
	fallback.set("max_health", fallback_hp)
	fallback.set("speed", fallback_spd)
	fallback.set("xp_value", xp)
	fallback.set("gold_value", gold)
	return fallback


func _test_chevron_flash() -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal("chevron_flash_requested"):
		print("BattleTest: [H Key] Requesting chevron flash FX...")
		sb.chevron_flash_requested.emit(true)


func _build_test_loot_table(item_count: int = 2) -> Resource:
	var loot_table := LootTable.new("BattleTest Debug Loot", item_count)

	var item1: ItemData = null
	var item2: ItemData = null

	var paths_1: Array[String] = ["res://Data/Items/GemDataQuartz.tres", "res://Data/Items/DataQuartz.tres"]
	var paths_2: Array[String] = ["res://Data/Items/ConHealthVial.tres", "res://Data/Items/HealthVial.tres"]

	for path in paths_1:
		if ResourceLoader.exists(path):
			item1 = load(path) as ItemData
			break

	for path in paths_2:
		if ResourceLoader.exists(path):
			item2 = load(path) as ItemData
			break

	if not is_instance_valid(item1):
		item1 = ItemData.new()
		item1.item_id = "gem_data_quartz"
		item1.item_name = "Data-Quartz"
		item1.credit_value = 100

	if not is_instance_valid(item2):
		item2 = ItemData.new()
		item2.item_id = "con_health_vial"
		item2.item_name = "Neon-Tinged Health Vial"
		item2.credit_value = 50

	var loot_item1 := LootItem.new(item1, 10, false, true, true)
	var loot_item2 := LootItem.new(item2, 10, false, true, true)

	loot_table.add_item(loot_item1)
	if item_count > 1:
		loot_table.add_item(loot_item2)

	return loot_table
