# res://Scripts/UI/universal_popup.gd
extends CanvasLayer
class_name UniversalPopup

@onready var panel_container: PanelContainer = $PanelContainer as PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel as Label
@onready var content_area: VBoxContainer = %ContentArea as VBoxContainer
@onready var confirm_button: TextureButton = %ConfirmButton as TextureButton
@onready var background_dimmer: ColorRect = $BackgroundDimmer as ColorRect

var active_action_type: StringName = &""
var active_data: Dictionary = {}

func _ready() -> void:
	if panel_container:
		panel_container.visible = false
	if background_dimmer:
		background_dimmer.visible = false
	
	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		bus.popup_requested.connect(_on_popup_requested)
		
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)

## Catches incoming event requests and builds custom menus on the fly
func _on_popup_requested(action_type: StringName, data: Dictionary = {}) -> void:
	active_action_type = action_type
	active_data = data
	_clear_content_area()
	
	match action_type:
		&"SEARCH":
			title_label.text = "SCANNING SYSTEM CORRIDORS"
			_build_search_ui()
		&"REST":
			title_label.text = "SET PURRGATORY CAMP DURATION"
			_build_rest_ui()
		&"ITEM_ACTIONS":
			title_label.text = "ITEM ACTION PROTOCOL"
			_build_item_actions_ui(data)
		_:
			push_warning("UniversalPopup: Unknown action type requested: " + String(action_type))
			return
			
	if background_dimmer: background_dimmer.visible = true		
	panel_container.visible = true

func _on_confirm_pressed() -> void:
	var payload: Dictionary = {}
	
	if active_action_type == &"REST":
		var slider := content_area.get_node_or_null("RestSlider") as HSlider
		if slider:
			payload["hours"] = int(slider.value)
			
	_emit_confirmation(active_action_type, payload)

func _clear_content_area() -> void:
	for child in content_area.get_children():
		child.queue_free()

func _emit_confirmation(action_type: StringName, extra_data: Dictionary) -> void:
	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		bus.popup_confirmed.emit(action_type, extra_data)
		
	if background_dimmer: background_dimmer.visible = false	
	panel_container.visible = false
	active_action_type = &""
	active_data.clear()

# =============================================================================
# 🛠️ DYNAMIC CONTENT GENERATION METHODS
# =============================================================================

func _build_search_ui() -> void:
	var info_text := Label.new()
	info_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_text.text = "Searching walls for hidden compartments...\nNo immediate micro-vibrations detected."
	content_area.add_child(info_text)

func _build_rest_ui() -> void:
	var info_text := Label.new()
	info_text.text = "Select rest duration (Hours):"
	content_area.add_child(info_text)
	
	var slider := HSlider.new()
	slider.name = "RestSlider"
	slider.min_value = 1
	slider.max_value = 12
	slider.value = 4
	slider.step = 1
	slider.custom_minimum_size = Vector2(200, 20)
	
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.text = "4 Hours"
	
	slider.value_changed.connect(func(val: float) -> void: 
		value_label.text = str(int(val)) + " Hours"
	)
	
	content_area.add_child(slider)
	content_area.add_child(value_label)

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
			# Equipped Item -> Offer Unequip
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
			# Inventory Item -> Offer Equip / Use
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
		_emit_confirmation(&"ITEM_ACTIONS", {"sub_action": "CANCEL"})
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
