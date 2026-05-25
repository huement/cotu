# res://Scripts/Resources/CatCharacter.gd
extends Resource
class_name CatCharacter

@export_group("Identity")
@export var name: String = "New Recruit"
@export var breed: CatBreed
@export var profession: ProfessionData # <--- This fixes the property crash!
@export var level: int = 1

@export_group("Core Attributes")
var strength: int = 8
var intelligence: int = 8
var piety: int = 8
var vitality: int = 8
var dexterity: int = 8
var speed: int = 8
var personality: int = 8

@export_group("Dynamic Vitals")
var current_hp: int = 10
var max_hp: int = 10
var current_energy: int = 10
var max_energy: int = 10

## Sets up baseline character capabilities from spreadsheet data resources
func initialize_stats() -> void:
	if not breed:
		return
		
	# 1. Start with the chosen breed's raw baseline values from your CSV sheet
	strength = breed.base_strength
	intelligence = breed.base_intelligence
	piety = breed.base_piety
	vitality = breed.base_vitality
	dexterity = breed.base_dexterity
	speed = breed.base_speed
	personality = breed.base_personality
	
	# 2. In a later step, you can add random rolled bonus points here!
	# For now, if a profession requires higher attributes, we scale up to meet the requirement
	if profession:
		strength = max(strength, profession.req_strength)
		intelligence = max(intelligence, profession.req_intelligence)
		piety = max(piety, profession.req_piety)
		vitality = max(vitality, profession.req_vitality)
		dexterity = max(dexterity, profession.req_dexterity)
		speed = max(speed, profession.req_speed)
		personality = max(personality, profession.req_personality)
		
	# 3. Calculate dynamic maximum vitals off your final core statistics
	_calculate_vitals()
	
	# Set current bars to maximum capacity
	current_hp = max_hp
	current_energy = max_energy

func _calculate_vitals() -> void:
	# Classic Wizardry math: Heavy combat archetypes receive health scaling bonuses
	if profession and (profession.profession_name == "Spartan" or profession.profession_name == "Crusader" or profession.profession_name == "Amazon"):
		max_hp = vitality * 3
	else:
		max_hp = vitality * 2
		
	# Energy pools are derived natively off your mind/devotion capacity traits
	max_energy = intelligence + piety
