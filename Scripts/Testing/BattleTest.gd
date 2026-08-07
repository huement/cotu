# res://Scripts/Testing/BattleTest.gd
class_name BattleTest
extends Node

## Standalone Debug Controller for testing combat triggers and UI feedback FX.
##
## Hotkeys:
##   [B] - Toggle Combat Encounter ON / OFF (Spawns 2 Cyber-Zombies)
##   [H] - Test Chevron Flash Damage FX

@export var mock_enemy_path: String = "res://Data/Enemies/ZombieCat_Base.tres"

# =============================================================================
# 1. LIFECYCLE & DEBUG INPUT
# =============================================================================


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B:
				_toggle_combat_encounter()
			KEY_H:
				_test_chevron_flash()

# =============================================================================
# 2. DEBUG ACTION HANDLERS
# =============================================================================


func _toggle_combat_encounter() -> void:
	var sb: Node = SignalBus
	if not is_instance_valid(sb):
		return

	# 1. If battle is already active, request combat termination via SignalBus
	var battle_hud: Node = get_tree().root.find_child("BattleHUD", true, false)
	if is_instance_valid(battle_hud) and battle_hud.get("visible") == true:
		print("BattleTest: [B Key] Ending active combat session...")
		if sb.has_signal("combat_ended"):
			sb.combat_ended.emit(true)
		return

	print("BattleTest: [B Key] Spawning 2-Enemy Cyber-Zombie Pack...")

	# 2. Safely fetch active party slots from GameState
	var active_party: Array = []
	var game_state_node: Node = get_tree().root.get_node_or_null("GameState")

	if is_instance_valid(game_state_node) and "current_party" in game_state_node:
		var party_res: Resource = game_state_node.get("current_party") as Resource
		if is_instance_valid(party_res) and "slots" in party_res:
			active_party = party_res.get("slots") as Array

	# 3. Load base test enemy resource
	var enemy1: Resource = null
	if ResourceLoader.exists(mock_enemy_path):
		enemy1 = load(mock_enemy_path) as Resource
	else:
		enemy1 = EnemyData.new()
		enemy1.set("enemy_name", "Cyber-Zombie Cat")
		enemy1.set("max_health", 30)
		enemy1.set("speed", 12.0)
		enemy1.set("xp_value", 50)
		enemy1.set("gold_value", 25)

	# 4. Attach a guaranteed 2-item LootTable to the test encounter
	var test_loot_table: Resource = _build_test_loot_table(2)
	if is_instance_valid(enemy1) and test_loot_table != null:
		enemy1.set("loot_table", test_loot_table)

	# 5. Duplicate enemy to create a 2-mob encounter
	var enemy2: Resource = enemy1.duplicate(true) if is_instance_valid(enemy1) else enemy1

	var enemy_pack: Array[Resource] = [enemy1, enemy2]

	# 6. Broadcast combat start with enemy pack array
	if sb.has_signal("combat_started"):
		sb.combat_started.emit(enemy_pack, active_party)


func _test_chevron_flash() -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal("chevron_flash_requested"):
		print("BattleTest: [H Key] Requesting chevron flash FX...")
		sb.chevron_flash_requested.emit(true)


## Constructs a guaranteed LootTable for BattleTest debug sessions
func _build_test_loot_table(item_count: int = 2) -> Resource:
	var loot_table := LootTable.new("BattleTest Debug Loot", item_count)
	print("BattleTest Debug LootTable: Constructing with %d guaranteed items..." % item_count)
	# 1. Attempt to load compiled ItemData resources from res://Data/Items/
	var item1: ItemData = null
	var item2: ItemData = null

	var paths_1: Array[String] = ["res://Data/Items/GemDataQuartz.tres", "res://Data/Items/DataQuartz.tres"]
	var paths_2: Array[String] = ["res://Data/Items/ConHealthVial.tres", "res://Data/Items/HealthVial.tres", "res://Data/Items/Consumables/ConHealthVial.tres"]

	for path in paths_1:
		if ResourceLoader.exists(path):
			item1 = load(path) as ItemData
			break

	for path in paths_2:
		if ResourceLoader.exists(path):
			item2 = load(path) as ItemData
			break

	# Fallback: Create typed ItemData in memory if compiled resources do not exist
	if not is_instance_valid(item1):
		item1 = ItemData.new()
		item1.item_id = "gem_data_quartz"
		item1.item_name = "Data-Quartz"
		item1.description = "A glowing crystal containing fractured source code from the elven mainframes."
		item1.credit_value = 100

	if not is_instance_valid(item2):
		item2 = ItemData.new()
		item2.item_id = "con_health_vial"
		item2.item_name = "Neon-Tinged Health Vial"
		item2.description = "Restores physical tissue using arcane-infused nanites."
		item2.credit_value = 50

	# 2. Add LootItems configured to always drop (should_drop_always = true)
	var loot_item1 := LootItem.new(item1, 10, false, true, true)
	var loot_item2 := LootItem.new(item2, 10, false, true, true)

	loot_table.add_item(loot_item1)
	if item_count > 1:
		loot_table.add_item(loot_item2)

	return loot_table
