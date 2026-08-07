# res://Scripts/UI/character_stats_panel.gd
extends PanelContainer
class_name CharacterStatsPanel

# STAT Column Labels
@onready var stat_str: Label = %StatStr as Label
@onready var stat_int: Label = %StatInt as Label
@onready var stat_pie: Label = %StatPie as Label
@onready var stat_vit: Label = %StatVit as Label
@onready var stat_dex: Label = %StatDex as Label
@onready var stat_spd: Label = %StatSpd as Label
@onready var stat_per: Label = %StatPer as Label
@onready var stat_kar: Label = %StatKar as Label

# FIGHT Column Labels
@onready var fight_acc: Label = %FightAcc as Label
@onready var fight_lh: Label = %FightLH as Label
@onready var fight_rh: Label = %FightRH as Label
@onready var fight_crt: Label = %FightCrt as Label
@onready var fight_dmg: Label = %FightDmg as Label
@onready var fight_arm: Label = %FightArm as Label

# Color Constants for Visual Stat Feedback
const COLOR_NEUTRAL: Color = Color(0.0, 1.0, 0.75, 1.0)
const COLOR_BONUS: Color = Color(0.2, 1.0, 0.3, 1.0)
const COLOR_PENALTY: Color = Color(1.0, 0.3, 0.3, 1.0)

var _current_cat: Resource = null
var _pending_cat: Resource = null


func _ready() -> void:
	# Check for pending data passed prior to entering scene tree
	if _pending_cat:
		display_character_stats(_pending_cat)
		_pending_cat = null


## Safely reads attributes from the passed CatCharacter resource,
## calculates equipment bonuses, and updates the labels in real-time.
func display_character_stats(cat: Resource) -> void:
	if not is_instance_valid(cat):
		return

	# LIFECYCLE GUARD: If @onready vars haven't initialized yet, cache and defer execution
	if not is_node_ready():
		_pending_cat = cat
		return

	# Disconnect previous character signal safely using string check (prevents null key crash)
	if is_instance_valid(_current_cat) and _current_cat.has_signal("equipment_changed"):
		if _current_cat.is_connected("equipment_changed", _on_character_equipment_changed):
			_current_cat.disconnect("equipment_changed", _on_character_equipment_changed)

	_current_cat = cat

	# Connect signal safely only if declared on CatCharacter resource
	if is_instance_valid(_current_cat) and _current_cat.has_signal("equipment_changed"):
		if not _current_cat.is_connected("equipment_changed", _on_character_equipment_changed):
			_current_cat.connect("equipment_changed", _on_character_equipment_changed)

	_update_all_stats()


func _on_character_equipment_changed() -> void:
	_update_all_stats()


func _update_all_stats() -> void:
	if not is_instance_valid(_current_cat):
		return

	# 1. Safely calculate equipment stat & combat bonuses
	var eq_bonuses: Dictionary = _calculate_equipment_bonuses(_current_cat)

	# Fetch base stats from cat
	var base_str: int = int(_current_cat.get("strength")) if "strength" in _current_cat else 10
	var base_int: int = int(_current_cat.get("intelligence")) if "intelligence" in _current_cat else 10
	var base_pie: int = int(_current_cat.get("piety")) if "piety" in _current_cat else 10
	var base_vit: int = int(_current_cat.get("vitality")) if "vitality" in _current_cat else 10
	var base_dex: int = int(_current_cat.get("dexterity")) if "dexterity" in _current_cat else 10
	var base_spd: int = int(_current_cat.get("speed")) if "speed" in _current_cat else 10
	var base_per: int = int(_current_cat.get("personality")) if "personality" in _current_cat else 10

	# --- STAT Column (Base + Equipment Offset Visualization) ---
	_update_stat_label(stat_str, base_str, int(eq_bonuses.get("strength", 0)))
	_update_stat_label(stat_int, base_int, int(eq_bonuses.get("intelligence", 0)))
	_update_stat_label(stat_pie, base_pie, int(eq_bonuses.get("piety", 0)))
	_update_stat_label(stat_vit, base_vit, int(eq_bonuses.get("vitality", 0)))
	_update_stat_label(stat_dex, base_dex, int(eq_bonuses.get("dexterity", 0)))
	_update_stat_label(stat_spd, base_spd, int(eq_bonuses.get("speed", 0)))
	_update_stat_label(stat_per, base_per, int(eq_bonuses.get("personality", 0)))
	if stat_kar:
		stat_kar.text = "10"

	# Calculate Effective Stat Totals
	var eff_str: int = base_str + int(eq_bonuses.get("strength", 0))
	var eff_dex: int = base_dex + int(eq_bonuses.get("dexterity", 0))
	var eff_spd: int = base_spd + int(eq_bonuses.get("speed", 0))
	var eff_per: int = base_per + int(eq_bonuses.get("personality", 0))

	# --- FIGHT Column (Derived Combat Metrics) ---
	# Accuracy: (DEX + PER) / 2
	var base_acc_bonus: int = (base_dex + base_per) / 2
	var eff_acc_bonus: int = (eff_dex + eff_per) / 2
	if fight_acc:
		fight_acc.text = "%d%%" % (80 + eff_acc_bonus)
		_apply_bonus_color(fight_acc, eff_acc_bonus - base_acc_bonus)

	# Left Hand Damage
	var left_weapon: ItemData = _get_equipped_item_in_slot(_current_cat, "LEFT_HAND")
	if fight_lh:
		var base_lh_dmg: int = max(1, eff_str / 2)
		if is_instance_valid(left_weapon) and left_weapon.attack_bonus > 0:
			fight_lh.text = "1d%d (+%d)" % [base_lh_dmg, left_weapon.attack_bonus]
			fight_lh.add_theme_color_override("font_color", COLOR_BONUS)
		else:
			fight_lh.text = "1d%d" % base_lh_dmg
			fight_lh.add_theme_color_override("font_color", COLOR_NEUTRAL)

	# Right Hand Damage
	var right_weapon: ItemData = _get_equipped_item_in_slot(_current_cat, "RIGHT_HAND")
	if right_weapon == null:
		right_weapon = _get_equipped_item_in_slot(_current_cat, "BOTH_HANDS")
	if fight_rh:
		var base_rh_dmg: int = max(1, eff_str / 2)
		if is_instance_valid(right_weapon) and right_weapon.attack_bonus > 0:
			fight_rh.text = "1d%d (+%d)" % [base_rh_dmg, right_weapon.attack_bonus]
			fight_rh.add_theme_color_override("font_color", COLOR_BONUS)
		else:
			fight_rh.text = "1d%d" % base_rh_dmg
			fight_rh.add_theme_color_override("font_color", COLOR_NEUTRAL)

	# Critical Chance: 5 + ((DEX + SPD) / 2) / 4
	var base_crit: int = 5 + ((base_dex + base_spd) / 2) / 4
	var eff_crit: int = 5 + ((eff_dex + eff_spd) / 2) / 4
	if fight_crt:
		fight_crt.text = "%d%%" % eff_crit
		_apply_bonus_color(fight_crt, eff_crit - base_crit)

	# Direct Combat Stats: Attack Bonus
	var base_attack: int = 0
	if "stats" in _current_cat and is_instance_valid(_current_cat.get("stats")):
		base_attack = int(_current_cat.get("stats").get("attack"))
	var eq_attack_bonus: int = int(eq_bonuses.get("attack", 0))
	var total_attack: int = base_attack + eq_attack_bonus
	if fight_dmg:
		if eq_attack_bonus > 0:
			fight_dmg.text = "+%d (+%d)" % [total_attack, eq_attack_bonus]
		else:
			fight_dmg.text = "+%d" % total_attack
		_apply_bonus_color(fight_dmg, eq_attack_bonus)

	# Direct Combat Stats: Defense / Armor
	var base_defense: int = 0
	if "stats" in _current_cat and is_instance_valid(_current_cat.get("stats")):
		base_defense = int(_current_cat.get("stats").get("defence"))
	elif "defense" in _current_cat:
		base_defense = int(_current_cat.get("defense"))
	var eq_defense_bonus: int = int(eq_bonuses.get("defense", 0))
	var total_defense: int = base_defense + eq_defense_bonus
	if fight_arm:
		if eq_defense_bonus > 0:
			fight_arm.text = "%d (+%d)" % [total_defense, eq_defense_bonus]
		else:
			fight_arm.text = "%d" % total_defense
		_apply_bonus_color(fight_arm, eq_defense_bonus)


## Updates attribute labels showing `Total (+Bonus)` or `Total (-Penalty)` with color formatting.
func _update_stat_label(label: Label, base_val: int, bonus: int) -> void:
	if not is_instance_valid(label):
		return

	var effective_val: int = base_val + bonus
	if bonus > 0:
		label.text = "%d (+%d)" % [effective_val, bonus]
		label.add_theme_color_override("font_color", COLOR_BONUS)
	elif bonus < 0:
		label.text = "%d (%d)" % [effective_val, bonus]
		label.add_theme_color_override("font_color", COLOR_PENALTY)
	else:
		label.text = str(base_val)
		label.add_theme_color_override("font_color", COLOR_NEUTRAL)


func _apply_bonus_color(label: Label, diff: int) -> void:
	if not is_instance_valid(label):
		return
	if diff > 0:
		label.add_theme_color_override("font_color", COLOR_BONUS)
	elif diff < 0:
		label.add_theme_color_override("font_color", COLOR_PENALTY)
	else:
		label.add_theme_color_override("font_color", COLOR_NEUTRAL)


## Safely computes total equipment bonuses for all attributes and combat metrics
func _calculate_equipment_bonuses(cat: Resource) -> Dictionary:
	var bonuses: Dictionary = { "strength": 0, "intelligence": 0, "piety": 0, "vitality": 0, "dexterity": 0, "speed": 0, "personality": 0, "karma": 0, "attack": 0, "defense": 0 }

	var equipped_items: Array = []
	if "equipment" in cat and cat.get("equipment") is Dictionary:
		equipped_items = (cat.get("equipment") as Dictionary).values()
	elif "equipped_items" in cat and cat.get("equipped_items") is Array:
		equipped_items = cat.get("equipped_items") as Array
	elif cat.has_method("get_equipped_items"):
		var raw_list: Variant = cat.call("get_equipped_items")
		if raw_list is Array:
			equipped_items = raw_list as Array

	for item_var in equipped_items:
		var item: ItemData = item_var as ItemData
		if not is_instance_valid(item):
			continue

		bonuses["attack"] += item.attack_bonus
		bonuses["defense"] += item.defense_bonus
		bonuses["speed"] += item.speed_bonus

		var eff_stat: String = str(item.effect_stat).to_lower().strip_edges()
		var eff_amt: int = int(item.effect_amount)

		match eff_stat:
			"str", "strength":
				bonuses["strength"] += eff_amt
			"int", "intelligence":
				bonuses["intelligence"] += eff_amt
			"pie", "piety":
				bonuses["piety"] += eff_amt
			"vit", "vitality":
				bonuses["vitality"] += eff_amt
			"dex", "dexterity":
				bonuses["dexterity"] += eff_amt
			"spd", "speed":
				bonuses["speed"] += eff_amt
			"per", "personality":
				bonuses["personality"] += eff_amt
			"kar", "karma":
				bonuses["karma"] += eff_amt
			"attack", "attack_bonus":
				bonuses["attack"] += eff_amt
			"defense", "defense_bonus":
				bonuses["defense"] += eff_amt

	return bonuses


## Safely fetches an equipped ItemData in a specific slot
func _get_equipped_item_in_slot(cat: Resource, slot_key: String) -> ItemData:
	if "equipment" in cat and cat.get("equipment") is Dictionary:
		var eq_dict: Dictionary = cat.get("equipment") as Dictionary
		if eq_dict.has(slot_key) and is_instance_valid(eq_dict[slot_key]):
			return eq_dict[slot_key] as ItemData

	if cat.has_method("get_equipped_item"):
		var raw_item: Variant = cat.call("get_equipped_item", slot_key)
		if is_instance_valid(raw_item) and raw_item is ItemData:
			return raw_item as ItemData

	return null
