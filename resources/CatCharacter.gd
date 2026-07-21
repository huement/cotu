# res://Resources/CatCharacter.gd
extends Resource
class_name CatCharacter

const CharacterStats = preload("res://Models/character_stats.gd")

@export_group("Identity")
@export var name: String = "New Recruit"
@export var breed: CatBreed
@export var profession: ProfessionData
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

@export_group("Dynamic Vitals")
var stats: CharacterStats = CharacterStats.new()
var current_energy: int = 10
var max_energy: int = 10

@export_group("Equipment")
@export var inventory: Inventory
@export var equipment: Dictionary = {
	"BODY": null,
	"ARMS": null,
	"LEGS": null,
	"FEET": null,
	"LEFT_HAND": null,
	"RIGHT_HAND": null
}

@export_group("Abilities")
@export var known_spells: Array[SpellData] = []
@export var known_skills: Array[SkillData] = []

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
	# This is a placeholder for the logic that will iterate through
	# all non-null items in the equipment dictionary and apply their stat
	# modifiers to the character.
	# For now, we'll just print a message.
	print("Recalculating stats based on equipment...")



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

# =============================================================================
# ⚙️ LIFECYCLE INITIALIZATION METHODS
# =============================================================================

func _init() -> void:
	stats = CharacterStats.new()

## Sets up baseline character capabilities from breed and profession templates
func initialize_stats() -> void:
	if not breed: return
	
	strength = breed.base_strength
	intelligence = breed.base_intelligence
	piety = breed.base_piety
	vitality = breed.base_vitality
	dexterity = breed.base_dexterity
	speed = breed.base_speed
	personality = breed.base_personality
	
	if profession:
		strength = max(strength, profession.req_strength)
		intelligence = max(intelligence, profession.req_intelligence)
		piety = max(piety, profession.req_piety)
		vitality = max(vitality, profession.req_vitality)
		dexterity = max(dexterity, profession.req_dexterity)
		speed = max(speed, profession.req_speed)
		personality = max(personality, profession.req_personality)
		
	_calculate_vitals()
	stats.health = stats.max_health # FIXED: Corrected assignment flow to start with full HP
	current_energy = max_energy

func take_damage(amount: int) -> void:
	stats.take_damage(amount)

func heal(amount: int) -> void:
	stats.heal(amount)

## Merges final allocated bonus points into core stats
func assemble_character(final_stats: Dictionary) -> void:
	strength = final_stats.get("strength", strength)
	intelligence = final_stats.get("intelligence", intelligence)
	piety = final_stats.get("piety", piety)
	vitality = final_stats.get("vitality", vitality)
	dexterity = final_stats.get("dexterity", dexterity)
	speed = final_stats.get("speed", speed)
	personality = final_stats.get("personality", personality)
	
	_calculate_vitals()
	stats.health = stats.max_health # FIXED: Corrected assignment flow to start with full HP
	current_energy = max_energy

func _calculate_vitals() -> void:
	if profession and (profession.profession_name in ["Spartan", "Crusader", "Amazon"]):
		stats.max_health = vitality * 3
	else:
		stats.max_health = vitality * 2
	max_energy = intelligence + piety
