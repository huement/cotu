# res://Scripts/Resources/CatCharacter.gd
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

# 🎯 ALIAS BRIDGES: Ensures HUD progress bars read values seamlessly
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
# ⚙️ LIFECYCLE & STAT INITIALIZATION
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

func _calculate_vitals() -> void:
	var prof_name: String = profession.get("profession_name") if is_instance_valid(profession) and "profession_name" in profession else ""
	if prof_name in ["Spartan", "Crusader", "Amazon"]:
		stats.max_health = vitality * 3
	else:
		stats.max_health = vitality * 2
	max_energy = intelligence + piety

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
