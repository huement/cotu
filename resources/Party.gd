# res://resources/Party.gd
extends Resource
class_name DungeonParty

## The 6-Slot Structural Matrix for Wizardry-style Party:
## Slots 0, 1, 2, 3 = Front Row (Exposed to Melee)  [1-based: Slots 1–4]
## Slots 4, 5       = Back Row  (Supports Ranged/Magic) [1-based: Slots 5–6]
##
## NOTE: Typed as Array[Resource] to avoid cyclic compiler deadlocks in Godot 4
@export var slots: Array[Resource] = [null, null, null, null, null, null]


# ==============================================================================
# 1. INITIALIZATION
# ==============================================================================
func _init() -> void:
	if slots.is_empty() or slots.size() != 6:
		slots = [null, null, null, null, null, null]


# ==============================================================================
# 2. ROW & POSITION UTILITIES
# ==============================================================================
## Swaps two party members in the matrix (e.g., moving a cat to the Back Row)
func swap_slots(from_idx: int, to_idx: int) -> void:
	if from_idx >= 0 and from_idx < 6 and to_idx >= 0 and to_idx < 6:
		var temp: Resource = slots[from_idx]
		slots[from_idx] = slots[to_idx]
		slots[to_idx] = temp


## Returns total number of living/active characters in Front Row
func get_front_row_count() -> int:
	var count: int = 0
	for cat_res in slots:
		if is_instance_valid(cat_res):
			var is_front: bool = bool(cat_res.get("is_front_row")) if "is_front_row" in cat_res else true
			if is_front:
				count += 1
	return count


## Assigns a character's row and reorganizes the 6-slot matrix
func set_character_row(cat: Resource, target_front: bool) -> void:
	if not is_instance_valid(cat):
		return

	if "is_front_row" in cat:
		cat.set("is_front_row", target_front)

	reorganize_party_matrix()


## Rebuilds matrix so Front Row cats occupy Slots 0-2 and Back Row cats occupy Slots 3-5
func reorganize_party_matrix() -> void:
	var front_cats: Array[Resource] = []
	var back_cats: Array[Resource] = []

	for cat_res in slots:
		if is_instance_valid(cat_res):
			var is_front: bool = bool(cat_res.get("is_front_row")) if "is_front_row" in cat_res else true
			if is_front:
				front_cats.append(cat_res)
			else:
				back_cats.append(cat_res)

	var new_slots: Array[Resource] = [null, null, null, null, null, null]

	for i in range(min(3, front_cats.size())):
		new_slots[i] = front_cats[i]

	for i in range(min(3, back_cats.size())):
		new_slots[3 + i] = back_cats[i]

	slots = new_slots

	var sb: Node = Engine.get_main_loop().root.get_node_or_null("SignalBus") if Engine.get_main_loop() else null
	if sb and sb.has_signal("party_roster_updated"):
		sb.party_roster_updated.emit(slots)


## Returns an array filtered down strictly to living combatants
func get_viable_combatants() -> Array[Resource]:
	var active_units: Array[Resource] = []
	for cat_res in slots:
		if is_instance_valid(cat_res):
			var hp: int = cat_res.get("current_hp") if "current_hp" in cat_res else (cat_res.get("current_health") if "current_health" in cat_res else 0)
			if hp > 0:
				active_units.append(cat_res)
	return active_units
