# res://resources/CatCharacter.gd
extends Resource
class_name CatCharacter

signal equipment_changed

const CharacterStats = preload("res://Models/character_stats.gd")

@export_group("Identity")
@export var name: String = "New Recruit"
@export var breed: Resource # CatBreed
@export var profession: Resource # ProfessionData
@export var portrait_path: String = ""
@export var portrait: Texture2D

@export_group("Level & Progression")
@export var level: int = 1
@export var current_xp: int = 0
@export var max_xp: int = 1000

@export_group("Core Attributes")
@export var strength: int = 8
@export var intelligence: int = 8
@export var piety: int = 8
@export var vitality: int = 8
@export var dexterity: int = 8
@export var speed: int = 8
@export var personality: int = 8

@export_group("Dynamic Vitals Component")
var stats: CharacterStats

@export var current_energy: int = 10
@export var max_energy: int = 10

@export_group("Equipment & Inventory")
@export var inventory: Resource
## Dictionary mapping slot names ("BODY", "HEAD", "LEFT_HAND", "RIGHT_HAND", etc.) to ItemData resources
@export var equipment: Dictionary = { "HEAD": null, "BODY": null, "ARMS": null, "LEGS": null, "FEET": null, "LEFT_HAND": null, "RIGHT_HAND": null, "ACCESSORY": null }

@export_group("Abilities")
@export var known_spells: Array[Resource] = []
@export var known_skills: Array[Resource] = []

# 🎯 Party Row Alignment (Defaults to Front Row)
@export_group("Tactical Positioning")
@export var is_front_row: bool = true

# =============================================================================
# ⚔️ ATTACK TYPE RESOLUTION
# =============================================================================


## Evaluates equipped weapons to return the active attack classification
func get_attack_type_string() -> String:
	var weapon: ItemData = get_equipped_item("RIGHT_HAND") as ItemData
	if not is_instance_valid(weapon):
		weapon = get_equipped_item("LEFT_HAND") as ItemData

	if is_instance_valid(weapon):
		if "weapon_type" in weapon and weapon.get("weapon_type") != null:
			var wt_val = weapon.get("weapon_type")
			if typeof(wt_val) == TYPE_INT:
				match wt_val:
					1:
						return "BLADE"
					2:
						return "BASH"
					3:
						return "RANGED"
					4:
						return "MAGIC"
			elif typeof(wt_val) == TYPE_STRING and not str(wt_val).is_empty():
				return str(wt_val).to_upper()

		var w_name: String = weapon.item_name.to_upper()
		if "BOW" in w_name or "CROSSBOW" in w_name or "ARROW" in w_name or "BOLT" in w_name:
			return "RANGED"
		if "SWORD" in w_name or "BLADE" in w_name or "KATANA" in w_name or "CLAW" in w_name or "DAGGER" in w_name:
			return "BLADE"
		if "STAFF" in w_name or "WAND" in w_name or "ORB" in w_name or "SPELL" in w_name:
			return "MAGIC"
		if "HAMMER" in w_name or "MACE" in w_name or "CLUB" in w_name or "SHIELD" in w_name:
			return "BASH"
		return "BLADE"

	return "UNARMED"

# =============================================================================
# 🏢 UI & SYSTEM WRAPPER PROPERTIES
# =============================================================================

var current_hp: int:
	get:
		return stats.health if stats else 0
	set(value):
		if stats:
			stats.health = value

var max_hp: int:
	get:
		return stats.max_health if stats else 0
	set(value):
		if stats:
			stats.max_health = value

var current_health: int:
	get:
		return current_hp
	set(value):
		current_hp = value

var max_health: int:
	get:
		return max_hp
	set(value):
		max_hp = value

var current_mana: int:
	get:
		return current_energy
	set(value):
		current_energy = value

var max_mana: int:
	get:
		return max_energy
	set(value):
		max_energy = value

# Calculated Equipment Stat Offsets
var equipment_bonus_attack: int = 0
var equipment_bonus_defense: int = 0
var equipment_bonus_speed: int = 0
var equipment_stat_bonuses: Dictionary = { }

# =============================================================================
# ⚙️ LIFECYCLE & STAT INITIALIZATION
# =============================================================================


func _init() -> void:
	stats = CharacterStats.new()


func initialize_stats() -> void:
	if stats == null:
		stats = CharacterStats.new()

	if is_instance_valid(breed):
		strength = breed.get("base_strength") if "base_strength" in breed else strength
		intelligence = breed.get("base_intelligence") if "base_intelligence" in breed else intelligence
		piety = breed.get("base_piety") if "base_piety" in breed else piety
		vitality = breed.get("base_vitality") if "base_vitality" in breed else vitality
		dexterity = breed.get("base_dexterity") if "base_dexterity" in breed else dexterity
		speed = breed.get("base_speed") if "base_speed" in breed else speed
		personality = breed.get("base_personality") if "base_personality" in breed else personality

	if is_instance_valid(profession):
		strength = max(strength, int(profession.get("req_strength"))) if "req_strength" in profession else strength
		intelligence = max(intelligence, int(profession.get("req_intelligence"))) if "req_intelligence" in profession else intelligence
		piety = max(piety, int(profession.get("req_piety"))) if "req_piety" in profession else piety
		vitality = max(vitality, int(profession.get("req_vitality"))) if "req_vitality" in profession else vitality
		dexterity = max(dexterity, int(profession.get("req_dexterity"))) if "req_dexterity" in profession else dexterity
		speed = max(speed, int(profession.get("req_speed"))) if "req_speed" in profession else speed
		personality = max(personality, int(profession.get("req_personality"))) if "req_personality" in profession else personality

	_calculate_vitals()
	stats.health = stats.max_health
	current_energy = max_energy
	max_xp = get_required_xp_for_level(level)

	populate_starting_skills()
	populate_starting_spells()


func _calculate_vitals() -> void:
	var prof_name: String = profession.get("profession_name") if is_instance_valid(profession) and "profession_name" in profession else ""
	if prof_name in ["Spartan", "Crusader", "Amazon"]:
		stats.max_health = vitality * 3
	else:
		stats.max_health = vitality * 2
	max_energy = intelligence + piety

# =============================================================================
# 📈 LEVEL & XP PROGRESSION MECHANICS
# =============================================================================


## Calculates XP required to reach the target level.
## Wizardry 7 style polynomial scaling: Base * Level^1.5
func get_required_xp_for_level(target_level: int) -> int:
	var base_xp: float = 1000.0
	if is_instance_valid(profession) and "base_xp_requirement" in profession:
		base_xp = float(profession.get("base_xp_requirement"))

	return int(base_xp * pow(float(target_level), 1.5))


## Adds XP to character, processes level ups, and carries over leftover XP.
## Returns true if the character leveled up.
func add_xp(amount: int) -> bool:
	current_xp += amount
	print("[CatCharacter] ", name, " gained ", amount, " XP! Current XP: ", current_xp, " / ", max_xp)

	if max_xp <= 0:
		max_xp = get_required_xp_for_level(level)

	var leveled_up: bool = false
	while current_xp >= max_xp:
		current_xp -= max_xp
		level += 1
		leveled_up = true
		max_xp = get_required_xp_for_level(level)
		_on_level_up()

	return leveled_up


func _on_level_up() -> void:
	vitality += 1
	strength += 1
	_calculate_vitals()
	stats.health = stats.max_health # Restore HP on level up
	current_energy = max_energy # Restore Energy on level up
	print("[CatCharacter] 🌟 ", name, " LEVELED UP to Level ", level, "! Next level requires ", max_xp, " XP.")

# =============================================================================
# ⚔️ ABILITY & EQUIPMENT MANAGERS
# =============================================================================


func populate_starting_skills() -> void:
	var skills_dir: String = "res://Data/Skills/"
	if not DirAccess.dir_exists_absolute(skills_dir):
		return

	var prof_name: String = profession.get("profession_name") if is_instance_valid(profession) and "profession_name" in profession else ""
	var breed_name_val: String = breed.get("breed_name") if is_instance_valid(breed) and "breed_name" in breed else ""

	var dir := DirAccess.open(skills_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var skill_res := load(skills_dir + file_name) as Resource
			if is_instance_valid(skill_res):
				var assigned_c: Array = skill_res.get("assigned_classes") if "assigned_classes" in skill_res else []
				var assigned_r: Array = skill_res.get("assigned_races") if "assigned_races" in skill_res else []

				var matches_class: bool = not prof_name.is_empty() and assigned_c.has(prof_name)
				var matches_race: bool = not breed_name_val.is_empty() and assigned_r.has(breed_name_val)

				if (matches_class or matches_race) and not known_skills.has(skill_res):
					known_skills.append(skill_res)
		file_name = dir.get_next()


func populate_starting_spells() -> void:
	var spells_dir: String = "res://Data/Spells/"
	if not DirAccess.dir_exists_absolute(spells_dir):
		return
	if not is_instance_valid(profession):
		return

	var sb_type_str: String = profession.get("spellbook_type") if "spellbook_type" in profession else ""
	if sb_type_str.is_empty() or sb_type_str == "None":
		return

	var allowed_books: Array[String] = []
	for p in sb_type_str.split(","):
		for inner_p in p.split("|"):
			var trimmed := inner_p.strip_edges().to_upper()
			if not trimmed.is_empty():
				allowed_books.append(trimmed)

	var dir := DirAccess.open(spells_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var spell_res := load(spells_dir + file_name) as Resource
			if is_instance_valid(spell_res):
				var s_book_val = spell_res.get("spellbook") if "spellbook" in spell_res else null
				var s_book_name: String = ""
				if s_book_val != null:
					match int(s_book_val):
						0:
							s_book_name = "ARCHANIST"
						1:
							s_book_name = "SOULWRIGHT"
						2:
							s_book_name = "MAESTER"
						3:
							s_book_name = "PSYNIC"
						_:
							s_book_name = str(s_book_val).to_upper()

				if allowed_books.has(s_book_name) and not known_spells.has(spell_res):
					known_spells.append(spell_res)
		file_name = dir.get_next()


func take_damage(amount: int) -> void:
	if stats:
		stats.take_damage(amount)


func heal(amount: int) -> void:
	if stats:
		stats.heal(amount)


func assemble_character(final_stats: Dictionary) -> void:
	strength = final_stats.get("strength", strength)
	intelligence = final_stats.get("intelligence", intelligence)
	piety = final_stats.get("piety", piety)
	vitality = final_stats.get("vitality", vitality)
	dexterity = final_stats.get("dexterity", dexterity)
	speed = final_stats.get("speed", speed)
	personality = final_stats.get("personality", personality)

	_calculate_vitals()
	stats.health = stats.max_health
	current_energy = max_energy

# =============================================================================
# YOUR EXISTING EQUIPMENT METHODS (ENHANCED)
# =============================================================================


func equip_item(slot_name: String, item: Resource) -> bool:
	if equipment.has(slot_name):
		equipment[slot_name] = item
		_recalculate_equipment_stats()
		return true
	return false


func unequip_item(slot_name: String) -> Resource:
	if equipment.has(slot_name):
		var item: Resource = equipment[slot_name]
		equipment[slot_name] = null
		_recalculate_equipment_stats()
		return item
	return null


func get_equipped_item(slot_name: String) -> Resource:
	return equipment.get(slot_name, null)


func _recalculate_equipment_stats() -> void:
	equipment_bonus_attack = 0
	equipment_bonus_defense = 0
	equipment_bonus_speed = 0
	equipment_stat_bonuses.clear()

	# Iterate over all currently equipped items in the equipment dictionary
	for item_var in equipment.values():
		var item: ItemData = item_var as ItemData
		if not is_instance_valid(item):
			continue

		# Accumulate direct combat stats
		equipment_bonus_attack += item.attack_bonus
		equipment_bonus_defense += item.defense_bonus
		equipment_bonus_speed += item.speed_bonus

		# Accumulate primary attribute bonuses (e.g., strength, intelligence, speed)
		var eff_stat: String = str(item.effect_stat).to_lower().strip_edges()
		var eff_amt: int = int(item.effect_amount)

		if not eff_stat.is_empty() and eff_amt != 0:
			var current: int = equipment_stat_bonuses.get(eff_stat, 0)
			equipment_stat_bonuses[eff_stat] = current + eff_amt

	# Broadcast signal to trigger UI updates (CharacterStatsPanel, CharacterLoadoutPanel)
	equipment_changed.emit()

# =============================================================================
# STAT GETTER HELPERS FOR UI & COMBAT
# =============================================================================


func get_equipment_stat_bonus(stat_name: StringName) -> int:
	var key: String = str(stat_name).to_lower()
	return equipment_stat_bonuses.get(key, 0)


func get_total_equipment_attack() -> int:
	return equipment_bonus_attack


func get_total_equipment_defense() -> int:
	return equipment_bonus_defense

# =============================================================================
# EFFECTIVE STAT RESOLVERS
# =============================================================================


func get_effective_stat(stat_name: StringName) -> int:
	var base_val: int = 10
	match stat_name:
		&"strength", &"str":
			base_val = strength
		&"intelligence", &"int":
			base_val = intelligence
		&"piety", &"pie":
			base_val = piety
		&"vitality", &"vit":
			base_val = vitality
		&"dexterity", &"dex":
			base_val = dexterity
		&"speed", &"spd":
			base_val = speed
		&"personality", &"per":
			base_val = personality

	return base_val + get_equipment_stat_bonus(stat_name)


func get_effective_strength() -> int:
	return get_effective_stat(&"strength")


func get_effective_speed() -> int:
	return get_effective_stat(&"speed")
