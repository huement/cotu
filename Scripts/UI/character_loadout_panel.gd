# res://Scripts/UI/character_loadout_panel.gd
extends VBoxContainer
class_name CharacterLoadoutPanel

@onready var signal_bus: Node = get_node_or_null("/root/SignalBus")

var _cached_cat: CatCharacter = null
var _current_cat: CatCharacter = null

# Cached default slot properties from the scene tree
var _default_titles: Dictionary = { }
var _default_icons: Dictionary = { }

# Equipment Slot Buttons
@onready var slot_head: Button = %SlotHead as Button if has_node("%SlotHead") else null
@onready var slot_body: Button = %SlotBody as Button if has_node("%SlotBody") else null
@onready var slot_arms: Button = %SlotArms as Button if has_node("%SlotArms") else null
@onready var slot_legs: Button = %SlotLegs as Button if has_node("%SlotLegs") else null
@onready var slot_feet: Button = %SlotFeet as Button if has_node("%SlotFeet") else null
@onready var slot_left_hand: Button = %SlotLeftHand as Button if has_node("%SlotLeftHand") else null
@onready var slot_right_hand: Button = %SlotRightHand as Button if has_node("%SlotRightHand") else null
@onready var slot_accessory_1: Button = %SlotAccessory1 as Button if has_node("%SlotAccessory1") else (%SlotAccessory as Button if has_node("%SlotAccessory") else null)
@onready var slot_accessory_2: Button = %SlotAccessory2 as Button if has_node("%SlotAccessory2") else (%SlotRing as Button if has_node("%SlotRing") else null)


func _ready() -> void:
	if slot_head:
		slot_head.pressed.connect(_on_slot_pressed.bind("HEAD"))
	if slot_body:
		slot_body.pressed.connect(_on_slot_pressed.bind("BODY"))
	if slot_arms:
		slot_arms.pressed.connect(_on_slot_pressed.bind("ARMS"))
	if slot_legs:
		slot_legs.pressed.connect(_on_slot_pressed.bind("LEGS"))
	if slot_feet:
		slot_feet.pressed.connect(_on_slot_pressed.bind("FEET"))
	if slot_left_hand:
		slot_left_hand.pressed.connect(_on_slot_pressed.bind("LEFT_HAND"))
	if slot_right_hand:
		slot_right_hand.pressed.connect(_on_slot_pressed.bind("RIGHT_HAND"))
	if slot_accessory_1:
		slot_accessory_1.pressed.connect(_on_slot_pressed.bind("ACCESSORY_1"))
	if slot_accessory_2:
		slot_accessory_2.pressed.connect(_on_slot_pressed.bind("ACCESSORY_2"))

	_cache_slot_defaults()

	if _cached_cat:
		display_loadout(_cached_cat)


## Caches initial scene titles and default icons (such as hexagon.png) for clean empty rendering
func _cache_slot_defaults() -> void:
	var slot_map: Dictionary = {
		"HEAD": slot_head,
		"BODY": slot_body,
		"ARMS": slot_arms,
		"LEGS": slot_legs,
		"FEET": slot_feet,
		"LEFT_HAND": slot_left_hand,
		"RIGHT_HAND": slot_right_hand,
		"ACCESSORY_1": slot_accessory_1,
		"ACCESSORY_2": slot_accessory_2,
	}

	for slot_key: String in slot_map:
		var slot_btn: Button = slot_map[slot_key] as Button
		if is_instance_valid(slot_btn):
			var name_label := slot_btn.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/ItemName") as Label
			var icon_node := slot_btn.get_node_or_null("MarginContainer/HBoxContainer/Icon") as TextureRect

			if name_label and not name_label.text.is_empty():
				_default_titles[slot_key] = name_label.text
			else:
				_default_titles[slot_key] = _get_fallback_slot_title(slot_key)

			if icon_node:
				_default_icons[slot_key] = icon_node.texture


func display_loadout(cat: CatCharacter) -> void:
	if not is_node_ready():
		_cached_cat = cat
		return

	_cached_cat = null
	_current_cat = cat
	if not is_instance_valid(cat):
		return

	_update_slot("HEAD", cat.get_equipped_item("HEAD") as ItemData)
	_update_slot("BODY", cat.get_equipped_item("BODY") as ItemData)
	_update_slot("ARMS", cat.get_equipped_item("ARMS") as ItemData)
	_update_slot("LEGS", cat.get_equipped_item("LEGS") as ItemData)
	_update_slot("FEET", cat.get_equipped_item("FEET") as ItemData)
	_update_slot("LEFT_HAND", cat.get_equipped_item("LEFT_HAND") as ItemData)
	_update_slot("RIGHT_HAND", cat.get_equipped_item("RIGHT_HAND") as ItemData)
	_update_slot("ACCESSORY_1", cat.get_equipped_item("ACCESSORY_1") as ItemData)
	_update_slot("ACCESSORY_2", cat.get_equipped_item("ACCESSORY_2") as ItemData)


func _update_slot(slot_name: String, item: ItemData) -> void:
	var slot_button: Button = _get_button_for_slot(slot_name)
	if not is_instance_valid(slot_button):
		return

	var existing_badge: Node = slot_button.get_node_or_null("QuantityBadge")
	if is_instance_valid(existing_badge):
		existing_badge.queue_free()

	var icon_node := slot_button.get_node_or_null("MarginContainer/HBoxContainer/Icon") as TextureRect
	var name_label := slot_button.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/ItemName") as Label
	var status_label := slot_button.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/StatusVal") as Label

	if is_instance_valid(item):
		# --- EQUIPPED ITEM STATE ---
		if name_label:
			name_label.text = item.item_name

		var item_qty: int = item.quantity if "quantity" in item else 1

		if status_label:
			if item_qty > 1:
				status_label.text = "QTY: %d" % item_qty
			elif "current_durability" in item and "max_durability" in item and int(item.get("max_durability")) > 0:
				status_label.text = "DUR: %d/%d" % [int(item.get("current_durability")), int(item.get("max_durability"))]
			else:
				status_label.text = "EQUIPPED"

		if icon_node:
			var tex: Texture2D = null
			if "icon" in item and item.get("icon") is Texture2D:
				tex = item.get("icon") as Texture2D
			elif "icon_path" in item and not str(item.get("icon_path")).is_empty() and ResourceLoader.exists(str(item.get("icon_path"))):
				tex = load(str(item.get("icon_path"))) as Texture2D

			icon_node.texture = tex if tex else _default_icons.get(slot_name, null)
	else:
		# --- EMPTY SLOT STATE ---
		if name_label:
			name_label.text = _default_titles.get(slot_name, _get_fallback_slot_title(slot_name))
		if status_label:
			status_label.text = "EMPTY"
		if icon_node:
			icon_node.texture = _default_icons.get(slot_name, null)


func _get_button_for_slot(slot_name: String) -> Button:
	match slot_name:
		"HEAD":
			return slot_head
		"BODY":
			return slot_body
		"ARMS":
			return slot_arms
		"LEGS":
			return slot_legs
		"FEET":
			return slot_feet
		"LEFT_HAND":
			return slot_left_hand
		"RIGHT_HAND":
			return slot_right_hand
		"ACCESSORY", "ACCESSORY_1":
			return slot_accessory_1
		"ACCESSORY_2":
			return slot_accessory_2
		_:
			return null


func _get_fallback_slot_title(slot_name: String) -> String:
	match slot_name:
		"HEAD":
			return "HEAD ARMOR"
		"BODY":
			return "BODY ARMOR"
		"ARMS":
			return "ARM GUARDS"
		"LEGS":
			return "LEG ARMOR"
		"FEET":
			return "MAG BOOTS"
		"LEFT_HAND":
			return "LEFT HAND"
		"RIGHT_HAND":
			return "RIGHT HAND"
		"ACCESSORY", "ACCESSORY_1", "ACCESSORY_2":
			return "ACCESSORY"
		_:
			return slot_name.replace("_", " ").to_upper()


func _on_slot_pressed(slot_name: String) -> void:
	var equipped_item: ItemData = null
	if is_instance_valid(_current_cat):
		equipped_item = _current_cat.get_equipped_item(slot_name) as ItemData

	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		bus.popup_requested.emit("ITEM_ACTIONS", { "slot": slot_name, "item": equipped_item, "is_equipped": true, "character": _current_cat })
