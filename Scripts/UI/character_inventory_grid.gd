# res://Scripts/UI/character_inventory_grid.gd
extends VBoxContainer
class_name CharacterInventoryGrid

@onready var grid_container: GridContainer = %GridContainer as GridContainer

var _connected_inventory: Inventory = null

## PUBLIC API: Binds to your custom Inventory resource and connects signal listeners
func display_inventory(inventory: Inventory) -> void:
	if not grid_container:
		push_error("CharacterInventoryGrid: %GridContainer reference is missing!")
		return

	# Disconnect from previous inventory if switching targets
	if is_instance_valid(_connected_inventory):
		if _connected_inventory.item_added.is_connected(_on_inventory_changed):
			_connected_inventory.item_added.disconnect(_on_inventory_changed)
		if _connected_inventory.item_removed.is_connected(_on_inventory_changed):
			_connected_inventory.item_removed.disconnect(_on_inventory_changed)

	_connected_inventory = inventory

	# Connect to your inventory.gd custom signals for live UI updates
	if is_instance_valid(_connected_inventory):
		_connected_inventory.item_added.connect(_on_inventory_changed)
		_connected_inventory.item_removed.connect(_on_inventory_changed)

	_render_grid()

func _on_inventory_changed(_item: ItemData) -> void:
	_render_grid()

func _render_grid() -> void:
	if not grid_container:
		return

	# Clear previous slot nodes
	for child in grid_container.get_children():
		child.queue_free()

	var item_list: Array[ItemData] = []
	var max_capacity: int = 24

	if is_instance_valid(_connected_inventory):
		item_list = _connected_inventory.get_items()
		max_capacity = _connected_inventory.max_slots

	# 1. Draw occupied item slots
	for i in range(item_list.size()):
		_create_slot_button(item_list[i], i)

	# 2. Draw empty placeholder slots
	var empty_count: int = max(0, max_capacity - item_list.size())
	for _i in range(empty_count):
		var empty_btn := _create_styled_button()
		empty_btn.disabled = true
		grid_container.add_child(empty_btn)

func _create_slot_button(item: ItemData, slot_idx: int) -> void:
	var btn := _create_styled_button()

	if is_instance_valid(item):
		if "icon" in item and item.icon is Texture2D:
			var icon_rect := TextureRect.new()
			icon_rect.texture = item.icon
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon_rect.offset_left = 4
			icon_rect.offset_top = 4
			icon_rect.offset_right = -4
			icon_rect.offset_bottom = -4
			btn.add_child(icon_rect)
		else:
			# Fallback: display abbreviated item name (e.g. "CATN")
			btn.text = item.item_name.left(4).to_upper()

		btn.tooltip_text = "%s\n%s" % [item.item_name, item.description]
		btn.pressed.connect(func() -> void:
			if get_tree().root.has_node("SignalBus"):
				SignalBus.popup_requested.emit("ITEM_ACTIONS", {
					"item": item,
					"index": slot_idx
				})
		)
	else:
		btn.disabled = true

	grid_container.add_child(btn)

## Generates a retro sci-fi dark cyan slot frame
func _create_styled_button() -> Button:
	var btn := Button.new()
	# Set minimum height (Y), but let X expand to fill column width
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.1, 0.14, 0.8)
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(0.0, 0.8, 0.7, 0.4)
	style_normal.corner_radius_top_left = 2
	style_normal.corner_radius_bottom_right = 2
	
	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.12, 0.2, 0.25, 0.9)
	style_hover.border_color = Color(0.0, 1.0, 0.8, 0.9)

	var style_disabled := style_normal.duplicate() as StyleBoxFlat
	style_disabled.bg_color = Color(0.04, 0.05, 0.07, 0.4)
	style_disabled.border_color = Color(0.2, 0.25, 0.3, 0.2)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8, 1.0))
	btn.add_theme_font_size_override("font_size", 10)

	return btn
