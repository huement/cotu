extends Resource
class_name CatBreed

@export var breed_name: String = "Unknown Breed"
@export_multiline var description: String = ""

@export_group("Base Stats")
@export var base_strength: int = 10
@export var base_agility: int = 10
@export var base_intelligence: int = 10
@export var base_constitution: int = 10

@export_group("Resistances")
@export var disease_resistance: float = 0.0 # 0.0 to 1.0 (Sphinx cats get a bonus!)
@export var radiation_resistance: float = 0.0
