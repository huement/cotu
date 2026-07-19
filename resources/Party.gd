extends Resource
class_name DungeonParty

## The absolute 6-slot structural matrix array constraint
## Slots 0, 1, 2 = Front Row (Exposed to melee)
## Slots 3, 4, 5 = Back Row  (Safe from melee, supports range/magic)
@export var slots: Array[CatCharacter] = [null, null, null, null, null, null]

## Programmatic Constructor: Instantly hardcodes your core test squad on execution
func _init() -> void:
	_generate_fixed_starter_party()

func _generate_fixed_starter_party() -> void:
	# --- PROFILE 1: FRONT ROW TANK ---
	var mc_breed := CatBreed.new()
	mc_breed.breed_name = "Maine Coon"
	mc_breed.base_vitality = 25 # Fixed: Scales out to 50 HP via your _calculate_vitals() rule
	mc_breed.base_speed = 8     # Fixed: Maps cleanly to breed base attributes
	
	var cat1 := CatCharacter.new()
	cat1.name = "Commander Whiskers" # Fixed: Maps to your CatCharacter.gd identity field
	cat1.breed = mc_breed
	cat1.portrait_path = "res://Data/Portraits/Spartan.png" # 🎯 Map Spartan asset
	cat1.initialize_stats() # Combined Lifecycle: Automatically generates and sets up HP, Energy, and Stats!
	slots[0] = cat1 # Placed in Front Row Left
	
	# --- PROFILE 2: FRONT ROW MELEE ---
	var siamese_breed := CatBreed.new()
	siamese_breed.breed_name = "Siamese"
	siamese_breed.base_vitality = 20 # Scales out to 40 HP
	siamese_breed.base_speed = 14
	
	var cat2 := CatCharacter.new()
	cat2.name = "Baron Von Hiss"
	cat2.breed = siamese_breed
	cat2.portrait_path = "res://Data/Portraits/Warden.png"
	cat2.initialize_stats()
	slots[1] = cat2 # Placed in Front Row Center
	
	# --- PROFILE 3: BACK ROW CASTER ---
	var sphinx_breed := CatBreed.new()
	sphinx_breed.breed_name = "Sphinx"
	sphinx_breed.base_vitality = 15 # Scales out to 30 HP
	sphinx_breed.base_speed = 11
	
	var cat4 := CatCharacter.new()
	cat4.name = "Sage Psych-Meow"
	cat4.breed = sphinx_breed
	cat4.portrait_path = "res://Data/Portraits/Wizard.png"
	cat4.initialize_stats()
	slots[3] = cat4 # Placed in Back Row Left

## Row Position Query Utilities
func is_front_row(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index <= 2

func is_back_row(slot_index: int) -> bool:
	return slot_index >= 3 and slot_index <= 5

## Returns an array filtered down strictly to living combatants
func get_viable_combatants() -> Array[CatCharacter]:
	var active_units: Array[CatCharacter] = []
	for cat in slots:
		if cat != null and not cat.stats.health <= 0: # Checks component framework safety boundaries
			active_units.append(cat)
	return active_units
