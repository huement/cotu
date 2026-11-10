# res://Scripts/UI/SpaceBackground.gd
@tool
class_name SpaceBackground
extends ColorRect
## Full-screen animated pixel-art space (Shaders/space_pixel.gdshader).
## Drop Scenes/UI/SpaceBackground.tscn behind any menu, or `SpaceBackground.new()` from code.
##
## Pick a `preset`, then fine-tune any shader uniform in the Inspector (Material > Shader Parameters)
## with preset = CUSTOM so your tweaks aren't overwritten.
##   set_calm(1.0)                 # fade to a quiet backdrop for text (tweens)
##   focus_on(%Window)             # darken the area behind a window (follows its rect once)
##   clear_focus()

const SHADER: Shader = preload("res://Shaders/space_pixel.gdshader")

enum Preset {
	## Busy, like the reference image: lots of stars, strong nebula.
	DEEP_FIELD,
	## Title screen: full scene, slightly calmer, slow drift.
	MAIN_MENU,
	## Behind a big window with text: faint nebula, few stars.
	CALM,
	## Keep whatever is in the material (for hand tuning).
	CUSTOM,
}

const PRESETS: Dictionary = {
	Preset.DEEP_FIELD: {
		"calm": 0.0, "nebula_intensity": 0.85, "nebula_coverage": 0.6, "far_star_density": 0.55,
		"mid_star_density": 0.35, "near_star_density": 0.25, "giant_star_density": 0.35,
		"drift": Vector2(2.2, -0.9), "vignette": 0.35, "brightness": 1.0,
	},
	Preset.MAIN_MENU: {
		"calm": 0.2, "nebula_intensity": 0.85, "nebula_coverage": 0.55, "far_star_density": 0.5,
		"mid_star_density": 0.3, "near_star_density": 0.2, "giant_star_density": 0.3,
		"drift": Vector2(1.6, -0.6), "vignette": 0.45, "brightness": 0.95,
	},
	Preset.CALM: {
		"calm": 0.75, "nebula_intensity": 0.75, "nebula_coverage": 0.5, "far_star_density": 0.45,
		"mid_star_density": 0.25, "near_star_density": 0.15, "giant_star_density": 0.2,
		"drift": Vector2(1.0, -0.4), "vignette": 0.5, "brightness": 0.85,
	},
}

@export var preset: Preset = Preset.DEEP_FIELD:
	set(value):
		preset = value
		_apply_preset()
## Size of one art pixel on screen (bigger = chunkier).
@export_range(1.0, 12.0, 1.0) var pixel_size: float = 3.0:
	set(value):
		pixel_size = value
		_set_param(&"pixel_size", value)
## Different seeds give different star / cloud layouts.
@export_range(0.0, 100.0, 0.1) var seed: float = 7.0:
	set(value):
		seed = value
		_set_param(&"seed", value)

var _calm_tween: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.BLACK


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not material is ShaderMaterial or (material as ShaderMaterial).shader != SHADER:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		material = mat
	_set_param(&"pixel_size", pixel_size)
	_set_param(&"seed", seed)
	_apply_preset()


## Tweens the "quiet" amount: 0 = full scene, 1 = calm backdrop for text.
func set_calm(amount: float, duration: float = 0.6) -> void:
	if _calm_tween != null:
		_calm_tween.kill()
	if duration <= 0.0 or not is_inside_tree():
		_set_param(&"calm", amount)
		return
	_calm_tween = create_tween()
	_calm_tween.tween_method(func(v: float) -> void: _set_param(&"calm", v), get_param(&"calm", 0.0), amount, duration)


## Darkens the area behind `window` (uses its current screen rect).
func focus_on(window: Control, dim: float = 0.55, softness: float = 0.08) -> void:
	var view: Vector2 = get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var r: Rect2 = window.get_global_rect()
	_set_param(&"focus_rect", Vector4(r.position.x / view.x, r.position.y / view.y, r.size.x / view.x, r.size.y / view.y))
	_set_param(&"focus_softness", softness)
	_set_param(&"focus_dim", dim)


func clear_focus() -> void:
	_set_param(&"focus_dim", 0.0)


func get_param(param: StringName, fallback: Variant = null) -> Variant:
	var mat := material as ShaderMaterial
	if mat == null:
		return fallback
	var v: Variant = mat.get_shader_parameter(param)
	return fallback if v == null else v


func _apply_preset() -> void:
	if preset == Preset.CUSTOM or not PRESETS.has(preset):
		return
	var values: Dictionary = PRESETS[preset]
	for key: String in values.keys():
		_set_param(StringName(key), values[key])


func _set_param(param: StringName, value: Variant) -> void:
	var mat := material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(param, value)
