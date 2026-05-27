# res://Scripts/Resources/CatCharacter.gd
extends Resource
class_name CatCharacter

@export_group("Identity")
@export var name: String = "New Recruit"
@export var breed: CatBreed
@export var profession: ProfessionData
@export var level: int = 1

@export_group("Core Attributes")
@export var strength: int = 8
@export var intelligence: int = 8
@export var piety: int = 8
@export var vitality: int = 8
@export var dexterity: int = 8
@export var speed: int = 8
@export var personality: int = 8

@export_group("Dynamic Vitals")
@export var current_hp: int = 10
@export var max_hp: int = 10
@export var current_energy: int = 10
@export var max_energy: int = 10

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
	current_hp = max_hp
	current_energy = max_energy

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
	current_hp = max_hp
	current_energy = max_energy

func _calculate_vitals() -> void:
	if profession and (profession.profession_name in ["Spartan", "Crusader", "Amazon"]):
		max_hp = vitality * 3
	else:
		max_hp = vitality * 2
	max_energy = intelligence + piety
