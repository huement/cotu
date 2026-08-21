# res://Scripts/Resources/item_data.gd
class_name ItemData
extends Resource

enum ItemType {
	MISC,
	WEAPON,
	ARMOR,
	POTION,
	CONSUMABLE,
	EQUIPMENT,
	QUEST,
}

enum TargetType {
	SINGLE_PARTY_MEMBER,
	ALL_PARTY,
	SINGLE_ENEMY,
	ALL_ENEMIES,
	NONE,
}

enum EquipmentSlot {
	NONE,
	BODY,
	ARMS,
	LEGS,
	FEET,
	LEFT_HAND,
	RIGHT_HAND,
	HEAD,
	BOTH_HANDS,
	ACCESSORY,
}

enum WeaponType {
	NONE,
	BLADE,
	BASH,
	RANGED,
}

enum EffectElement {
	NONE,
	MAGIC,
	BLADE,
	RANGED,
	LIFE,
	BASH,
}

enum ElementalBase {
	NONE,
	FIRE,
	EARTH,
	WATER,
	AIR,
	LIFE,
	DARK,
	BOLT,
}

@export_group("Item Core Identity")
@export var item_id: String = ""
@export var item_name: String = "New Item"
@export_multiline var description: String = ""
@export var icon_path: String = ""
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.MISC
@export var target_type: TargetType = TargetType.SINGLE_PARTY_MEMBER
@export var quantity: int = 1
@export var can_use_in_battle: bool = true
@export var can_use_in_field: bool = true

@export_group("Equipment & Combat Specifications")
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
@export var weapon_type: WeaponType = WeaponType.NONE
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0
@export var speed_bonus: int = 0
@export var credit_value: int = 0
@export var max_durability: int = 100
@export var current_durability: int = 100

@export_group("Consumables & Potions")
@export var is_consumable: bool = false
@export var heal_amount: int = 0
@export var energy_restore: int = 0
@export var stat_effect: Dictionary = { }
@export var mana_restore: int = 0
@export var health_restore: int = 0

@export_group("Magic & Special Effects")
@export var effects: String = ""
@export var effect_amount: float = 0.0
@export var effect_element: EffectElement = EffectElement.NONE
@export var effect_stat: String = ""


## Returns string key matching CharacterLoadoutPanel slot keys ("BODY", "LEFT_HAND", "RIGHT_HAND", etc.)
func get_slot_string() -> String:
	match equipment_slot:
		EquipmentSlot.BODY:
			return "BODY"
		EquipmentSlot.ARMS:
			return "ARMS"
		EquipmentSlot.LEGS:
			return "LEGS"
		EquipmentSlot.FEET:
			return "FEET"
		EquipmentSlot.LEFT_HAND:
			return "LEFT_HAND"
		EquipmentSlot.RIGHT_HAND, EquipmentSlot.BOTH_HANDS:
			return "RIGHT_HAND"
		EquipmentSlot.HEAD:
			return "HEAD"
		EquipmentSlot.ACCESSORY:
			return "ACCESSORY"
		_:
			return ""


func can_be_used(in_combat: bool) -> bool:
	var is_usable: bool = is_consumable or item_type == ItemType.CONSUMABLE or item_type == ItemType.POTION
	if not is_usable:
		return false
	return can_use_in_battle if in_combat else can_use_in_field
