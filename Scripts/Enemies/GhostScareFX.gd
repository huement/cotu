# res://Scripts/Enemies/GhostScareFX.gd
class_name GhostScareFX
extends CanvasLayer
## Full-screen "jump scare" pulse: the screen inverts and tears apart for a split second.
## Self-contained: creates itself on top of everything, plays, then frees itself.
##
##     GhostScareFX.play(get_tree())                 # default double pulse (inverted, ghostly)
##     GhostScareFX.play(get_tree(), 3, 1.0, 0.07)   # three hard pulses
##     GhostScareFX.play_blood(get_tree())           # red / black strobe (boss entrances)

const SHADER: Shader = preload("res://Shaders/ghost_scare_screen.gdshader")

var _rect: ColorRect = null
var _material: ShaderMaterial = null


## [param pulses] quick flashes, each peaking at [param peak] (0-1) and lasting about
## [param pulse_seconds] * 3. Returns the effect node (it frees itself when done).
static func play(tree: SceneTree, pulses: int = 2, peak: float = 1.0, pulse_seconds: float = 0.06,
		tint: Color = Color(0.62, 0.08, 1.0), duotone: bool = false) -> GhostScareFX:
	if tree == null or tree.root == null:
		return null
	var fx := GhostScareFX.new()
	fx._material.set_shader_parameter(&"tint", tint)
	fx._material.set_shader_parameter(&"duotone", 1.0 if duotone else 0.0)
	tree.root.add_child(fx)
	fx._run(maxi(1, pulses), clampf(peak, 0.0, 1.0), maxf(0.02, pulse_seconds))
	return fx


## Red-and-black strobe: the screen drops to black shadows and blood-red highlights.
static func play_blood(tree: SceneTree, pulses: int = 2, peak: float = 1.0, pulse_seconds: float = 0.08) -> GhostScareFX:
	return play(tree, pulses, peak, pulse_seconds, Color(0.95, 0.06, 0.04), true)


func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)


func _run(pulses: int, peak: float, pulse_seconds: float) -> void:
	_set_intensity(0.0)
	var tween: Tween = create_tween()
	for i: int in pulses:
		var strength: float = peak * (1.0 if i == 0 else 0.8)
		tween.tween_method(_set_intensity, 0.0, strength, pulse_seconds * 0.5)
		tween.tween_interval(pulse_seconds)
		tween.tween_method(_set_intensity, strength, 0.12, pulse_seconds * 1.5)
	tween.tween_method(_set_intensity, 0.12, 0.0, pulse_seconds * 3.0)
	tween.finished.connect(queue_free)


func _set_intensity(value: float) -> void:
	_material.set_shader_parameter(&"intensity", value)
