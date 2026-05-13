extends Resource
class_name CatCharacter

@export var name: String = "New Recruit"
@export var breed: CatBreed # Drag and drop a Breed resource here later
@export var level: int = 1

# Current dynamic stats
var current_hp: int = 10
var current_energy: int = 10

func initialize_stats() -> void:
	if breed:
		# A simple Wizardry-style HP calc: Constitution * 2
		current_hp = breed.base_constitution * 2
		current_energy = breed.base_intelligence + 5
