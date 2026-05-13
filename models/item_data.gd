class_name ItemData
extends Resource

enum ItemType {
	CONSUMABLE,
	EQUIPMENT,
	QUEST,
}

@export var item_name: String = ""
@export var description: String = ""
@export var stat_effect: Dictionary = {}
@export var item_type: ItemType = ItemType.CONSUMABLE
