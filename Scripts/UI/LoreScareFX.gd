# res://Scripts/UI/LoreScareFX.gd
class_name LoreScareFX
extends CanvasLayer

## Full-screen lore scare: aura shader + strobing image flash (normal + inverted twin).

const AURA_SHADER: Shader = preload("res://Shaders/lore_aura_overlay.gdshader")
const INVERT_SHADER: Shader = preload("res://Shaders/invert_texture.gdshader")
const DEFAULT_FLASH_TEXTURE: Texture2D = preload("res://resources/Lore/cube.png")

var _root: Control
var _aura_rect: ColorRect
var _aura_material: ShaderMaterial
var _flash_primary: TextureRect
var _flash_inverted: TextureRect
var _sequence_tween: Tween
var _aura_tween: Tween
var _is_playing: bool = false


func _ready() -> void:
	layer = 105 # Above UniversalPopup (100) so the cube flash punches through lore text
	_build_overlay_tree()
	_hide_all()

	if is_instance_valid(SignalBus) and SignalBus.has_signal(&"lore_scare_requested"):
		if not SignalBus.lore_scare_requested.is_connected(_on_lore_scare_requested):
			SignalBus.lore_scare_requested.connect(_on_lore_scare_requested)


func _build_overlay_tree() -> void:
	_root = Control.new()
	_root.name = "LoreScareRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_aura_rect = ColorRect.new()
	_aura_rect.name = "AuraOverlay"
	_aura_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_aura_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura_rect.modulate.a = 0.0
	_aura_material = ShaderMaterial.new()
	_aura_material.shader = AURA_SHADER
	_aura_rect.material = _aura_material
	_root.add_child(_aura_rect)

	_flash_primary = _make_flash_rect("FlashPrimary", false)
	_flash_inverted = _make_flash_rect("FlashInverted", true)
	_root.add_child(_flash_primary)
	_root.add_child(_flash_inverted)


func _make_flash_rect(node_name: String, inverted: bool) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0
	rect.visible = false
	if inverted:
		var invert_mat := ShaderMaterial.new()
		invert_mat.shader = INVERT_SHADER
		rect.material = invert_mat
	return rect


func _on_lore_scare_requested(data: Dictionary) -> void:
	play_scare(data)


## Plays the scare sequence. Safe to call directly for tests.
func play_scare(data: Dictionary = {}) -> void:
	if _is_playing:
		return
	_is_playing = true

	var texture: Texture2D = data.get("flash_texture", DEFAULT_FLASH_TEXTURE) as Texture2D
	if not is_instance_valid(texture):
		var path: String = str(data.get("flash_texture_path", "res://resources/Lore/cube.png"))
		if ResourceLoader.exists(path):
			texture = load(path) as Texture2D
	if not is_instance_valid(texture):
		texture = DEFAULT_FLASH_TEXTURE

	var aura_type: String = str(data.get("aura_type", "bad"))
	var shake_trauma: float = float(data.get("shake_trauma", 0.55))
	var aura_hold: float = float(data.get("aura_hold", 3.2))

	_flash_primary.texture = texture
	_flash_inverted.texture = texture
	_configure_aura(aura_type)
	_hide_flashes()
	_root.visible = true
	_aura_rect.visible = true

	_start_aura(aura_hold)
	_run_flash_sequence(shake_trauma)


func _configure_aura(preset_type: String) -> void:
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


func _start_aura(hold_seconds: float) -> void:
	if is_instance_valid(_aura_tween):
		_aura_tween.kill()
	_aura_rect.modulate.a = 0.0
	_aura_tween = create_tween()
	_aura_tween.tween_property(_aura_rect, "modulate:a", 1.0, 0.28) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_aura_tween.tween_interval(maxf(0.5, hold_seconds))
	_aura_tween.tween_property(_aura_rect, "modulate:a", 0.0, 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_aura_tween.tween_callback(func() -> void:
		if is_instance_valid(_aura_rect):
			_aura_rect.visible = false
	)


func _run_flash_sequence(shake_trauma: float) -> void:
	if is_instance_valid(_sequence_tween):
		_sequence_tween.kill()

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var offset: Vector2 = Vector2(viewport_size.x * 0.045, -viewport_size.y * 0.03)

	_sequence_tween = create_tween()
	# 1) Hard fade-in hit
	_sequence_tween.tween_callback(func() -> void:
		_bump_shake(shake_trauma)
		_show_primary(1.0, Vector2.ZERO)
	)
	_sequence_tween.tween_property(_flash_primary, "modulate:a", 1.0, 0.06)
	_sequence_tween.tween_interval(0.14)
	_sequence_tween.tween_property(_flash_primary, "modulate:a", 0.0, 0.18)
	_sequence_tween.tween_callback(_hide_flashes)
	_sequence_tween.tween_interval(0.06)

	# 2) Strobe: primary / inverted-off-center / primary
	_sequence_tween.tween_callback(func() -> void:
		_bump_shake(shake_trauma * 0.7)
		_show_primary(1.0, Vector2.ZERO)
	)
	_sequence_tween.tween_interval(0.05)
	_sequence_tween.tween_callback(_hide_flashes)
	_sequence_tween.tween_interval(0.04)

	_sequence_tween.tween_callback(func() -> void:
		_bump_shake(shake_trauma * 0.85)
		_show_inverted(1.0, offset)
	)
	_sequence_tween.tween_interval(0.11)
	_sequence_tween.tween_callback(_hide_flashes)
	_sequence_tween.tween_interval(0.03)

	_sequence_tween.tween_callback(func() -> void:
		_show_primary(1.0, Vector2(-offset.x * 0.4, offset.y * 0.5))
	)
	_sequence_tween.tween_interval(0.05)
	_sequence_tween.tween_callback(_hide_flashes)
	_sequence_tween.tween_interval(0.05)

	# 3) Double-vision slam then fade out
	_sequence_tween.tween_callback(func() -> void:
		_bump_shake(shake_trauma)
		_show_primary(0.9, Vector2.ZERO)
		_show_inverted(0.75, offset * 1.35)
	)
	_sequence_tween.tween_interval(0.12)
	_sequence_tween.tween_property(_flash_primary, "modulate:a", 0.0, 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sequence_tween.parallel().tween_property(_flash_inverted, "modulate:a", 0.0, 0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sequence_tween.tween_callback(func() -> void:
		_hide_flashes()
		_is_playing = false
		if is_instance_valid(_aura_rect) and _aura_rect.modulate.a <= 0.01:
			_root.visible = false
	)


func _show_primary(alpha: float, position_offset: Vector2) -> void:
	_flash_primary.position = position_offset
	_flash_primary.modulate.a = alpha
	_flash_primary.visible = true


func _show_inverted(alpha: float, position_offset: Vector2) -> void:
	_flash_inverted.position = position_offset
	_flash_inverted.modulate.a = alpha
	_flash_inverted.visible = true


func _hide_flashes() -> void:
	if is_instance_valid(_flash_primary):
		_flash_primary.modulate.a = 0.0
		_flash_primary.visible = false
		_flash_primary.position = Vector2.ZERO
	if is_instance_valid(_flash_inverted):
		_flash_inverted.modulate.a = 0.0
		_flash_inverted.visible = false
		_flash_inverted.position = Vector2.ZERO


func _hide_all() -> void:
	_hide_flashes()
	if is_instance_valid(_aura_rect):
		_aura_rect.modulate.a = 0.0
		_aura_rect.visible = false
	if is_instance_valid(_root):
		_root.visible = false


func _bump_shake(trauma: float) -> void:
	if is_instance_valid(SignalBus) and SignalBus.has_signal(&"camera_shake_requested"):
		SignalBus.camera_shake_requested.emit(trauma)
