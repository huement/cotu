class_name ItemStack
extends RefCounted

signal quantity_changed(new_quantity: int)

var item_data: ItemData
var quantity: int = 1:
	set(value):
		quantity = max(0, value)
		quantity_changed.emit(quantity)

func _init(p_item_data: ItemData = null, p_quantity: int = 1) -> void:
	item_data = p_item_data
	quantity = p_quantity

func consume(amount: int = 1) -> bool:
	if not item_data or not item_data.is_consumable:
		return false

	if quantity >= amount:
		quantity -= amount
		return true
	return false

func is_empty() -> bool:
	return quantity <= 0
