# res://Scripts/UI/universal_popup.gd
extends CanvasLayer
class_name UniversalPopup

@onready var panel_container: PanelContainer = $PanelContainer as PanelContainer
@onready var background_dimmer: ColorRect = $BackgroundDimmer as ColorRect
@onready var title_label: Label = %TitleLabel as Label
@onready var content_area: VBoxContainer = %ContentArea as VBoxContainer
@onready var confirm_button: TextureButton = %ConfirmButton as TextureButton

var active_action_type: StringName = &""
var active_data: Dictionary = {}

# Standalone Items Modal State & UI Pointers
var _selected_item: ItemData = null
var _selected_slot_index: int = -1
var _preview_title_label: Label = null
var _preview_desc_label: Label = null
var _preview_icon: TextureRect = null
var _items_use_btn: Button = null
var _items_drop_btn: Button = null
var _items_grid_instance: CharacterInventoryGrid = null

func _ready() -> void:
	if panel_container:
		panel_container.visible = false
	if background_dimmer:
		background_dimmer.visible = false
	
	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		bus.popup_requested.connect(_on_popup_requested)
		bus.battle_victory_popup_requested.connect(_on_popup_requested.bind(&"BATTLE_VICTORY"))
		
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)

## Catches incoming event requests and builds custom menus on the fly
func _on_popup_requested(action_type: StringName, data: Dictionary = {}) -> void:
	# 🎯 Intercept item selection when the Standalone ITEMS Modal is already open
	if action_type == &"ITEM_ACTIONS" and active_action_type == &"ITEMS":
		_update_items_preview(data)
		return

	active_action_type = action_type
	active_data = data
	_clear_content_area()
	
	match action_type:
		&"BATTLE_VICTORY":
			title_label.text = "VICTORY ACHIEVED"
			_build_battle_victory_ui(data)
		&"SEARCH":
			title_label.text = "SCANNING SYSTEM CORRIDORS"
			_build_search_ui()
		&"REST":
			title_label.text = "SET PURRGATORY CAMP DURATION"
			_build_rest_ui()
		&"ITEMS":
			title_label.text = "USEABLE ITEMS"
			_build_items_inventory_ui()
		&"ITEM_ACTIONS":
			title_label.text = "ITEM ACTION PROTOCOL"
			_build_item_actions_ui(data)
		&"ALL_SKILLS":
			title_label.text = "ALL KNOWN SKILLS PROTOCOL"
			_build_all_skills_popup_ui(data)
		&"ALL_SPELLS":
			title_label.text = "SPELLBOOK DIRECTORY"
			_build_all_spells_popup_ui(data)
		_:
			push_warning("UniversalPopup: Unknown action type requested: " + String(action_type))
			return
			
	if background_dimmer:
		background_dimmer.visible = true
	if panel_container:
		panel_container.visible = true

func _on_confirm_pressed() -> void:
	var payload: Dictionary = {}
	
	if active_action_type == &"REST":
		var slider := content_area.get_node_or_null("RestSlider") as HSlider
		if slider:
			payload["hours"] = int(slider.value)
			
	_emit_confirmation(active_action_type, payload)

func _clear_content_area() -> void:
	if confirm_button:
		confirm_button.visible = false
	for child in content_area.get_children():
		child.queue_free()

func _emit_confirmation(action_type: StringName, extra_data: Dictionary) -> void:
	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		bus.popup_confirmed.emit(action_type, extra_data)
		
	_close_modal()

func _close_modal() -> void:
	if background_dimmer:
		background_dimmer.visible = false
	if panel_container:
		panel_container.visible = false
	active_action_type = &""
	active_data.clear()

# =============================================================================
# 🛠️ DYNAMIC CONTENT GENERATION METHODS
# =============================================================================

## 1. SEARCH MODAL
func _build_search_ui() -> void:
	var info_text := Label.new()
	info_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_text.text = "Searching walls for hidden compartments...\nNo immediate micro-vibrations detected."
	content_area.add_child(info_text)

	var close_btn := _create_modal_button("CLOSE", Color(0.5, 0.5, 0.5, 1.0))
	close_btn.pressed.connect(_close_modal)
	
	var btn_center := HBoxContainer.new()
	btn_center.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_center.add_child(close_btn)
	content_area.add_child(btn_center)

## 2. REST MODAL
func _build_rest_ui() -> void:
	var info_text := Label.new()
	info_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_text.text = "Select rest duration (Hours):"
	content_area.add_child(info_text)
	
	var slider := HSlider.new()
	slider.name = "RestSlider"
	slider.min_value = 1
	slider.max_value = 12
	slider.value = 4
	slider.step = 1
	slider.custom_minimum_size = Vector2(200, 24)
	
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.text = "4 Hours"
	
	slider.value_changed.connect(func(val: float) -> void: 
		value_label.text = str(int(val)) + " Hours"
	)
	
	content_area.add_child(slider)
	content_area.add_child(value_label)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)

	var rest_btn := _create_modal_button("REST", Color(0.0, 0.9, 0.8, 1.0))
	rest_btn.pressed.connect(func() -> void:
		_emit_confirmation(&"REST", {"hours": int(slider.value)})
	)

	var cancel_btn := _create_modal_button("CANCEL", Color(0.5, 0.5, 0.5, 1.0))
	cancel_btn.pressed.connect(_close_modal)

	btn_hbox.add_child(rest_btn)
	btn_hbox.add_child(cancel_btn)
	content_area.add_child(btn_hbox)

## 3. STANDALONE USEABLE ITEMS MODAL
func _build_items_inventory_ui() -> void:
	_selected_item = null
	_selected_slot_index = -1

	# --- Top Item Info / Preview Header ---
	var preview_hbox := HBoxContainer.new()
	preview_hbox.custom_minimum_size = Vector2(0, 80)
	preview_hbox.add_theme_constant_override("separation", 16)

	# Large Icon Box Frame
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

	# Text Column (Title & Description)
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
	content_area.add_child(preview_hbox)

	var sep := HSeparator.new()
	content_area.add_child(sep)

	# --- Inventory Grid ---
	var inventory_grid_scene: PackedScene = preload("res://Scenes/UI/CharacterInventoryGrid.tscn")
	_items_grid_instance = inventory_grid_scene.instantiate() as CharacterInventoryGrid
	content_area.add_child(_items_grid_instance)

	if "inventory" in GameState:
		_items_grid_instance.display_inventory(GameState.inventory)

	# --- Bottom Action Footer Buttons ---
	var footer_hbox := HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	footer_hbox.add_theme_constant_override("separation", 12)

	_items_use_btn = _create_modal_button("USE", Color(0.0, 0.9, 0.9, 1.0))
	_items_drop_btn = _create_modal_button("DROP", Color(0.0, 0.8, 0.7, 1.0))
	var close_btn := _create_modal_button("CLOSE", Color(0.5, 0.5, 0.5, 1.0))

	_items_use_btn.disabled = true
	_items_drop_btn.disabled = true

	footer_hbox.add_child(_items_use_btn)
	footer_hbox.add_child(_items_drop_btn)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(spacer)
	footer_hbox.add_child(close_btn)

	content_area.add_child(footer_hbox)

	close_btn.pressed.connect(_close_modal)

	# Use Action Button
	_items_use_btn.pressed.connect(func() -> void:
		if is_instance_valid(_selected_item) and "inventory" in GameState:
			var active_cat: CatCharacter = GameState.get_active_cat() if GameState.has_method("get_active_cat") else null
			if is_instance_valid(active_cat) and _selected_slot_index >= 0:
				GameState.inventory.use_item(_selected_slot_index, active_cat)
				_items_grid_instance.display_inventory(GameState.inventory)
				_reset_items_preview()
	)

	# Drop Action Button
	_items_drop_btn.pressed.connect(func() -> void:
		if is_instance_valid(_selected_item) and "inventory" in GameState:
			GameState.inventory.remove_item(_selected_item)
			_items_grid_instance.display_inventory(GameState.inventory)
			_reset_items_preview()
	)

## Dynamic Preview Updater triggered when selecting an item in the grid
func _update_items_preview(data: Dictionary) -> void:
	var item: ItemData = data.get("item", null) as ItemData
	var slot_idx: int = data.get("index", -1)

	if is_instance_valid(item):
		_selected_item = item
		_selected_slot_index = slot_idx

		if _preview_title_label: _preview_title_label.text = item.item_name.to_upper()
		if _preview_desc_label: _preview_desc_label.text = item.description
		if _preview_icon: _preview_icon.texture = item.icon if "icon" in item else null

		if _items_use_btn: _items_use_btn.disabled = false
		if _items_drop_btn: _items_drop_btn.disabled = false

func _reset_items_preview() -> void:
	_selected_item = null
	_selected_slot_index = -1
	if _preview_title_label: _preview_title_label.text = "SELECT AN ITEM"
	if _preview_desc_label: _preview_desc_label.text = "Click any item in the grid below to inspect its details or use it."
	if _preview_icon: _preview_icon.texture = null
	if _items_use_btn: _items_use_btn.disabled = true
	if _items_drop_btn: _items_drop_btn.disabled = true

## 5. ALL SKILLS POPUP VIEW
func _build_all_skills_popup_ui(data: Dictionary) -> void:
	var cat: CatCharacter = data.get("character", null) as CatCharacter
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 200)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	if is_instance_valid(cat) and "known_skills" in cat and not cat.known_skills.is_empty():
		for skill in cat.known_skills:
			if skill is SkillData:
				var lbl := Label.new()
				lbl.text = "• %s (Proficiency: %d%%)\n  %s" % [skill.skill_name.to_upper(), skill.base_percentage, skill.description]
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 0.8, 1.0))
				vbox.add_child(lbl)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "No skills registered for this character."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_lbl)

	content_area.add_child(scroll)

	var close_btn := _create_modal_button("CLOSE", Color(0.5, 0.5, 0.5, 1.0))
	close_btn.pressed.connect(_close_modal)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_child(close_btn)
	content_area.add_child(btn_hbox)

## 6. ALL SPELLS POPUP VIEW
func _build_all_spells_popup_ui(data: Dictionary) -> void:
	var cat: CatCharacter = data.get("character", null) as CatCharacter
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 200)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	if is_instance_valid(cat) and "known_spells" in cat and not cat.known_spells.is_empty():
		for spell in cat.known_spells:
			if spell is SpellData:
				var lbl := Label.new()
				lbl.text = "• %s [%s] - Cost: %d EN\n  %s" % [spell.spell_name.to_upper(), spell.spell_title, spell.energy_cost, spell.description]
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 0.8, 1.0))
				vbox.add_child(lbl)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "No spells registered in this spellbook."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_lbl)

	content_area.add_child(scroll)

	var close_btn := _create_modal_button("CLOSE", Color(0.5, 0.5, 0.5, 1.0))
	close_btn.pressed.connect(_close_modal)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_child(close_btn)
	content_area.add_child(btn_hbox)
	
## 4. INDIVIDUAL ITEM ACTIONS MODAL (From Character Sheet)
func _build_item_actions_ui(data: Dictionary) -> void:
	var item: ItemData = data.get("item", null) as ItemData
	var slot_name: String = data.get("slot", "")
	var slot_idx: int = data.get("index", -1)
	
	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if is_instance_valid(item):
		name_label.text = item.item_name.to_upper() + "\n" + item.description
	elif not slot_name.is_empty():
		name_label.text = "SLOT: " + slot_name + " (EMPTY)"
	else:
		name_label.text = "NO ITEM SELECTED"
		
	content_area.add_child(name_label)
	
	var cat: CatCharacter = GameState.get_active_cat() if GameState.has_method("get_active_cat") else null
	var inv: Inventory = GameState.get("inventory") if "inventory" in GameState else null

	if is_instance_valid(item):
		if not slot_name.is_empty():
			_add_action_button("[ UNEQUIP ]", func() -> void:
				if is_instance_valid(cat):
					var unequipped: ItemData = cat.unequip_item(slot_name)
					if is_instance_valid(inv) and is_instance_valid(unequipped):
						inv.add_item(unequipped)
						
				_emit_confirmation(&"ITEM_ACTIONS", {
					"sub_action": "UNEQUIP",
					"slot": slot_name,
					"item": item
				})
				_refresh_party_ui()
			)
		else:
			if item.item_type == ItemData.ItemType.EQUIPMENT:
				_add_action_button("[ EQUIP ]", func() -> void:
					if is_instance_valid(cat):
						var target_slot: String = item.get_slot_string()
						var unequipped: ItemData = cat.unequip_item(target_slot)
						cat.equip_item(target_slot, item)
						if is_instance_valid(inv):
							inv.remove_item(item)
							if is_instance_valid(unequipped):
								inv.add_item(unequipped)
								
					_emit_confirmation(&"ITEM_ACTIONS", {
						"sub_action": "EQUIP",
						"index": slot_idx,
						"item": item
					})
					_refresh_party_ui()
				)
			elif item.item_type == ItemData.ItemType.CONSUMABLE:
				_add_action_button("[ USE ]", func() -> void:
					if is_instance_valid(inv) and slot_idx >= 0:
						inv.use_item(slot_idx, cat)
						
					_emit_confirmation(&"ITEM_ACTIONS", {
						"sub_action": "USE",
						"index": slot_idx,
						"item": item
					})
					_refresh_party_ui()
				)
				
			_add_action_button("[ DROP ]", func() -> void:
				if is_instance_valid(inv):
					inv.remove_item(item)
					
				_emit_confirmation(&"ITEM_ACTIONS", {
					"sub_action": "DROP",
					"index": slot_idx,
					"item": item
				})
				_refresh_party_ui()
			)

	_add_action_button("[ CANCEL ]", func() -> void:
		_close_modal()
	)

func _add_action_button(label_text: String, action_callable: Callable) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.pressed.connect(action_callable)
	content_area.add_child(btn)

func _refresh_party_ui() -> void:
	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		var active_idx: int = GameState.get("active_cat_index") if "active_cat_index" in GameState else 0
		bus.portrait_clicked.emit(active_idx)

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


## 7. BATTLE VICTORY SCREEN
func _build_battle_victory_ui(data: Dictionary) -> void:
	var enemies_killed: int = data.get("enemies_killed", 0)
	var total_xp: int = data.get("total_xp", 0)
	var living_members: int = data.get("living_members", 1)
	var xp_per_member: int = int(float(total_xp) / living_members) if living_members > 0 else 0

	var summary_label := Label.new()
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.text = "You defeated %d enemies!" % enemies_killed
	content_area.add_child(summary_label)

	var xp_label := Label.new()
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.text = "EXP Earned: %d / %d = %d XP each" % [total_xp, living_members, xp_per_member]
	content_area.add_child(xp_label)

	var confirm_btn := _create_modal_button("CONFIRM", Color(0.0, 0.9, 0.8, 1.0))
	confirm_btn.pressed.connect(_close_modal)

	var btn_center := HBoxContainer.new()
	btn_center.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_center.add_child(confirm_btn)
	content_area.add_child(btn_center)
