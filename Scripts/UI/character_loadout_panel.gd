# res://Scripts/UI/character_loadout_panel.gd
extends VBoxContainer
class_name CharacterLoadoutPanel

# Note: CatCharacter and ItemData are global class_names registered in Godot 4.
# No need for preload("res://resources/Item.gd") constants!

@onready var signal_bus: Node = get_node("/root/SignalBus")

# Cache character data if display_loadout is called before _ready()
var _cached_cat: CatCharacter = null
var _current_cat: CatCharacter = null


# Equipment Slot Buttons
@onready var slot_body: Button = %SlotBody as Button
@onready var slot_arms: Button = %SlotArms as Button
@onready var slot_legs: Button = %SlotLegs as Button
@onready var slot_feet: Button = %SlotFeet as Button
@onready var slot_left_hand: Button = %SlotLeftHand as Button
@onready var slot_right_hand: Button = %SlotRightHand as Button

func _ready() -> void:
	# Connect all button signals safely
	if slot_body: slot_body.pressed.connect(_on_slot_pressed.bind("BODY"))
	if slot_arms: slot_arms.pressed.connect(_on_slot_pressed.bind("ARMS"))
	if slot_legs: slot_legs.pressed.connect(_on_slot_pressed.bind("LEGS"))
	if slot_feet: slot_feet.pressed.connect(_on_slot_pressed.bind("FEET"))
	if slot_left_hand: slot_left_hand.pressed.connect(_on_slot_pressed.bind("LEFT_HAND"))
	if slot_right_hand: slot_right_hand.pressed.connect(_on_slot_pressed.bind("RIGHT_HAND"))

	if _cached_cat:
		display_loadout(_cached_cat)

## PUBLIC API: Populates the UI with a character's equipped ItemData resources
func display_loadout(cat: CatCharacter) -> void:
	if not is_node_ready():
		_cached_cat = cat
		return

	_cached_cat = null
	_current_cat = cat
	if not is_instance_valid(cat):
		return

	# Update each slot with corresponding ItemData or null
	_update_slot("BODY", cat.get_equipped_item("BODY") as ItemData)
	_update_slot("ARMS", cat.get_equipped_item("ARMS") as ItemData)
	_update_slot("LEGS", cat.get_equipped_item("LEGS") as ItemData)
	_update_slot("FEET", cat.get_equipped_item("FEET") as ItemData)
	_update_slot("LEFT_HAND", cat.get_equipped_item("LEFT_HAND") as ItemData)
	_update_slot("RIGHT_HAND", cat.get_equipped_item("RIGHT_HAND") as ItemData)

## Updates a single equipment slot's UI elements safely
func _update_slot(slot_name: String, item: ItemData) -> void:
	var slot_button: Button = null
	match slot_name:
		"BODY": slot_button = slot_body
		"ARMS": slot_button = slot_arms
		"LEGS": slot_button = slot_legs
		"FEET": slot_button = slot_feet
		"LEFT_HAND": slot_button = slot_left_hand
		"RIGHT_HAND": slot_button = slot_right_hand

	if not slot_button:
		return

	var icon_node := slot_button.get_node_or_null("MarginContainer/HBoxContainer/Icon") as TextureRect
	var name_label := slot_button.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/ItemName") as Label
	var status_label := slot_button.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/StatusVal") as Label

	if is_instance_valid(item):
		if name_label: 
			name_label.text = item.item_name
		
		if status_label:
			# If you add durability stats later, it reads them safely here
			if "current_durability" in item and "max_durability" in item:
				status_label.text = "DUR: %d/%d" % [item.get("current_durability"), item.get("max_durability")]
			else:
				status_label.text = "EQUIPPED"
				
		if icon_node:
			if "icon_path" in item and not str(item.get("icon_path")).is_empty():
				icon_node.texture = load(item.get("icon_path")) as Texture
			elif "icon" in item and item.get("icon") is Texture:
				icon_node.texture = item.get("icon") as Texture
			else:
				icon_node.texture = null
	else:
		if name_label: name_label.text = "-- Empty --"
		if status_label: status_label.text = ""
		if icon_node: icon_node.texture = null

## Signal handler for equipment slot presses
func _on_slot_pressed(slot_name: String) -> void:
	var equipped_item: ItemData = null
	if is_instance_valid(_current_cat):
		equipped_item = _current_cat.get_equipped_item(slot_name)

	print("CharacterLoadoutPanel: Requesting item popup for slot: ", slot_name, " Item: ", equipped_item)

	if get_tree().root.has_node("SignalBus"):
		SignalBus.popup_requested.emit("ITEM_ACTIONS", {
			"slot": slot_name,
			"item": equipped_item,
			"is_equipped": true
		})
