# res://Scripts/Resources/loot_item.gd
class_name LootItem
extends Resource

signal pre_roll
signal post_roll
signal hit

@export var item: ItemData
@export var probability: int = 10
@export var is_unique: bool = false
@export var should_drop_always: bool = false
@export var is_enabled: bool = true


func _init(p_item: ItemData = null, p_probability: int = 10, p_unique: bool = false, p_always_drop: bool = false, p_enabled: bool = true) -> void:
	item = p_item
	probability = p_probability
	is_unique = p_unique
	should_drop_always = p_always_drop
	is_enabled = p_enabled
