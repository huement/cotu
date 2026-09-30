extends TextureButton

## 🎯 THE DECOUPLED SIGNAL IDENTIFIER
## Set this in the Inspector for each button (e.g., "SEARCH", "REST", "LOOK")
@export var action_type: String = "SEARCH"

@export var hover_scale: Vector2 = Vector2(1.1, 1.1)
@export var click_scale: Vector2 = Vector2(0.95, 0.95)
@export var default_scale: Vector2 = Vector2(1.0, 1.0)

func _ready() -> void:
	# Connect visual feedback loops
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	button_down.connect(_on_click_start)
	button_up.connect(_on_click_end)
	
	# 🎯 THE FUNCTIONAL EVENT HOOK
	pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	# Trigger button click audio
	if is_instance_valid(AudioManager):
		AudioManager.play_button_press()
		
	# Trigger light blue edge flash for search scan feedback
	var sb: Node = SignalBus if is_instance_valid(SignalBus) else get_tree().root.get_node_or_null("SignalBus")
	if is_instance_valid(sb) and sb.has_signal(&"edge_flash_requested"):
		sb.edge_flash_requested.emit(Color("38b6ff"), 0.4)

	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player) and player.has_method("_try_interact_facing_tile"):
		var result: Variant = player.call("_try_interact_facing_tile")
		if result is bool and bool(result) == true:
			return # Direct interaction with facing object succeeded!

	if is_instance_valid(sb) and sb.has_signal(&"popup_requested"):
		sb.popup_requested.emit(action_type)
		print("ActionButton: Requested modal window transformation for: ", action_type)
	else:
		push_error("ActionButton: Core SignalBus singleton could not be resolved from tree root!")


# =============================================================================
# 🎨 SATISFYING RETRO VISUAL ANIMATIONS
# =============================================================================

func _on_hover_start() -> void:
	pivot_offset = size / 2
	z_index = 1
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", hover_scale, 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1.3, 1.3, 1.1, 1.0), 0.15)

func _on_hover_end() -> void:
	z_index = 0
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", default_scale, 0.15)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.15)

func _on_click_start() -> void:
	pivot_offset = size / 2
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", click_scale, 0.05)
	tween.tween_property(self, "rotation_degrees", 5.0, 0.05)

func _on_click_end() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.1)
	
	if is_hovered():
		_on_hover_start()
	else:
		_on_hover_end()
