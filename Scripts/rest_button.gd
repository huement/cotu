extends TextureButton

## 🎯 THE DECOUPLED SIGNAL IDENTIFIER
## Set this in the Inspector for each button (e.g., "SEARCH", "REST", "LOOK")
@export var action_type: String = "REST"

@export var hover_scale: Vector2 = Vector2(1.1, 1.1)
@export var click_scale: Vector2 = Vector2(0.95, 0.95)
@export var default_scale: Vector2 = Vector2(1.0, 1.0)

func _ready() -> void:
	# Connect the button signals
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	button_down.connect(_on_click_start)
	button_up.connect(_on_click_end)
	
	# 🎯 THE FUNCTIONAL EVENT HOOK
	pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	# Broadcast the payload across the global event router
	if get_tree().root.has_node("SignalBus"):
		var bus: Node = get_tree().root.get_node("SignalBus")
		bus.popup_requested.emit(action_type)
		print("ActionButton: Requested modal window transformation for: ", action_type)
	else:
		push_error("ActionButton: Core SignalBus singleton could not be resolved from tree root!")

func _on_hover_start() -> void:
	# 1. Dynamically grab the size the HBox gave this button and find the center
	pivot_offset = size / 2
	
	# 2. Pop this button to the front layer so it doesn't expand BEHIND its neighbors
	z_index = 1
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", hover_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1.3, 1.3, 1.1, 1.0), 0.15)

func _on_hover_end() -> void:
	# 3. Put the layer priority back to normal
	z_index = 0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", default_scale, 0.15)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.15)

func _on_click_start() -> void:
	pivot_offset = size / 2
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", click_scale, 0.05)
	tween.tween_property(self, "rotation_degrees", 5.0, 0.05)

func _on_click_end() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.1)
	
	if is_hovered():
		_on_hover_start()
	else:
		_on_hover_end()
