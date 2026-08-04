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
		enemy1 = EnemyData.new() if ClassDB.class_exists("EnemyData") else Resource.new()
		enemy1.set("enemy_name", "Cyber-Zombie Cat")
		enemy1.set("max_health", 30)
		enemy1.set("speed", 12.0)
		enemy1.set("xp_value", 50)

	# 4. Duplicate enemy to create a 2-mob encounter
	var enemy2: Resource = enemy1.duplicate(true) if is_instance_valid(enemy1) else enemy1

	var enemy_pack: Array[Resource] = [enemy1, enemy2]

	# 5. Broadcast combat start with enemy pack array
	if sb.has_signal("combat_started"):
		sb.combat_started.emit(enemy_pack, active_party)


func _test_chevron_flash() -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal("chevron_flash_requested"):
		print("BattleTest: [H Key] Requesting chevron flash FX...")
		sb.chevron_flash_requested.emit(true)
