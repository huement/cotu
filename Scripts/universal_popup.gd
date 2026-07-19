extends CanvasLayer
class_name UniversalPopup

@onready var panel_container: PanelContainer = $PanelContainer as PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel as Label
@onready var content_area: VBoxContainer = %ContentArea as VBoxContainer
@onready var confirm_button: TextureButton = %ConfirmButton as TextureButton

## Tracks what system currently owns the open window
var active_action_type: String = ""

func _ready() -> void:
	# Hide the menu window on startup
	panel_container.visible = false
	
	# Connect to event router
	if get_tree().root.has_node("SignalBus"):
		var signal_bus := get_tree().root.get_node("SignalBus")
		signal_bus.popup_requested.connect(_on_popup_requested)
		
	confirm_button.pressed.connect(_on_confirm_pressed)

## Catches incoming event requests and builds custom menus on the fly
func _on_popup_requested(action_type: String) -> void:
	print("UniversalPopup: Successfully caught broadcast for action: ", action_type)
	
	active_action_type = action_type
	_clear_content_area()
	
	match action_type.to_upper():
		"SEARCH":
			title_label.text = "SCANNING SYSTEM CORRIDORS"
			_build_search_ui()
		"REST":
			title_label.text = "SET PURRGATORY CAMP DURATION"
			_build_rest_ui()
		_:
			push_warning("Popup: Unknown action type requested: " + action_type)
			return
			
	panel_container.visible = true

func _on_confirm_pressed() -> void:
	var payload: Dictionary = {}
	
	# Gather user selections from our programmatic nodes before wiping them
	if active_action_type.to_upper() == "REST":
		var slider := content_area.get_node_or_null("RestSlider") as HSlider
		if slider:
			payload["hours"] = int(slider.value)
			
	# Broadcast the confirmation back to the game engines
	if get_tree().root.has_node("SignalBus"):
		get_tree().root.get_node("SignalBus").popup_confirmed.emit(active_action_type, payload)
		
	panel_container.visible = false
	active_action_type = ""

## Clear programmatic children from previous uses
func _clear_content_area() -> void:
	for child in content_area.get_children():
		child.queue_free()

# =============================================================================
# 🛠️ DYNAMIC CONTENT GENERATION METHODS
# =============================================================================

func _build_search_ui() -> void:
	var info_text := Label.new()
	info_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Query the surrounding environment coordinates
	info_text.text = "Searching walls for hidden compartments...\nNo immediate micro-vibrations or secret hollows detected."
	
	content_area.add_child(info_text)

func _build_rest_ui() -> void:
	var info_text := Label.new()
	info_text.text = "Select rest duration (Hours):"
	content_area.add_child(info_text)
	
	# Instantiate a slide control programmatically
	var slider := HSlider.new()
	slider.name = "RestSlider"
	slider.min_value = 1
	slider.max_value = 8
	slider.value = 4
	slider.step = 1
	slider.custom_minimum_size = Vector2(200, 20)
	
	# Visual numeric readout matching slider value
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.text = "4 Hours"
	
	slider.value_changed.connect(func(val: float): 
		value_label.text = str(int(val)) + " Hours"
	)
	
	content_area.add_child(slider)
	content_area.add_child(value_label)
