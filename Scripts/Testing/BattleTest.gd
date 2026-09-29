class_name BattleTest
extends Node

## Standalone Debug Controller for testing combat triggers and UI feedback FX.
##
## Hotkeys:
##   [B] - Single Tap: Toggle Scavenger/Zombie Encounter. Double Tap: Spawn Ghost Encounter.
##   [N] - Direct Spawn Ghost Encounter.
##   [H] - Test Chevron Flash Damage FX.
##   [V] - Test Nine HUD Assistant Voice ("cant-sleep-here").

@export var enemy_a_path: String = "res://Data/Enemies/EnScavengerCyclops.tres"
@export var enemy_zombie_path: String = "res://Data/Enemies/EnZombieCat.tres"
@export var enemy_ghost_path: String = "res://Data/Enemies/EnGhost.tres"
@export var legacy_zombie_path: String = "res://Data/Enemies/ZombieCat_Base.tres"


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B:
				_toggle_combat_encounter()
			KEY_N:
				_trigger_ghost_encounter()
			KEY_H:
				_test_chevron_flash()
			KEY_V:
				_test_nine_hud()
			KEY_L:
				_simulate_level_up()


func _toggle_combat_encounter() -> void:
	if _try_end_active_battle():
		return

	print("BattleTest: [B Key] Spawning Mixed Encounter (Scavenger Drone + Zombie Cat)...")

	var active_party: Array = _get_active_party()
	var enemy1: Resource = _load_enemy_resource(enemy_a_path, "Scavenger Cyclops", 60, 8.0, 20, 10)
	var enemy2_path: String = enemy_zombie_path if ResourceLoader.exists(enemy_zombie_path) else legacy_zombie_path
	var enemy2: Resource = _load_enemy_resource(enemy2_path, "Zombie Cat", 75, 7.0, 50, 25)

	var test_loot_table: Resource = _build_test_loot_table(2)
	if is_instance_valid(enemy1) and test_loot_table != null:
		enemy1.set("loot_table", test_loot_table)

	var enemy_pack: Array[Resource] = [enemy1, enemy2]
	_broadcast_combat_start(enemy_pack, active_party)


func _trigger_ghost_encounter() -> void:
	if _try_end_active_battle():
		return

	print("BattleTest: Spawning Ghost Encounter...")

	var active_party: Array = _get_active_party()
	var ghost_enemy: Resource = _load_enemy_resource(enemy_ghost_path, "Ghost", 50, 11.0, 80, 40)
	
	var test_loot_table: Resource = _build_test_loot_table(1)
	if is_instance_valid(ghost_enemy) and test_loot_table != null:
		ghost_enemy.set("loot_table", test_loot_table)

	var enemy_pack: Array[Resource] = [ghost_enemy]
	_broadcast_combat_start(enemy_pack, active_party)


func _try_end_active_battle() -> bool:
	var sb: Node = SignalBus
	var battle_hud: Node = get_tree().root.find_child("BattleHUD", true, false)
	if is_instance_valid(battle_hud) and battle_hud.get("visible") == true:
		print("BattleTest: Ending active combat session...")
		if is_instance_valid(sb) and sb.has_signal("combat_ended"):
			sb.combat_ended.emit(true)
		return true
	return false


func _get_active_party() -> Array:
	var active_party: Array = []
	var game_state_node: Node = get_tree().root.get_node_or_null("GameState")
	if is_instance_valid(game_state_node) and "current_party" in game_state_node:
		var party_res: Resource = game_state_node.get("current_party") as Resource
		if is_instance_valid(party_res) and "slots" in party_res:
			active_party = party_res.get("slots") as Array
	return active_party


func _broadcast_combat_start(enemy_pack: Array[Resource], active_party: Array) -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal("combat_started"):
		sb.combat_started.emit(enemy_pack, active_party, "SOUTH")


func _load_enemy_resource(res_path: String, fallback_name: String, fallback_hp: int, fallback_spd: float, xp: int, gold: int) -> Resource:
	var enemy_res: Resource = null

	if ResourceLoader.exists(res_path):
		enemy_res = load(res_path) as Resource
	else:
		var fallback := EnemyData.new()
		fallback.set("enemy_name", fallback_name)
		fallback.set("max_health", fallback_hp)
		fallback.set("speed", fallback_spd)
		fallback.set("xp_value", xp)
		fallback.set("gold_value", gold)

		if ResourceLoader.exists(legacy_zombie_path):
			var base_res: Resource = load(legacy_zombie_path) as Resource
			if is_instance_valid(base_res):
				if "model_scene" in base_res:
					fallback.set("model_scene", base_res.get("model_scene"))
				if "custom_material" in base_res:
					fallback.set("custom_material", base_res.get("custom_material"))

		enemy_res = fallback

	_ensure_material_texture(enemy_res)
	return enemy_res


func _ensure_material_texture(enemy_data: Resource) -> void:
	if not is_instance_valid(enemy_data):
		return

	var custom_mat: Material = enemy_data.get("custom_material") as Material if "custom_material" in enemy_data else null
	var tex_path: String = str(enemy_data.get("texture_path")) if "texture_path" in enemy_data else ""

	if custom_mat == null and not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		var new_mat := StandardMaterial3D.new()
		new_mat.albedo_texture = load(tex_path) as Texture2D
		enemy_data.set("custom_material", new_mat)
	elif custom_mat is StandardMaterial3D:
		var std_mat := custom_mat as StandardMaterial3D
		if std_mat.albedo_texture == null and not tex_path.is_empty() and ResourceLoader.exists(tex_path):
			std_mat.albedo_texture = load(tex_path) as Texture2D


func _test_chevron_flash() -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal("chevron_flash_requested"):
		print("BattleTest: [H Key] Requesting chevron flash FX...")
		sb.chevron_flash_requested.emit(true)


func _test_nine_hud() -> void:
	var nine_hud: Node = get_tree().root.find_child("NineHud", true, false)
	if is_instance_valid(nine_hud) and nine_hud.has_method("make_nine_talk"):
		print("BattleTest: [V Key] Triggering Nine HUD voice assistant...")
		nine_hud.call("make_nine_talk", "cant-sleep-here")
	else:
		push_warning("BattleTest: Could not find NineHud node in active scene tree!")


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


func _simulate_level_up() -> void:
	var active_party: Array = _get_active_party()
	if active_party.is_empty():
		push_warning("BattleTest: Cannot simulate level up — active party is empty!")
		return

	print("BattleTest: [L Key] Simulating level-up for all %d active party members..." % active_party.size())

	const FIGHTER_CLASSES: Array[String] = ["Spartan", "Crusader", "Ghostblade", "Ronin", "Amazon"]

	for i in range(active_party.size()):
		var cat: Resource = active_party[i] as Resource
		if not is_instance_valid(cat):
			continue

		var cat_name: String = str(cat.get("name")) if cat.get("name") != null else "Cat %d" % (i + 1)
		var prof_name: String = ""

		# 1. Resolve Class / Profession Name
		if "profession" in cat and is_instance_valid(cat.get("profession")):
			var prof: Resource = cat.get("profession") as Resource
			if "profession_name" in prof and prof.get("profession_name") != null:
				prof_name = str(prof.get("profession_name"))

		if prof_name.is_empty() and "profession_name" in cat and cat.get("profession_name") != null:
			prof_name = str(cat.get("profession_name"))

		# 2. Check Fighter Class Match
		var is_fighter: bool = false
		for f_class in FIGHTER_CLASSES:
			if prof_name.nocasecmp_to(f_class) == 0:
				is_fighter = true
				break

		# 3. Configure Archetype Stat Distribution
		var stat_distribution: Dictionary = {}
		if is_fighter:
			# Fighter allocation (STR, VIT, DEX, SPD)
			stat_distribution = {
				"strength": 2,
				"vitality": 1,
				"dexterity": 1,
				"speed": 1
			}
		else:
			# Magic User / Caster allocation (INT, PIE, VIT, SPD)
			stat_distribution = {
				"intelligence": 2,
				"piety": 1,
				"vitality": 1,
				"speed": 1
			}

		var test_options: Dictionary = {
			"stat_points": stat_distribution
		}

		print("BattleTest: Leveling up slot %d: %s (Class: '%s')..." % [i, cat_name, prof_name if not prof_name.is_empty() else "Unknown"])
		LevelManager.level_player(cat, test_options)
