# res://resources/CatCharacter.gd
extends Resource
class_name CatCharacter

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
@export var equipment: Dictionary = {
	"BODY": null,
	"ARMS": null,
	"LEGS": null,
	"FEET": null,
	"LEFT_HAND": null,
	"RIGHT_HAND": null
}

@export_group("Abilities")
@export var known_spells: Array[Resource] = []
@export var known_skills: Array[Resource] = []


# =============================================================================
# 🏢 UI & SYSTEM WRAPPER PROPERTIES (Bridges requests to CharacterStats)
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
	get: return current_hp
	set(value): current_hp = value

var max_health: int:
	get: return max_hp
	set(value): max_hp = value

var current_mana: int:
	get: return current_energy
	set(value): current_energy = value

var max_mana: int:
	get: return max_energy
	set(value): max_energy = value


# =============================================================================
# ⚙️ LIFECYCLE & ABILITY INITIALIZATION
# =============================================================================

func _init() -> void:
	stats = CharacterStats.new()


## Sets up baseline character capabilities from breed and profession templates
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

	# 🎯 Populate abilities for Class and Breed
	populate_starting_skills()
	populate_starting_spells()


func _calculate_vitals() -> void:
	var prof_name: String = profession.get("profession_name") if is_instance_valid(profession) and "profession_name" in profession else ""
	if prof_name in ["Spartan", "Crusader", "Amazon"]:
		stats.max_health = vitality * 3
	else:
		stats.max_health = vitality * 2
	max_energy = intelligence + piety


## Auto-populates starting skills based on class and breed assignments
func populate_starting_skills() -> void:
	var skills_dir: String = "res://Data/Skills/"
	if not DirAccess.dir_exists_absolute(skills_dir):
		return

	var prof_name: String = profession.get("profession_name") if is_instance_valid(profession) and "profession_name" in profession else ""
	var breed_name_val: String = breed.get("breed_name") if is_instance_valid(breed) and "breed_name" in breed else ""

	var dir := DirAccess.open(skills_dir)
	if dir == null: return

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


## Auto-populates starting spells based on class's allowed spellbook(s)
func populate_starting_spells() -> void:
	var spells_dir: String = "res://Data/Spells/"
	if not DirAccess.dir_exists_absolute(spells_dir):
		return

	if not is_instance_valid(profession):
		return

	var sb_type_str: String = profession.get("spellbook_type") if "spellbook_type" in profession else ""
	if sb_type_str.is_empty() or sb_type_str == "None":
		return

	# Supports comma or pipe separated spellbooks e.g. "Soulwright, Archanist"
	var allowed_books: Array[String] = []
	for p in sb_type_str.split(","):
		for inner_p in p.split("|"):
			var trimmed := inner_p.strip_edges().to_upper()
			if not trimmed.is_empty():
				allowed_books.append(trimmed)

	var dir := DirAccess.open(spells_dir)
	if dir == null: return

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
						0: s_book_name = "ARCHANIST"
						1: s_book_name = "SOULWRIGHT"
						2: s_book_name = "MAESTER"
						3: s_book_name = "PSYNIC"
						_: s_book_name = str(s_book_val).to_upper()

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
# ⚔️ EQUIPMENT MANAGERS
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
	print("Recalculating stats based on equipment...")
