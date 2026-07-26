# res://resources/Party.gd
extends Resource
class_name DungeonParty

## The 6-Slot Structural Matrix for Wizardry-style Party:
## Slots 0, 1, 2 = Front Row (Exposed to Melee)
## Slots 3, 4, 5 = Back Row  (Protected from Melee, Supports Ranged/Magic)
## 
## NOTE: Typed as Array[Resource] to avoid cyclic compiler deadlocks in Godot 4
@export var slots: Array[Resource] = [null, null, null, null, null, null]


# ==============================================================================
# 1. INITIALIZATION
# ==============================================================================
func _init() -> void:
	# Ensure the 6 slots are initialized without overwriting existing data
	if slots.is_empty() or slots.size() != 6:
		slots = [null, null, null, null, null, null]


# ==============================================================================
# 2. ROW & POSITION UTILITIES
# ==============================================================================
static func is_front_row(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index <= 2

static func is_back_row(slot_index: int) -> bool:
	return slot_index >= 3 and slot_index <= 5

## Swaps two party members in the matrix (e.g., moving a cat to the Back Row)
func swap_slots(from_idx: int, to_idx: int) -> void:
	if from_idx >= 0 and from_idx < 6 and to_idx >= 0 and to_idx < 6:
		var temp: Resource = slots[from_idx]
		slots[from_idx] = slots[to_idx]
		slots[to_idx] = temp

## Returns an array filtered down strictly to living combatants
func get_viable_combatants() -> Array[Resource]:
	var active_units: Array[Resource] = []
	for cat_res in slots:
		if is_instance_valid(cat_res):
			var hp: int = cat_res.get("current_hp") if "current_hp" in cat_res else (cat_res.get("current_health") if "current_health" in cat_res else 0)
			if hp > 0:
				active_units.append(cat_res)
	return active_units


# ==============================================================================
# 3. STARTER PARTY GENERATOR
# ==============================================================================
## Called explicitly when starting a New Game session
func setup_starter_party() -> void:
	var spartan_prof: Resource = load("res://Data/Classes/Spartan.tres")
	var warden_prof: Resource = load("res://Data/Classes/Warden.tres")
	var wizard_prof: Resource = load("res://Data/Classes/Wizard.tres")

	# --- PROFILE 1: FRONT ROW TANK (Slot 0) ---
	slots[0] = _create_starter_cat(
		"Commander Whiskers", 
		"Maine Coon", 
		25, 
		8, 
		spartan_prof, 
		"res://Data/Portraits/Spartan.png"
	)

	# --- PROFILE 2: FRONT ROW MELEE (Slot 1) ---
	slots[1] = _create_starter_cat(
		"Baron Von Hiss", 
		"Siamese", 
		20, 
		14, 
		warden_prof, 
		"res://Data/Portraits/Warden.png"
	)

	# --- PROFILE 3: BACK ROW CASTER (Slot 3) ---
	slots[3] = _create_starter_cat(
		"Sage Psych-Meow", 
		"Sphinx", 
		15, 
		11, 
		wizard_prof, 
		"res://Data/Portraits/Wizard.png"
	)

func _create_starter_cat(cat_name: String, breed_name: String, vit: int, spd: int, prof: Resource, portrait: String) -> Resource:
	var breed := CatBreed.new()
	breed.breed_name = breed_name
	breed.base_vitality = vit
	breed.base_speed = spd
	
	var cat := CatCharacter.new()
	cat.name = cat_name
	cat.breed = breed
	cat.profession = prof
	cat.portrait_path = portrait
	if cat.has_method("initialize_stats"):
		cat.initialize_stats()
	return cat
