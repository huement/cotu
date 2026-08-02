# res://Scripts/UI/character_inventory_grid.gd
extends VBoxContainer
class_name CharacterInventoryGrid

@onready var grid_container: GridContainer = %GridContainer as GridContainer

var _connected_inventory: Inventory = null


func display_inventory(inventory: Inventory) -> void:
	if not grid_container:
		push_error("CharacterInventoryGrid: %GridContainer reference is missing!")
		return

	if is_instance_valid(_connected_inventory):
		if _connected_inventory.item_added.is_connected(_on_inventory_changed):
			_connected_inventory.item_added.disconnect(_on_inventory_changed)
		if _connected_inventory.item_removed.is_connected(_on_inventory_changed):
			_connected_inventory.item_removed.disconnect(_on_inventory_changed)

	_connected_inventory = inventory

	if is_instance_valid(_connected_inventory):
		_connected_inventory.item_added.connect(_on_inventory_changed)
		_connected_inventory.item_removed.connect(_on_inventory_changed)

	_render_grid()


func _on_inventory_changed(_item: ItemData) -> void:
	_render_grid()


func _render_grid() -> void:
	if not grid_container:
		return

	for child in grid_container.get_children():
		child.queue_free()

	var item_list: Array[ItemData] = []
	var max_capacity: int = 24

	if is_instance_valid(_connected_inventory):
		item_list = _connected_inventory.get_items()
		max_capacity = _connected_inventory.max_slots

	# Group duplicate items and calculate counts
	var unique_items: Array[ItemData] = []
	var item_counts: Dictionary = {}

	for item in item_list:
		if not is_instance_valid(item):
			continue

		var existing: ItemData = null
		for u in unique_items:
			if not item.item_id.is_empty() and u.item_id == item.item_id:
				existing = u
				break
			elif u.item_name == item.item_name:
				existing = u
				break

		if existing != null:
			item_counts[existing] += 1
		else:
			unique_items.append(item)
			item_counts[item] = 1

	# 1. Render occupied slots with icons and quantity badges
	for i in range(unique_items.size()):
		var item: ItemData = unique_items[i]
		var count: int = item_counts.get(item, 1)
		var original_idx: int = item_list.find(item)
		_create_slot_button(item, original_idx, count)

	# 2. Draw empty placeholder slots
	var empty_slots: int = max(0, max_capacity - unique_items.size())
	for _i in range(empty_slots):
		var empty_btn := _create_styled_button()
		empty_btn.disabled = true
		grid_container.add_child(empty_btn)


func _create_slot_button(item: ItemData, slot_idx: int, count: int = 1) -> void:
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
			btn.text = item.item_name.left(4).to_upper()

		_add_quantity_counter(btn, count)

		btn.tooltip_text = "%s (x%d)\n%s" % [item.item_name, count, item.description]
		btn.pressed.connect(func() -> void:
			if get_tree().root.has_node("SignalBus"):
				SignalBus.popup_requested.emit("ITEM_ACTIONS", {
					"item": item,
					"index": slot_idx,
					"count": count
				})
		)
	else:
		btn.disabled = true

	grid_container.add_child(btn)


func _add_quantity_counter(btn: Button, count: int) -> void:
	if count <= 1:
		return

	var count_label := Label.new()
	count_label.text = "%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	count_label.offset_left = 2
	count_label.offset_top = 2
	count_label.offset_right = -4
	count_label.offset_bottom = -2

	count_label.add_theme_font_size_override("font_size", 11)
	count_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	count_label.add_theme_constant_override("outline_size", 4)

	btn.add_child(count_label)


func _create_styled_button() -> Button:
	var btn := Button.new()
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
