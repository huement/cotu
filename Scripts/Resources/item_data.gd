# res://Scripts/Resources/item_data.gd
class_name ItemData
extends Resource

enum ItemType {
	CONSUMABLE,
	EQUIPMENT,
	QUEST,
}

enum EquipmentSlot {
	NONE,
	BODY,
	ARMS,
	LEGS,
	FEET,
	LEFT_HAND,
	RIGHT_HAND
}

@export_group("Item Core Identity")
@export var item_id: String = ""
@export var item_name: String = "New Item"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.CONSUMABLE

@export_group("Equipment Specifications")
## Target slot when equipping this item
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0
@export var max_durability: int = 100
@export var current_durability: int = 100

@export_group("Consumable Effects")
## Example: {"heal": 25, "energy": 10}
@export var stat_effect: Dictionary = {}

## Returns string key matching CharacterLoadoutPanel slot keys
func get_slot_string() -> String:
	match equipment_slot:
		EquipmentSlot.BODY: return "BODY"
		EquipmentSlot.ARMS: return "ARMS"
		EquipmentSlot.LEGS: return "LEGS"
		EquipmentSlot.FEET: return "FEET"
		EquipmentSlot.LEFT_HAND: return "LEFT_HAND"
		EquipmentSlot.RIGHT_HAND: return "RIGHT_HAND"
		_: return ""
