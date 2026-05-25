# res://resources/CatBreed.gd
extends Resource
class_name CatBreed

@export_group("Identity")
@export var breed_name: String = "Unknown Breed"
@export_multiline var description: String = ""

@export_group("Base Attributes")
@export var base_strength: int = 8
@export var base_intelligence: int = 8
@export var base_piety: int = 8
@export var base_vitality: int = 8
@export var base_dexterity: int = 8
@export var base_speed: int = 8
@export var base_personality: int = 8

@export_group("Environmental Resistances")
@export var disease_resistance: float = 0.0     # 0.0 to 1.0 (e.g., Sphinx bonus)
@export var radiation_resistance: float = 0.0   # 0.0 to 1.0
@export var cryo_insulation: float = 0.0        # 0.0 to 1.0 (e.g., Maine Coon bonus)
