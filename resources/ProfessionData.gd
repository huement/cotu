# res://resources/ProfessionData.gd
extends Resource
class_name ProfessionData

@export_group("Identity")
@export var profession_name: String = "Spartan"
@export var classic_counterpart: String = "Fighter"

@export_group("Minimum Gate Requirements")
@export var req_strength: int = 10
@export var req_intelligence: int = 10
@export var req_piety: int = 10
@export var req_vitality: int = 10
@export var req_dexterity: int = 10
@export var req_speed: int = 10
@export var req_personality: int = 10

@export_group("Magic Configuration")
@export_enum("None", "Mage", "Priest", "Alchemist", "Psionic") var spellbook_type: String = "None"
@export var level_spells_unlock: int = 0

@export_group("Innate Skill Modification Hooks")
@export var native_abilities: Array[String] = []
