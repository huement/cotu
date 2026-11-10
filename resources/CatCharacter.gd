# res://resources/CatCharacter.gd
extends Resource
class_name CatCharacter

signal equipment_changed

const CharacterStatsData = preload("res://resources/character_stats.gd")
 
@export_group("Identity")
@export var name: String = "New Recruit"
@export var breed: Resource # CatBreed
@export var profession: Resource # ProfessionData
@export var portrait_path: String = ""
@export var portrait: Texture2D

@export_group("Roster")
## Id of this character's file in the roster (user://character_pool/<roster_id>.tres). Empty = not a
## roster character (e.g. the test party in Data/default_save.tres). See CharacterRoster.
@export var roster_id: String = ""
## Set once the character has been taken into a game: its roster entry can't be edited any more.
@export var roster_locked: bool = false
## Character creation: the bonus dice rolled and how the points were spent ({ "strength": 2, ... }).
@export var creation_dice: Array[int] = []
@export var creation_allocation: Dictionary = {}

@export_group("Level & Progression")
@export var level: int = 1
@export var current_xp: int = 0
@export var max_xp: int = 1000
@export var unspent_stat_points: int = 0
@export var unspent_skill_points: int = 0
@export var unspent_spell_points: int = 0
## Level-up bonus dice still to roll (one per level gained). Rolled when the Level Up screen opens.
@export var pending_level_rolls: int = 0
## Permanent max-HP bonus from level-up dice (percent, e.g. 3.0 = +3%).
@export var bonus_max_hp_percent: float = 0.0
## skill_id / spell_id -> rank (int). Missing known abilities default to rank 1.
@export var ability_ranks: Dictionary = {}

@export_group("Core Attributes")
@export var strength: int = 8
@export var intelligence: int = 8
@export var piety: int = 8
@export var vitality: int = 8
@export var dexterity: int = 8
@export var speed: int = 8
@export var personality: int = 8

@export_group("Dynamic Vitals Component")
var stats: CharacterStatsData

# 🎯 EXPORTED VITALS FOR PERSISTENCE
@export var current_hp: int = 10:
	get:
		if stats and stats.health != current_hp:
			return stats.health
		return current_hp
	set(value):
		current_hp = value
		if stats:
			stats.health = value

@export var max_hp: int:
	get:
		return stats.max_health if stats else 10
	set(value):
		if stats:
			stats.max_health = value

# ENERGY = MANA
@export var current_energy: int = 10
@export var max_energy: int = 10

@export_group("Equipment & Inventory")
@export var inventory: Resource
@export var equipment: Dictionary = { "HEAD": null, "BODY": null, "ARMS": null, "LEGS": null, "FEET": null, "LEFT_HAND": null, "RIGHT_HAND": null, "ACCESSORY_1": null, "ACCESSORY_2": null }

@export_group("Abilities")
@export var known_spells: Array[Resource] = []
@export var known_skills: Array[Resource] = []
## True once the character got its starting abilities (AbilityRules.initialize_abilities). New spells /
## skills after that only come from Spell Books / Skill Crystals (and the spellbook-opening level-up).
@export var abilities_initialized: bool = false

@export_group("Tactical Positioning")
@export var is_front_row: bool = true

# =============================================================================
# ⚔️ ATTACK TYPE RESOLUTION
# =============================================================================


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

var equipment_bonus_attack: int = 0
var equipment_bonus_defense: int = 0
var equipment_bonus_speed: int = 0
var equipment_stat_bonuses: Dictionary = { }

# =============================================================================
# ⚙️ LIFECYCLE & STAT INITIALIZATION
# =============================================================================


func _init() -> void:
	stats = CharacterStatsData.new()


func initialize_stats() -> void:
	if stats == null:
		stats = CharacterStatsData.new()

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

	# 🎯 Preserve existing saved HP/Energy instead of resetting to 100%!
	if current_hp <= 0:
		current_hp = max_hp
		stats.health = max_hp
	else:
		stats.health = current_hp

	if current_energy <= 0:
		current_energy = max_energy

	populate_starting_skills()
	populate_starting_spells()


## Max HP / MP from the class sheet (Data/Class_Progression.csv) + level + dice HP bonus.
func _calculate_vitals() -> void:
	var row: Dictionary = get_class_progression()
	var base_hp: int = ClassProgression.max_hp(row, vitality, level)
	stats.max_health = roundi(float(base_hp) * (1.0 + bonus_max_hp_percent / 100.0))
	max_energy = ClassProgression.max_mp(row, intelligence, piety, level)


## This character's row in Data/Class_Progression.csv (defaults when the class isn't listed).
func get_class_progression() -> Dictionary:
	if not is_instance_valid(profession) or not "profession_name" in profession:
		return ClassProgression.DEFAULTS
	return ClassProgression.for_class(str(profession.get("profession_name")))


func get_max_level() -> int:
	return int(get_class_progression()["max_level"])


func take_damage(amount: int) -> void:
	if stats:
		stats.take_damage(amount)
		current_hp = stats.health


func heal(amount: int) -> void:
	if stats:
		stats.heal(amount)
		current_hp = stats.health

# =============================================================================
# 📈 LEVEL & XP PROGRESSION MECHANICS
# =============================================================================


## Calculates XP required to reach the target level.
## Wizardry 7 style polynomial scaling: Base * Level^1.5
func get_required_xp_for_level(target_level: int) -> int:
	return ClassProgression.xp_to_next_level(get_class_progression(), target_level)


## Adds XP to character, processes level ups, and carries over leftover XP.
## Returns true if the character leveled up.
func add_xp(amount: int) -> bool:
	current_xp += amount
	print("[CatCharacter] ", name, " gained ", amount, " XP! Current XP: ", current_xp, " / ", max_xp)

	# Always follow the class sheet (so edits to Data/Class_Progression.csv apply to old saves too).
	max_xp = get_required_xp_for_level(level)

	var leveled_up: bool = false
	while current_xp >= max_xp and level < get_max_level():
		current_xp -= max_xp
		level += 1
		leveled_up = true
		max_xp = get_required_xp_for_level(level)
		_on_level_up()

	return leveled_up


func _on_level_up() -> void:
	var gains: Dictionary = get_class_progression()["auto_stat_gains"]
	for stat: String in gains.keys():
		if stat in self:
			set(stat, int(get(stat)) + int(gains[stat]))
	grant_level_points()
	pending_level_rolls += 1
	var opened: Array[SpellData] = AbilityRules.grant_spellbook_opening(self)
	if not opened.is_empty() and is_instance_valid(SignalBus):
		var names: PackedStringArray = []
		for sp: SpellData in opened:
			names.append(sp.spell_name)
		SignalBus.show_toast.emit("%s opened their spellbook: %s" % [name, ", ".join(names)], false)
	_calculate_vitals()
	stats.health = stats.max_health # Restore HP on level up
	current_energy = max_energy # Restore Energy on level up
	print("[CatCharacter] 🌟 ", name, " LEVELED UP to Level ", level, "! Next level requires ", max_xp, " XP.")


## Adds one level's worth of allocation pools.
## Points come from Data/Class_Progression.csv (per-level + milestone bonus; spell points only once
## the class's spellbook is unlocked).
func grant_level_points() -> void:
	var pts: Vector3i = ClassProgression.points_for_level(get_class_progression(), level)
	unspent_stat_points += maxi(0, pts.x)
	unspent_skill_points += maxi(0, pts.y)
	unspent_spell_points += maxi(0, pts.z)


## Applies one level-up dice roll (see LevelUpDice): adds bonus stat / skill / spell points and
## the permanent HP bonus, and uses up one pending roll. Returns the bonus dictionary.
func apply_level_roll(roll: int) -> Dictionary:
	var bonus: Dictionary = LevelUpDice.bonus_for_roll(roll)
	unspent_stat_points += int(bonus["stat"])
	var split: Vector2i = LevelUpDice.split_ability_points(int(bonus["ability"]), known_skills.size(), known_spells.size())
	unspent_skill_points += split.x
	unspent_spell_points += split.y
	bonus["skill"] = split.x
	bonus["spell"] = split.y
	var hp_pct: float = float(bonus["hp_percent"])
	if hp_pct > 0.0:
		var old_max: int = max_hp
		bonus_max_hp_percent += hp_pct
		_calculate_vitals()
		if stats:
			stats.health = mini(stats.max_health, stats.health + (stats.max_health - old_max))
			current_hp = stats.health
	pending_level_rolls = maxi(0, pending_level_rolls - 1)
	return bonus


func get_ability_rank(ability_id: String) -> int:
	if ability_id.is_empty():
		return 1
	if ability_ranks.has(ability_id):
		return maxi(1, int(ability_ranks[ability_id]))
	return 1


func has_unspent_points() -> bool:
	return unspent_stat_points > 0 or unspent_skill_points > 0 or unspent_spell_points > 0


## Applies a Level Up screen draft. Does not bump level or reset XP.
## stat_deltas: { "strength": 1, ... }
## skill_rank_ups / spell_rank_ups: ability ids to bump by +1 each.
func apply_level_up_allocation(
	stat_deltas: Dictionary,
	skill_rank_ups: Array[String],
	spell_rank_ups: Array[String]
) -> bool:
	var stats_spent: int = 0
	for key: Variant in stat_deltas.keys():
		var stat_name: String = str(key)
		var amount: int = int(stat_deltas[key])
		if amount <= 0:
			continue
		if not stat_name in self:
			continue
		set(stat_name, int(get(stat_name)) + amount)
		stats_spent += amount

	if stats_spent > unspent_stat_points:
		push_warning("[CatCharacter] apply_level_up_allocation overspent stats; clamping.")
		stats_spent = unspent_stat_points
	unspent_stat_points = maxi(0, unspent_stat_points - stats_spent)

	var skills_spent: int = 0
	for ability_id: String in skill_rank_ups:
		if ability_id.is_empty():
			continue
		ability_ranks[ability_id] = get_ability_rank(ability_id) + 1
		skills_spent += 1
	if skills_spent > unspent_skill_points:
		push_warning("[CatCharacter] apply_level_up_allocation overspent skill points; clamping.")
		skills_spent = unspent_skill_points
	unspent_skill_points = maxi(0, unspent_skill_points - skills_spent)

	var spells_spent: int = 0
	for ability_id: String in spell_rank_ups:
		if ability_id.is_empty():
			continue
		ability_ranks[ability_id] = get_ability_rank(ability_id) + 1
		spells_spent += 1
	if spells_spent > unspent_spell_points:
		push_warning("[CatCharacter] apply_level_up_allocation overspent spell points; clamping.")
		spells_spent = unspent_spell_points
	unspent_spell_points = maxi(0, unspent_spell_points - spells_spent)

	_calculate_vitals()
	if stats:
		stats.health = stats.max_health
	current_energy = max_energy
	print("[CatCharacter] Applied level-up allocation for %s (stats -%d, skills -%d, spells -%d)." % [
		name, stats_spent, skills_spent, spells_spent
	])
	return true

# =============================================================================
# ⚔️ ABILITY & EQUIPMENT MANAGERS
# =============================================================================


## True when this character's profession may equip `item` (weapon-type allowlist).
func can_equip_item(item: Resource) -> bool:
	if not is_instance_valid(item):
		return false
	var item_data: ItemData = item as ItemData
	if not is_instance_valid(item_data):
		return true
	var prof: ProfessionData = profession as ProfessionData
	if not is_instance_valid(prof):
		return true
	return prof.allows_weapon_type(item_data.weapon_type)


func equip_item(slot_name: String, item: Resource) -> bool:
	if not can_equip_item(item):
		return false

	if slot_name == "ACCESSORY":
		if equipment.get("ACCESSORY_1") == null:
			slot_name = "ACCESSORY_1"
		elif equipment.get("ACCESSORY_2") == null:
			slot_name = "ACCESSORY_2"
		else:
			slot_name = "ACCESSORY_1"

	if equipment.has(slot_name):
		equipment[slot_name] = item
		_recalculate_equipment_stats()
		return true
	return false


func unequip_item(slot_name: String) -> Resource:
	if slot_name == "ACCESSORY" and not equipment.has("ACCESSORY"):
		slot_name = "ACCESSORY_1"

	if equipment.has(slot_name):
		var item: Resource = equipment[slot_name]
		equipment[slot_name] = null
		_recalculate_equipment_stats()
		return item
	return null


func get_equipped_item(slot_name: String) -> Resource:
	if slot_name == "ACCESSORY" and not equipment.has("ACCESSORY"):
		return equipment.get("ACCESSORY_1", null)
	return equipment.get(slot_name, null)


func _recalculate_equipment_stats() -> void:
	equipment_bonus_attack = 0
	equipment_bonus_defense = 0
	equipment_bonus_speed = 0
	equipment_stat_bonuses.clear()

	for item_var in equipment.values():
		var item: ItemData = item_var as ItemData
		if not is_instance_valid(item):
			continue

		equipment_bonus_attack += item.attack_bonus
		equipment_bonus_defense += item.defense_bonus
		equipment_bonus_speed += item.speed_bonus

		var eff_stat: String = str(item.effect_stat).to_lower().strip_edges()
		var eff_amt: int = int(item.effect_amount)

		if not eff_stat.is_empty() and eff_amt != 0:
			var current: int = equipment_stat_bonuses.get(eff_stat, 0)
			equipment_stat_bonuses[eff_stat] = current + eff_amt

	equipment_changed.emit()


## Starting abilities for a new character (no-op once initialized). See AbilityRules.
func populate_starting_skills() -> void:
	AbilityRules.initialize_abilities(self)


## Kept for older callers: abilities are set up together in populate_starting_skills().
func populate_starting_spells() -> void:
	AbilityRules.initialize_abilities(self)


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


## Restores HP and Energy based on hours rested.
## Returns a Dictionary detailing actual HP and Energy gained.
func rest(hours: int) -> Dictionary:
	if hours <= 0 or current_hp <= 0:
		return { "hp_restored": 0, "energy_restored": 0 }

	# Base hourly recovery scaled by Vitality (HP) and Piety/Intelligence (Energy)
	var hp_per_hour: int = max(1, int(float(max_hp) * 0.10) + int(vitality * 0.25))
	var energy_per_hour: int = max(1, int(float(max_energy) * 0.15) + int(piety * 0.25))

	var total_hp_heal: int = hp_per_hour * hours
	var total_energy_heal: int = energy_per_hour * hours

	var old_hp: int = current_hp
	var old_energy: int = current_energy

	heal(total_hp_heal)
	current_energy = clampi(current_energy + total_energy_heal, 0, max_energy)

	var actual_hp_gained: int = current_hp - old_hp
	var actual_energy_gained: int = current_energy - old_energy

	return { "hp_restored": actual_hp_gained, "energy_restored": actual_energy_gained }

# =============================================================================
# STAT GETTER HELPERS FOR UI & COMBAT
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

	var key: String = str(stat_name).to_lower()
	return base_val + equipment_stat_bonuses.get(key, 0)


func get_equipment_stat_bonus(stat_name: StringName) -> int:
	var key: String = str(stat_name).to_lower()
	return equipment_stat_bonuses.get(key, 0)


func get_total_equipment_attack() -> int:
	return equipment_bonus_attack


func get_total_equipment_defense() -> int:
	return equipment_bonus_defense


func get_effective_strength() -> int:
	return get_effective_stat(&"strength")


func get_effective_speed() -> int:
	return get_effective_stat(&"speed")
