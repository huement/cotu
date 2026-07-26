# res://Scripts/UI/BattleActionBar.gd
class_name BattleActionBar
extends HBoxContainer

## Emitted when any combat command button inside the bar is pressed
signal action_selected(action_name: StringName)

@onready var attack_button: TextureButton = $AttackButton if has_node("AttackButton") else null
@onready var defend_button: TextureButton = $DefendButton if has_node("DefendButton") else null
@onready var spell_button: TextureButton = $SpellButton if has_node("SpellButton") else null
@onready var item_button: TextureButton = $ItemButton if has_node("ItemButton") else null

func _ready() -> void:
	# Connect button presses to emit the central action signal
	if is_instance_valid(attack_button):
		attack_button.pressed.connect(func(): action_selected.emit(&"ATTACK"))
	if is_instance_valid(defend_button):
		defend_button.pressed.connect(func(): action_selected.emit(&"DEFEND"))
	if is_instance_valid(spell_button):
		spell_button.pressed.connect(func(): action_selected.emit(&"SPELL"))
	if is_instance_valid(item_button):
		item_button.pressed.connect(func(): action_selected.emit(&"ITEM"))

func show_for_character(slot_index: int) -> void:
	show()
	# Optional: Enable/disable specific buttons based on character capabilities (e.g. disable spell button for non-casters)
