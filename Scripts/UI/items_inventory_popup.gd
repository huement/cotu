# res://Scripts/UI/items_inventory_popup.gd
extends VBoxContainer
class_name ItemsInventoryPopup

signal close_requested
signal target_selection_requested(item: ItemData, inv_slot_idx: int, acting_slot_idx: int)

var _selected_item: ItemData = null
var _selected_slot_index: int = -1

var _preview_title_label: Label = null
var _preview_desc_label: Label = null
var _preview_icon: TextureRect = null
var _items_use_btn: Button = null
var _items_drop_btn: Button = null
var _items_grid_instance: CharacterInventoryGrid = null

var active_action_type: StringName = &"ITEMS"
var active_data: Dictionary = {}


func setup(action_type: StringName, data: Dictionary = {}) -> void:
	active_action_type = action_type
	active_data = data
	_build_ui()


func _build_ui() -> void:
	_selected_item = null
	_selected_slot_index = -1

	# 1. Preview Header Area
	var preview_hbox := HBoxContainer.new()
	preview_hbox.custom_minimum_size = Vector2(0, 80)
	preview_hbox.add_theme_constant_override("separation", 16)

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(72, 72)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.04, 0.08, 0.1, 0.9)
	icon_style.border_width_left = 1
	icon_style.border_width_top = 1
	icon_style.border_width_right = 1
	icon_style.border_width_bottom = 1
	icon_style.border_color = Color(0.0, 0.8, 0.7, 0.8)
	icon_box.add_theme_stylebox_override("panel", icon_style)

	_preview_icon = TextureRect.new()
	_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_box.add_child(_preview_icon)
	preview_hbox.add_child(icon_box)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_preview_title_label = Label.new()
	_preview_title_label.text = "SELECT AN ITEM"
	_preview_title_label.add_theme_color_override("font_color", Color(0.0, 0.9, 0.8, 1.0))
	_preview_title_label.add_theme_font_size_override("font_size", 16)
	text_vbox.add_child(_preview_title_label)

	_preview_desc_label = Label.new()
	_preview_desc_label.text = "Click any item in the grid below to inspect its details or use it."
	_preview_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_desc_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.9))
	_preview_desc_label.add_theme_font_size_override("font_size", 12)
	text_vbox.add_child(_preview_desc_label)

	preview_hbox.add_child(text_vbox)
	add_child(preview_hbox)

	var sep := HSeparator.new()
	add_child(sep)

	# 2. Character Inventory Grid
	var inventory_grid_scene: PackedScene = load("res://Scenes/UI/CharacterInventoryGrid.tscn") as PackedScene
	if is_instance_valid(inventory_grid_scene):
		_items_grid_instance = inventory_grid_scene.instantiate() as CharacterInventoryGrid
		_items_grid_instance.custom_minimum_size = Vector2(360, 240)
		print("[DEBUG] UniversalPopup: Inventory grid instance created: ", 		_items_grid_instance)
		add_child(_items_grid_instance)

		if "inventory" in GameState and is_instance_valid(GameState.inventory):
			_items_grid_instance.display_inventory(GameState.inventory)

	# 3. Footer Action Buttons
	var footer_hbox := HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	footer_hbox.add_theme_constant_override("separation", 12)

	_items_use_btn = _create_modal_button("USE", Color(0.0, 0.9, 0.9, 1.0))
	_items_drop_btn = _create_modal_button("DROP", Color(0.0, 0.8, 0.7, 1.0))
	var close_btn_text: String = "CANCEL" if active_action_type == &"BATTLE_ITEMS" else "CLOSE"
	var close_btn := _create_modal_button(close_btn_text, Color(0.5, 0.5, 0.5, 1.0))

	_items_use_btn.disabled = true
	_items_drop_btn.disabled = true

	footer_hbox.add_child(_items_use_btn)
	footer_hbox.add_child(_items_drop_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(spacer)
	footer_hbox.add_child(close_btn)

	add_child(footer_hbox)

	# 4. Signal Connections
	close_btn.pressed.connect(func() -> void: close_requested.emit())
	_items_use_btn.pressed.connect(_on_use_pressed)
	_items_drop_btn.pressed.connect(_on_drop_pressed)


func update_preview(item: ItemData, slot_idx: int) -> void:
	if not is_instance_valid(item):
		_reset_preview()
		return

	_selected_item = item
	_selected_slot_index = slot_idx

	if _preview_title_label:
		_preview_title_label.text = item.item_name.to_upper()
	if _preview_desc_label:
		_preview_desc_label.text = item.description
	if _preview_icon:
		_preview_icon.texture = item.icon if "icon" in item else null

	var in_combat: bool = (active_action_type == &"BATTLE_ITEMS")
	var is_usable: bool = (
		item.can_be_used(in_combat)
		if item.has_method("can_be_used")
		else (item.is_consumable or item.item_type == ItemData.ItemType.CONSUMABLE or item.item_type == ItemData.ItemType.POTION)
	)

	if _items_use_btn:
		_items_use_btn.disabled = not is_usable
	if _items_drop_btn:
		_items_drop_btn.disabled = in_combat


func _reset_preview() -> void:
	_selected_item = null
	_selected_slot_index = -1
	if _preview_title_label:
		_preview_title_label.text = "SELECT AN ITEM"
	if _preview_desc_label:
		_preview_desc_label.text = "Click any item in the grid below to inspect its details or use it."
	if _preview_icon:
		_preview_icon.texture = null
	if _items_use_btn:
		_items_use_btn.disabled = true
	if _items_drop_btn:
		_items_drop_btn.disabled = true


func _on_use_pressed() -> void:
	if not is_instance_valid(_selected_item) or _selected_slot_index < 0:
		return

	var item_to_use: ItemData = _selected_item
	var inv_slot_idx: int = _selected_slot_index
	var in_battle: bool = (active_action_type == &"BATTLE_ITEMS")
	var acting_slot_idx: int = active_data.get("slot_index", -1) if in_battle else -1

	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("hud-button-press")

	target_selection_requested.emit(item_to_use, inv_slot_idx, acting_slot_idx)


func _on_drop_pressed() -> void:
	if is_instance_valid(_selected_item) and "inventory" in GameState:
		GameState.inventory.remove_item(_selected_item)
		if is_instance_valid(_items_grid_instance):
			_items_grid_instance.display_inventory(GameState.inventory)
		_reset_preview()


func _create_modal_button(text_val: String, color_val: Color) -> Button:
	var btn := Button.new()
	btn.text = text_val
	btn.custom_minimum_size = Vector2(100, 36)
	btn.focus_mode = Control.FOCUS_NONE

	var style := StyleBoxFlat.new()
	style.bg_color = color_val
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_right = 2

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color.BLACK)
	btn.add_theme_font_size_override("font_size", 14)
	return btn
