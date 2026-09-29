# res://Scripts/Managers/LevelManager.gd
extends Node
class_name LevelManager

## Levels up a cat character resource, allocating stat choices and recalculating derived stats.
static func level_player(cat: Resource, options: Dictionary = {}) -> bool:
	if not is_instance_valid(cat):
		push_error("LevelManager: Invalid cat resource passed to level_player()")
		return false

	# 1. Advance Base Level
	var current_lvl: int = int(cat.get("level")) if "level" in cat else 1
	var new_lvl: int = current_lvl + 1
	cat.set("level", new_lvl)

	# 2. Allocate Player-Selected Stat Increases (from options dictionary)
	# Expected options format: {"strength": 1, "vitality": 2, "intelligence": 1}
	var stat_choices: Dictionary = options.get("stat_points", options)
	for stat_name: String in stat_choices.keys():
		var points_to_add: int = int(stat_choices[stat_name])
		if points_to_add <= 0:
			continue

		if stat_name in cat:
			var old_val: int = int(cat.get(stat_name))
			cat.set(stat_name, old_val + points_to_add)
			print("LevelManager: %s +%d -> %d" % [stat_name.capitalize(), points_to_add, old_val + points_to_add])

	# 3. Recalculate Derived Stats (Max HP & Max MP)
	var vit: int = int(cat.get("vitality")) if "vitality" in cat else (int(cat.get("vit")) if "vit" in cat else 10)
	var int_stat: int = int(cat.get("intelligence")) if "intelligence" in cat else 10
	var pie: int = int(cat.get("piety")) if "piety" in cat else 10

	# Formula: Base Class HP + (Vitality * Level Multiplier)
	var old_max_hp: int = int(cat.get("max_hp")) if "max_hp" in cat else 20
	var hp_gain: int = 5 + int(vit * 1.5)
	var new_max_hp: int = old_max_hp + hp_gain
	cat.set("max_hp", new_max_hp)

	# Restore HP on Level Up
	cat.set("current_hp", new_max_hp)

	# Formula: Base MP + (INT/PIE scaling)
	var old_max_mp: int = int(cat.get("max_mp")) if "max_mp" in cat else 10
	var mp_gain: int = 3 + int((int_stat + pie) * 0.75)
	var new_max_mp: int = old_max_mp + mp_gain
	cat.set("max_mp", new_max_mp)
	
	if "current_mp" in cat:
		cat.set("current_mp", new_max_mp)
	elif "current_mana" in cat:
		cat.set("current_mana", new_max_mp)

	# 4. Compute Next Level XP Threshold
	# Formula: 100 * (Level ^ 1.5)
	if "current_xp" in cat:
		cat.set("current_xp", 0)
	elif "xp" in cat:
		cat.set("xp", 0)

	# Formula: 100 * (Level ^ 1.5)
	var next_max_xp: int = roundi(100.0 * pow(float(new_lvl), 1.5))
	if "max_xp" in cat:
		cat.set("max_xp", next_max_xp)

	var cat_name: String = str(cat.get("name")) if cat.get("name") != null else "Cat"
	print("LevelManager: 🌟 %s REACHED LEVEL %d! HP: %d (+%d) | MP: %d (+%d) | Next XP: %d" % [
		cat_name, new_lvl, new_max_hp, hp_gain, new_max_mp, mp_gain, next_max_xp
	])

	# 5. Notify Global System & Save Progress
	var tree := Engine.get_main_loop() as SceneTree
	if is_instance_valid(tree) and tree.root.has_node("SignalBus"):
		var sb: Node = tree.root.get_node("SignalBus")
		if sb.has_signal("show_toast"):
			sb.emit_signal("show_toast", "🌟 %s Leveled Up to Lvl %d!" % [cat_name, new_lvl], false)

	if is_instance_valid(tree) and tree.root.has_node("GameState"):
		var gs: Node = tree.root.get_node("GameState")
		if gs.has_method("save_game"):
			gs.call("save_game")

	return true
