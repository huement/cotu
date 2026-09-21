# res://Scripts/universal_popup.gd
extends CanvasLayer
class_name UniversalPopup

@onready var panel_container: PanelContainer = $PanelContainer as PanelContainer
@onready var background_dimmer: ColorRect = $BackgroundDimmer as ColorRect
@onready var title_label: Label = %TitleLabel as Label
@onready var content_area: VBoxContainer = %ContentArea as VBoxContainer
@onready var confirm_button: TextureButton = %ConfirmButton as TextureButton
@export var shake_interval: float = 0.35
@export var shake_trauma_amount: float = 0.45 # Increased from 0.12 to yield noticeable camera wobble (0.45^2 = ~0.20 power)

var active_action_type: StringName = &""
var active_data: Dictionary = { }

# Standalone Items Modal State & UI Pointers
var _selected_item: ItemData = null
var _selected_slot_index: int = -1
var _preview_title_label: Label = null
var _preview_desc_label: Label = null
var _preview_icon: TextureRect = null
var _items_use_btn: Button = null
var _items_drop_btn: Button = null
var _items_grid_instance: CharacterInventoryGrid = null

const BATTLE_VICTORY_SCENE: PackedScene = preload("res://Scenes/UI/BattleVictoryPopup.tscn")
@export var skills_spells_popup_scene: PackedScene = preload("res://Scenes/UI/SkillsSpellsPopup.tscn")

# Aura Shader & Shake Control
var _aura_rect: ColorRect = null
var _aura_material: ShaderMaterial = null
var _is_aura_active: bool = false
var _shake_timer: float = 0.0


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
func _on_popup_requested(action_type: StringName, data: Dictionary = { }) -> void:
	# 🎯 Guard: Ignore ABILITY_INFO so UniversalPopup does not destroy its content
	if action_type == &"ABILITY_INFO":
		return

	# Intercept item selection when the Standalone ITEMS Modal is already open
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
		&"ALL_SKILLS", &"ALL_SPELLS", &"SPELLBOOK":
			title_label.text = ""
			_build_skills_spells_popup_ui(action_type, data)
		&"CHEST_LOOT":
			title_label.text = "CONTAINER CONTENTS"
			_build_chest_loot_ui(data)
		&"LORE_POPUP":
			var title_str: String = str(data.get("title", "ARCHIVE LOG")).to_upper()
			title_label.text = title_str
			_build_lore_popup_ui(data)
		_:
			push_warning("UniversalPopup: Unknown action type requested: " + String(action_type))
			return

	if background_dimmer:
		background_dimmer.visible = true
	if panel_container:
		panel_container.visible = true


func _on_confirm_pressed() -> void:
	var payload: Dictionary = { }
	if is_instance_valid(AudioManager):
		AudioManager.play_ui_sound("button-confirm")
	if active_action_type == &"REST":
		var slider := content_area.get_node_or_null("RestSlider") as HSlider
		if slider:
			payload["hours"] = int(slider.value)

	_emit_confirmation(active_action_type, payload)


func _clear_content_area() -> void:
	if confirm_button:
		confirm_button.visible = false
	if title_label:
		title_label.visible = true
	_apply_popup_margins(false)
	
	for child in content_area.get_children():
		content_area.remove_child(child)
		child.queue_free()
		
	if panel_container:
		panel_container.reset_size()


func display_popup(title_text: String, content_node: Control, options: Dictionary = { }) -> void:
	# 1. Hide TitleLabel when empty so VBoxContainer collapses the top 20px separation
	var title_lbl := %TitleLabel as Label
	if title_lbl:
		title_lbl.text = title_text
		title_lbl.visible = not title_text.is_empty()

	# 2. Hide ConfirmButton if the popup provides its own action/close buttons
	var show_confirm: bool = options.get("show_confirm", true)
	var confirm_btn := %ConfirmButton as TextureButton
	if confirm_btn:
		confirm_btn.visible = show_confirm

	# 3. Dynamically adjust outer margins for full-bleed UI popups
	var is_flush_ui: bool = options.get("flush_margins", false)
	var main_margin := $PanelContainer/MarginContainer as MarginContainer
	if main_margin:
		var top_margin: int = 0 if (is_flush_ui or title_text.is_empty()) else 15
		var side_margin: int = 0 if is_flush_ui else 15
		main_margin.add_theme_constant_override("margin_top", top_margin)
		main_margin.add_theme_constant_override("margin_left", side_margin)
		main_margin.add_theme_constant_override("margin_right", side_margin)
		main_margin.add_theme_constant_override("margin_bottom", side_margin)

	# Attach content_node to %ContentArea as normal
	# var content_area := %ContentArea as VBoxContainer
	if content_area and content_node:
		content_area.add_child(content_node)


func _emit_confirmation(action_type: StringName, extra_data: Dictionary) -> void:
	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		bus.popup_confirmed.emit(action_type, extra_data)

	_close_modal()


func _close_modal() -> void:
	_stop_aura_effect()
	if background_dimmer:
		background_dimmer.visible = false
	if panel_container:
		panel_container.visible = false
	active_action_type = &""
	active_data.clear()


# Add _build_chest_loot_ui() to res://Scripts/universal_popup.gd:
func _build_chest_loot_ui(data: Dictionary) -> void:
	var chest_node: Node3D = data.get("chest", null) as Node3D
	var loot_items: Array[ItemData] = []
	if data.has("loot") and data["loot"] is Array:
		for item in (data["loot"] as Array):
			if item is ItemData:
				loot_items.append(item as ItemData)
	var gold: int = int(data.get("gold", 0))

	var loot_popup := LootPopup.new()
	content_area.add_child(loot_popup)
	loot_popup.setup_loot_display(chest_node, loot_items, gold)
	loot_popup.closed.connect(_close_modal)


# When Player uses SearchButton to scan the area around them
func _build_search_ui() -> void:
	# Trigger search scan SFX (res://Audio/Player/search.mp3)
	if is_instance_valid(AudioManager):
		AudioManager.play_search_sound()
		
	var info_text := Label.new()
	info_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var nearby_details: Array[String] = []

	if is_instance_valid(player) and "current_grid_pos" in player:
		var p_cell: Vector2i = player.get("current_grid_pos")
		var interactables: Array[Node] = get_tree().get_nodes_in_group(&"dungeon_interactables")

		for obj in interactables:
			if is_instance_valid(obj) and obj.has_method("get_grid_pos"):
				var o_cell: Vector2i = obj.call("get_grid_pos") as Vector2i
				var dist: int = absi(o_cell.x - p_cell.x) + absi(o_cell.y - p_cell.y)
				if dist <= 2:
					var obj_name: String = obj.name
					if "object_id" in obj:
						obj_name = str(obj.get("object_id")).capitalize()
					nearby_details.append("- %s detected (%d tiles away)" % [obj_name, dist])

	if nearby_details.is_empty():
		info_text.text = "Searching corridors for hidden compartments...\nNo immediate micro-vibrations or anomalies detected."
	else:
		info_text.text = "SCAN RESULTS:\n" + "\n".join(nearby_details) + "\n\nFace object and press 'E' or 'SEARCH' to interact."

	content_area.add_child(info_text)

	var close_btn := _create_modal_button("CLOSE", Color(0.5, 0.5, 0.5, 1.0))
	close_btn.pressed.connect(_close_modal)

	var btn_center := HBoxContainer.new()
	btn_center.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_center.add_child(close_btn)
	content_area.add_child(btn_center)


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

	slider.value_changed.connect(
		func(val: float) -> void:
			value_label.text = str(int(val)) + " Hours",
	)

	content_area.add_child(slider)
	content_area.add_child(value_label)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)

	var rest_btn := _create_modal_button("REST", Color(0.0, 0.9, 0.8, 1.0))
	rest_btn.pressed.connect(
		func() -> void:
			_emit_confirmation(&"REST", { "hours": int(slider.value) }),
	)

	var cancel_btn := _create_modal_button("CANCEL", Color(0.5, 0.5, 0.5, 1.0))
	cancel_btn.pressed.connect(_close_modal)

	btn_hbox.add_child(rest_btn)
	btn_hbox.add_child(cancel_btn)
	content_area.add_child(btn_hbox)


func _build_items_inventory_ui() -> void:
	_selected_item = null
	_selected_slot_index = -1

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
	content_area.add_child(preview_hbox)

	var sep := HSeparator.new()
	content_area.add_child(sep)

	var inventory_grid_scene: PackedScene = preload("res://Scenes/UI/CharacterInventoryGrid.tscn")
	_items_grid_instance = inventory_grid_scene.instantiate() as CharacterInventoryGrid
	content_area.add_child(_items_grid_instance)

	if "inventory" in GameState:
		_items_grid_instance.display_inventory(GameState.inventory)

	var footer_hbox := HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	footer_hbox.add_theme_constant_override("separation", 12)

	_items_use_btn = _create_modal_button("USE", Color(0.0, 0.9, 0.9, 1.0))
	_items_drop_btn = _create_modal_button("DROP", Color(0.0, 0.8, 0.7, 1.0))
	var close_btn := _create_modal_button("CANCEL" if active_action_type == &"BATTLE_ITEMS" else "CLOSE", Color(0.5, 0.5, 0.5, 1.0))

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

	_items_use_btn.pressed.connect(
		func() -> void:
			if not is_instance_valid(_selected_item) or _selected_slot_index < 0:
				return

			var item_to_use: ItemData = _selected_item
			var inv_slot_idx: int = _selected_slot_index
			var in_battle: bool = (active_action_type == &"BATTLE_ITEMS")
			var acting_slot_idx: int = active_data.get("slot_index", -1) if in_battle else -1

			GameLogger.info("UniversalPopup: USE clicked for %s (Slot %d, Acting Slot %d)" % [item_to_use.item_name, inv_slot_idx, acting_slot_idx])

			match item_to_use.target_type:
				ItemData.TargetType.NONE, ItemData.TargetType.ALL_PARTY, ItemData.TargetType.ALL_ENEMIES:
					_execute_item_use_direct(item_to_use, inv_slot_idx, acting_slot_idx, -1)
					_close_modal()
				ItemData.TargetType.SINGLE_PARTY_MEMBER, ItemData.TargetType.SINGLE_ENEMY:
					_build_item_target_selection_ui(item_to_use, inv_slot_idx, acting_slot_idx)
	)

	_items_drop_btn.pressed.connect(
		func() -> void:
			if is_instance_valid(_selected_item) and "inventory" in GameState:
				GameState.inventory.remove_item(_selected_item)
				_items_grid_instance.display_inventory(GameState.inventory)
				_reset_items_preview(),
	)


func _build_item_target_selection_ui(item: ItemData, inv_slot_idx: int, acting_slot_idx: int) -> void:
	_clear_content_area()

	var header_lbl := Label.new()
	header_lbl.text = "SELECT TARGET FOR %s" % item.item_name.to_upper()
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8, 1.0))
	header_lbl.add_theme_font_size_override("font_size", 16)
	content_area.add_child(header_lbl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 180)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	content_area.add_child(scroll)

	var is_in_battle: bool = (acting_slot_idx >= 0)

	if is_in_battle:
		var combatants: Array = active_data.get("combatants", [])
		var is_ally_target: bool = (item.target_type == ItemData.TargetType.SINGLE_PARTY_MEMBER or item.target_type == ItemData.TargetType.ALL_PARTY)

		var valid_targets: Array = []
		for c in combatants:
			var is_player: bool = c.get("is_player") if "is_player" in c else false
			var hp: int = c.get("current_hp") if "current_hp" in c else 0
			if is_ally_target and is_player and hp > 0:
				valid_targets.append(c)
			elif not is_ally_target and not is_player and hp > 0:
				valid_targets.append(c)

		if valid_targets.is_empty():
			valid_targets = combatants

		for c in valid_targets:
			var c_name: String = str(c.get("name")).to_upper() if "name" in c else "TARGET"
			var c_hp: int = int(c.get("current_hp")) if "current_hp" in c else 0
			var c_max_hp: int = int(c.get("max_hp")) if "max_hp" in c else 1
			var c_slot: int = int(c.get("slot_index")) if "slot_index" in c else 0
			var c_ref: Resource = c.get("ref") as Resource if "ref" in c else null

			var btn := _create_target_card_button(c_name, c_hp, c_max_hp, c_ref)
			btn.pressed.connect(
				func() -> void:
					_execute_item_use_direct(item, inv_slot_idx, acting_slot_idx, c_slot)
					_close_modal(),
			)
			grid.add_child(btn)
	else:
		var gs: Node = get_tree().root.get_node_or_null("GameState")
		if is_instance_valid(gs) and "current_party" in gs and gs.current_party:
			var party_slots: Array = gs.current_party.get("slots") as Array
			for idx in range(party_slots.size()):
				var cat: Resource = party_slots[idx] as Resource
				if is_instance_valid(cat):
					var c_name: String = (
						str(cat.get("character_name")).to_upper()
						if "character_name" in cat and not str(cat.get("character_name")).is_empty()
						else (str(cat.get("name")).to_upper() if "name" in cat else "PARTY MEMBER")
					)
					var c_hp: int = int(cat.get("current_hp")) if "current_hp" in cat else 0
					var c_max_hp: int = int(cat.get("max_hp")) if "max_hp" in cat else 1

					var btn := _create_target_card_button(c_name, c_hp, c_max_hp, cat)
					var target_idx: int = idx
					btn.pressed.connect(
						func() -> void:
							_execute_item_use_direct(item, inv_slot_idx, -1, target_idx)
							_close_modal(),
					)
					grid.add_child(btn)

	var cancel_btn := _create_modal_button("CANCEL", Color(0.5, 0.5, 0.5, 1.0))
	cancel_btn.pressed.connect(_close_modal)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_child(cancel_btn)
	content_area.add_child(btn_hbox)


func _create_target_card_button(c_name: String, c_hp: int, c_max_hp: int, portrait_res: Resource) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(170, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	btn.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if is_instance_valid(portrait_res):
		if "portrait" in portrait_res and portrait_res.get("portrait") is Texture2D:
			icon_rect.texture = portrait_res.get("portrait")
		elif "portrait_texture" in portrait_res and portrait_res.get("portrait_texture") is Texture2D:
			icon_rect.texture = portrait_res.get("portrait_texture")
		elif "portrait_path" in portrait_res and ResourceLoader.exists(str(portrait_res.get("portrait_path"))):
			icon_rect.texture = load(str(portrait_res.get("portrait_path"))) as Texture2D

	hbox.add_child(icon_rect)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var title_lbl := Label.new()
	title_lbl.text = c_name
	title_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8, 1.0))
	title_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(title_lbl)

	var hp_lbl := Label.new()
	hp_lbl.text = "HP: %d / %d" % [c_hp, c_max_hp]
	hp_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	hp_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(hp_lbl)

	hbox.add_child(vbox)

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.06, 0.1, 0.14, 0.9)
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(0.0, 0.8, 0.7, 0.4)

	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.12, 0.25, 0.3, 0.9)
	style_hover.border_color = Color(0.0, 1.0, 0.8, 0.9)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)

	return btn


func _execute_item_use_direct(item: ItemData, inv_slot_idx: int, acting_slot_idx: int, target_slot_idx: int) -> void:
	if acting_slot_idx >= 0:
		GameLogger.combat("UniversalPopup: Direct Item Use in Battle (Acting Slot %d, Item: %s, Target: %d)" % [acting_slot_idx, item.item_name, target_slot_idx])
		var target_mgr: Node = get_tree().root.get_node_or_null("TargetSelectionManager")
		if is_instance_valid(target_mgr) and target_mgr.has_method("start_item_target_selection"):
			target_mgr.call("start_item_target_selection", item, inv_slot_idx, acting_slot_idx)

		if get_tree().root.has_node("SignalBus"):
			SignalBus.player_action_selected.emit(acting_slot_idx, &"ITEM", max(0, target_slot_idx))
	else:
		var gs: Node = get_tree().root.get_node_or_null("GameState")
		if is_instance_valid(gs) and "inventory" in gs and gs.inventory != null:
			var target_cat: Resource = null
			var resolved_target_idx: int = target_slot_idx

			if resolved_target_idx < 0:
				resolved_target_idx = gs.get("active_cat_index") if "active_cat_index" in gs else 0

			if "current_party" in gs and gs.current_party:
				var slots: Array = gs.current_party.get("slots") as Array
				if resolved_target_idx >= 0 and resolved_target_idx < slots.size():
					target_cat = slots[resolved_target_idx] as Resource

			if not is_instance_valid(target_cat) and gs.has_method("get_active_cat"):
				target_cat = gs.get_active_cat()

			if is_instance_valid(target_cat):
				if is_instance_valid(AudioManager):
					AudioManager.play_ui_sound("button-confirm")
				var success: bool = gs.inventory.use_item(inv_slot_idx, target_cat)
				GameLogger.info("UniversalPopup: Direct Field Item Use result = %s" % [str(success)])
				if success and get_tree().root.has_node("SignalBus"):
					if target_cat.get("current_hp") != null:
						SignalBus.character_health_changed.emit(resolved_target_idx, target_cat.get("current_hp"))
					if target_cat.get("current_energy") != null:
						SignalBus.character_mana_changed.emit(resolved_target_idx, target_cat.get("current_energy"))


func _update_items_preview(data: Dictionary) -> void:
	var item: ItemData = data.get("item", null) as ItemData
	var slot_idx: int = data.get("index", -1)

	if is_instance_valid(item):
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


func _reset_items_preview() -> void:
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


## Renders the styled popup scene inside the universal popup modal
func _build_skills_spells_popup_ui(action_type: StringName, data: Dictionary) -> void:
	var cat: CatCharacter = data.get("character", null) as CatCharacter
	print("UniversalPopup: Building Skills/Spells Popup for character: ", cat.name if is_instance_valid(cat) else "null", " with action_type: ", action_type)

	# 1. Determine initial tab mode
	var initial_mode: SkillsSpellsPopup.Mode = SkillsSpellsPopup.Mode.SPELLS
	if data.has("mode"):
		initial_mode = data["mode"] as SkillsSpellsPopup.Mode
	elif action_type == &"ALL_SKILLS":
		initial_mode = SkillsSpellsPopup.Mode.SKILLS
	else:
		initial_mode = SkillsSpellsPopup.Mode.SPELLS

	# 2. Hide default confirm button and title label to collapse VBoxContainer gaps
	if confirm_button:
		confirm_button.visible = false

	var title_lbl := %TitleLabel as Label
	if title_lbl:
		title_lbl.text = ""
		title_lbl.visible = false

	# 3. Apply flush margins directly to the parent containers
	_apply_popup_margins(true)

	if not skills_spells_popup_scene:
		return

	var popup_node: Control = skills_spells_popup_scene.instantiate() as Control
	content_area.add_child(popup_node)

	if popup_node is SkillsSpellsPopup:
		var popup_instance := popup_node as SkillsSpellsPopup
		if is_instance_valid(cat):
			popup_instance.display_character_abilities(cat, initial_mode)

		popup_instance.closed.connect(_close_modal)


## Helper method to adjust container margins for standard vs flush modals
func _apply_popup_margins(is_flush: bool) -> void:
	var main_margin := $PanelContainer/MarginContainer as MarginContainer
	if main_margin:
		var pad: int = 0 if is_flush else 15
		main_margin.add_theme_constant_override("margin_top", pad)
		main_margin.add_theme_constant_override("margin_left", pad)
		main_margin.add_theme_constant_override("margin_right", pad)
		main_margin.add_theme_constant_override("margin_bottom", pad)

	var content_margin := $PanelContainer/MarginContainer/VBoxContainer/MarginContainer as MarginContainer
	if content_margin:
		var inner_pad: int = 0 if is_flush else 5
		content_margin.add_theme_constant_override("margin_top", inner_pad)
		content_margin.add_theme_constant_override("margin_bottom", inner_pad)


## INDIVIDUAL ITEM ACTIONS MODAL (From Character Sheet)
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

	var cat: Resource = data.get("character", null) as Resource
	if not is_instance_valid(cat) and GameState.has_method("get_active_cat"):
		cat = GameState.get_active_cat() as Resource

	var inv: Resource = GameState.get("inventory") if "inventory" in GameState else null

	if is_instance_valid(item):
		if not slot_name.is_empty():
			# 🛡️ UNEQUIP Action (Clicked from CharacterLoadoutPanel)
			var unequip_action := func() -> void:
				if is_instance_valid(cat) and cat.has_method("unequip_item"):
					var unequipped: ItemData = cat.unequip_item(slot_name) as ItemData
					if is_instance_valid(inv) and is_instance_valid(unequipped) and inv.has_method("add_item"):
						inv.add_item(unequipped)
				_emit_confirmation(&"ITEM_ACTIONS", { "sub_action": "UNEQUIP", "slot": slot_name, "item": item })
				_refresh_party_ui()

			_add_action_button("[ UNEQUIP ]", unequip_action)
		else:
			# ⚔️ EQUIP Action (Clicked from CharacterInventoryGrid)
			var is_equippable: bool = item.equipment_slot != ItemData.EquipmentSlot.NONE or \
					item.item_type in [ItemData.ItemType.EQUIPMENT, ItemData.ItemType.WEAPON, ItemData.ItemType.ARMOR]

			if is_equippable:
				var equip_action := func() -> void:
					if is_instance_valid(cat):
						var target_slot: String = item.get_slot_string()
						if target_slot.is_empty():
							target_slot = "LEFT_HAND"

						# Aggregate total quantity of matching stack items in inventory
						var total_qty: int = 0
						var items_to_remove: Array[ItemData] = []
						if is_instance_valid(inv):
							for inv_item in inv.get_items():
								if is_instance_valid(inv_item) and (
									(not item.item_id.is_empty() and inv_item.item_id == item.item_id) or
									(inv_item.item_name == item.item_name)
								):
									total_qty += inv_item.quantity
									items_to_remove.append(inv_item)

						item.quantity = max(1, total_qty)

						# Remove all matching stack instances from inventory
						if is_instance_valid(inv):
							for r_item in items_to_remove:
								inv.remove_item(r_item)

						# Swap equipment in loadout
						var unequipped: ItemData = cat.unequip_item(target_slot) as ItemData if cat.has_method("unequip_item") else null
						if cat.has_method("equip_item"):
							cat.equip_item(target_slot, item)
						if is_instance_valid(inv) and is_instance_valid(unequipped):
							inv.add_item(unequipped)

					_emit_confirmation(&"ITEM_ACTIONS", { "sub_action": "EQUIP", "index": slot_idx, "item": item })	
					if is_instance_valid(AudioManager):
						AudioManager.play_ui_sound("button-confirm")
					_refresh_party_ui()

				_add_action_button("[ EQUIP ]", equip_action)

			# 🧪 USE Action (Consumables / Potions)
			elif item.item_type == ItemData.ItemType.CONSUMABLE or item.item_type == ItemData.ItemType.POTION or item.is_consumable:
				if is_instance_valid(AudioManager):
					AudioManager.play_potion_sound()
				var use_action := func() -> void:
					match item.target_type:
						ItemData.TargetType.NONE, ItemData.TargetType.ALL_PARTY, ItemData.TargetType.ALL_ENEMIES:
							_execute_item_use_direct(item, slot_idx, -1, -1)
							_close_modal()
						ItemData.TargetType.SINGLE_PARTY_MEMBER, ItemData.TargetType.SINGLE_ENEMY:
							_build_item_target_selection_ui(item, slot_idx, -1)

				_add_action_button("[ USE ]", use_action)

			# 🗑️ DROP Action
			var drop_action := func() -> void:
				if is_instance_valid(inv) and inv.has_method("remove_item"):
					inv.remove_item(item)
				_emit_confirmation(&"ITEM_ACTIONS", { "sub_action": "DROP", "index": slot_idx, "item": item })
				_refresh_party_ui()

			_add_action_button("[ DROP ]", drop_action)

	var cancel_action := func() -> void:
		_close_modal()

	_add_action_button("[ CANCEL ]", cancel_action)


func _refresh_party_ui() -> void:
	# 🎯 Save session whenever item actions (equip, unequip, drop, use) occur!
	if GameState.has_method("save_game"):
		GameState.save_game()

	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		var active_idx: int = GameState.get("active_character_index") if "active_character_index" in GameState else 0
		bus.portrait_clicked.emit(active_idx)


func _add_action_button(label_text: String, action_callable: Callable) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.pressed.connect(action_callable)
	content_area.add_child(btn)


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


func _build_battle_victory_ui(data: Dictionary) -> void:
	# Instantiates the dedicated component scene
	var victory_popup: BattleVictoryPopup = BATTLE_VICTORY_SCENE.instantiate() as BattleVictoryPopup
	content_area.add_child(victory_popup)

	# Initialize data and connect confirmation signal
	victory_popup.setup_victory_display(data)
	victory_popup.victory_confirmed.connect(
		func() -> void:
			_emit_confirmation(&"BATTLE_VICTORY", data),
	)


func _build_lore_popup_ui(data: Dictionary) -> void:
	var body_text: String = str(data.get("body", "No legible data decoded."))
	var aura_preset: String = str(data.get("aura_type", "bad"))

	if aura_preset != "none":
		_start_aura_effect(aura_preset)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 160)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl := Label.new()
	lbl.text = body_text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	lbl.add_theme_font_size_override("font_size", 13)
	scroll.add_child(lbl)

	content_area.add_child(scroll)

	var close_btn := _create_modal_button("CLOSE", Color(0.0, 0.7, 0.8, 1.0))
	close_btn.pressed.connect(_close_modal)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_child(close_btn)
	content_area.add_child(btn_hbox)
	
	
func _process(delta: float) -> void:
	if _is_aura_active:
		_shake_timer += delta
		if _shake_timer >= shake_interval:
			_shake_timer = 0.0
			if get_tree().root.has_node("SignalBus"):
				SignalBus.camera_shake_requested.emit(shake_trauma_amount)


func _configure_aura_preset(preset_type: String) -> void:
	_ensure_aura_rect_exists()
	if not is_instance_valid(_aura_material):
		return

	match preset_type.to_lower():
		"good":
			_aura_material.set_shader_parameter("albedo_color_a", Color(0.0, 0.5, 0.9, 0.85))
			_aura_material.set_shader_parameter("albedo_color_b", Color(0.0, 0.85, 0.45, 0.85))
			_aura_material.set_shader_parameter("emission_color", Color(0.1, 1.0, 0.8, 0.6))
		"bad", _:
			_aura_material.set_shader_parameter("albedo_color_a", Color(0.8, 0.05, 0.1, 0.85))
			_aura_material.set_shader_parameter("albedo_color_b", Color(0.35, 0.0, 0.5, 0.85))
			_aura_material.set_shader_parameter("emission_color", Color(1.0, 0.1, 0.15, 0.6))


func _ensure_aura_rect_exists() -> void:
	if is_instance_valid(_aura_rect):
		_aura_rect.size = get_viewport().get_visible_rect().size
		return

	_aura_rect = ColorRect.new()
	_aura_rect.name = "AuraOverlay"
	_aura_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura_rect.position = Vector2.ZERO
	_aura_rect.size = get_viewport().get_visible_rect().size
	_aura_rect.modulate.a = 0.0

	add_child(_aura_rect)
	if is_instance_valid(panel_container):
		move_child(_aura_rect, max(0, panel_container.get_index()))

	var shader_res: Shader = load("res://Shaders/lore_aura_overlay.gdshader") as Shader
	if not is_instance_valid(shader_res):
		push_error("UniversalPopup: Could not load shader resource at 'res://Shaders/lore_aura_overlay.gdshader'. Verify file exists.")
		return

	_aura_material = ShaderMaterial.new()
	_aura_material.shader = shader_res
	_aura_rect.material = _aura_material


func _start_aura_effect(preset_type: String) -> void:
	_configure_aura_preset(preset_type)

	if is_instance_valid(_aura_rect):
		_aura_rect.size = get_viewport().get_visible_rect().size
		_aura_rect.visible = true

		var tween: Tween = create_tween()
		tween.tween_property(_aura_rect, "modulate:a", 1.0, 0.35) \
				.set_trans(Tween.TRANS_SINE) \
				.set_ease(Tween.EASE_OUT)

	_is_aura_active = true
	_shake_timer = 0.0


func _stop_aura_effect() -> void:
	_is_aura_active = false
	if is_instance_valid(_aura_rect):
		var tween: Tween = create_tween()
		tween.tween_property(_aura_rect, "modulate:a", 0.0, 0.25) \
				.set_trans(Tween.TRANS_SINE) \
				.set_ease(Tween.EASE_IN)
		tween.finished.connect(func() -> void:
			if is_instance_valid(_aura_rect) and not _is_aura_active:
				_aura_rect.visible = false
		)
