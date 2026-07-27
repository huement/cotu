# res://Scripts/Testing/BattleTest.gd
class_name BattleTest
extends Node

## Standalone Debug Controller for testing combat triggers and UI feedback FX.
## 
## Hotkeys:
##   [B] - Toggle Combat Encounter ON / OFF
##   [H] - Test Chevron Flash Damage FX

@export var mock_enemy_path: String = "res://Data/Enemies/ZombieCat_Base.tres"


# =============================================================================
# 1. LIFECYCLE & DEBUG INPUT
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	# Guard: Only execute hotkeys in Debug builds
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

	print("BattleTest: [B Key] Spawning Cyber-Zombie encounter...")

	# 2. Safely fetch active party slots from GameState without null reference crashes
	var active_party: Array = []
	var game_state_node: Node = get_tree().root.get_node_or_null("GameState")

	if is_instance_valid(game_state_node) and "current_party" in game_state_node:
		var party_res: Resource = game_state_node.get("current_party") as Resource
		if is_instance_valid(party_res) and "slots" in party_res:
			active_party = party_res.get("slots") as Array

	# 3. Load test enemy resource or fall back to dynamic resource data
	var enemy_res: Resource = null
	if ResourceLoader.exists(mock_enemy_path):
		enemy_res = load(mock_enemy_path) as Resource
	else:
		enemy_res = EnemyData.new() if ClassDB.class_exists("EnemyData") else Resource.new()
		enemy_res.set("enemy_name", "Cyber-Zombie Cat")
		enemy_res.set("max_health", 30)
		enemy_res.set("speed", 12.0)

	# 4. Broadcast combat start through SignalBus
	if sb.has_signal("combat_started"):
		sb.combat_started.emit(enemy_res, active_party)


func _test_chevron_flash() -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal("chevron_flash_requested"):
		print("BattleTest: [H Key] Requesting chevron flash FX...")
		sb.chevron_flash_requested.emit(true)
