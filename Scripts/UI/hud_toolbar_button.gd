# res://Scripts/UI/hud_toolbar_button.gd
extends TextureButton
## Shared behaviour for the exploration toolbar buttons (SEARCH / REST / ITEMS):
## click sound, hover / press pop, the shine sweep the party portraits use, and the
## SignalBus popup request. search_button.gd, rest_button.gd and item_button.gd extend this.

const SHINE_SHADER: Shader = preload("res://Shaders/portrait_shine.gdshader")

## The event payload sent on SignalBus.popup_requested when clicked.
@export var action_type: String = ""

@export var hover_scale: Vector2 = Vector2(1.1, 1.1)
@export var click_scale: Vector2 = Vector2(0.95, 0.95)
@export var default_scale: Vector2 = Vector2(1.0, 1.0)

@export_group("Shine")
## White reads on both the cyan hover icon and the grey pressed icon.
@export var shine_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var shine_size: float = 0.35
@export var hover_shine_time: float = 0.35
@export var press_shine_time: float = 0.2

var _shine_material: ShaderMaterial
var _shine_tween: Tween


func _ready() -> void:
	_setup_shine_shader()
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	button_down.connect(_on_click_start)
	button_up.connect(_on_click_end)
	pressed.connect(_on_button_pressed)


## Plays the click sound, then does the button's job. Override _activate(), not this.
func _on_button_pressed() -> void:
	if is_instance_valid(AudioManager):
		AudioManager.play_button_press()
	_activate()


## What the button does once clicked. Default: ask the HUD for this button's popup.
func _activate() -> void:
	_request_popup()


func _request_popup() -> void:
	var bus: Node = get_tree().root.get_node_or_null(^"SignalBus")
	if is_instance_valid(bus) and bus.has_signal(&"popup_requested"):
		bus.emit_signal(&"popup_requested", action_type)
	else:
		push_error("HudToolbarButton: SignalBus could not be resolved from tree root!")


# ==============================================================================
# Shine sweep (same shader as the party portraits)
# ==============================================================================
func _setup_shine_shader() -> void:
	# One material per button so they sweep independently.
	_shine_material = ShaderMaterial.new()
	_shine_material.shader = SHINE_SHADER
	_shine_material.set_shader_parameter(&"shine_progress", -0.5)
	_shine_material.set_shader_parameter(&"shine_size", shine_size)
	_shine_material.set_shader_parameter(&"shine_color", shine_color)
	material = _shine_material


func _play_shine_sweep(duration: float) -> void:
	if not is_instance_valid(_shine_material):
		return
	if _shine_tween != null and _shine_tween.is_running():
		_shine_tween.kill()
	_shine_material.set_shader_parameter(&"shine_progress", -0.5)
	_shine_tween = create_tween()
	_shine_tween.tween_property(_shine_material, "shader_parameter/shine_progress", 1.5, duration) \
			.set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)


# ==============================================================================
# Hover / press pop
# ==============================================================================
func _on_hover_start() -> void:
	pivot_offset = size / 2
	z_index = 1 # pop above the neighbours while enlarged
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", hover_scale, 0.15) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	_play_shine_sweep(hover_shine_time)


func _on_hover_end() -> void:
	z_index = 0
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", default_scale, 0.15)


func _on_click_start() -> void:
	pivot_offset = size / 2
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", click_scale, 0.05)
	tween.tween_property(self, "rotation_degrees", 5.0, 0.05)
	_play_shine_sweep(press_shine_time)


func _on_click_end() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation_degrees", 0.0, 0.1)
	if is_hovered():
		_on_hover_start()
	else:
		_on_hover_end()
