# res://Scripts/item_button.gd
extends "res://Scripts/UI/hud_toolbar_button.gd"
## ITEMS toolbar button. Sound, hover / press pop and shine live in hud_toolbar_button.gd.


func _init() -> void:
	action_type = "ITEMS"
	input_action = &"item_menu"
