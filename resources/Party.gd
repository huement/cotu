extends Resource
class_name Party

signal member_changed(slot_index: int, character: CatCharacter)

# 6 slots: 0-2 = Front Row, 3-5 = Back Row
@export var members: Array[CatCharacter] = [null, null, null, null, null, null]

# Shared inventory for "Group" items (keys, maps, torches)
@export var shared_pouch: Inventory = Inventory.new()

func set_member(slot: int, character: CatCharacter) -> void:
	if slot >= 0 and slot < 6:
		members[slot] = character
		member_changed.emit(slot, character)

func get_front_row() -> Array[CatCharacter]:
	return members.slice(0, 3).filter(func(c): return c != null)

func get_back_row() -> Array[CatCharacter]:
	return members.slice(3, 6).filter(func(c): return c != null)
