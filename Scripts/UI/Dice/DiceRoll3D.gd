# res://Scripts/UI/Dice/DiceRoll3D.gd
@icon("res://addons/dice_roller/dice/d6_dice/d6_dice.svg")
class_name DiceRoll3D
extends SubViewportContainer
## A 3D D6 that tumbles in, bounces and lands showing a result. Pure presentation:
## put it in any Control layout (transparent background) and `await roll()`.
##
##   var dice := DiceRoll3D.new()            # or instance Scenes/UI/Dice/DiceRoll3D.tscn
##   some_container.add_child(dice)
##   var value: int = await dice.roll()      # random 1..6
##   var forced: int = await dice.roll(6)    # code decides, dice shows it
##
## For a ready-made window (title + result + glass panel) use DiceRollPopup.roll_d6().
## Works while the tree is paused (process_mode ALWAYS).

signal roll_started
## Emitted when the die has landed (after the landing pop).
signal rolled(value: int)
## Each time the die hits the table (3 per roll) - hook sounds / shakes here.
signal impact(strength: float)

const D6_MODEL: PackedScene = preload("res://resources/Objects/d6.glb")
## Local face normal for each value of resources/Objects/d6.glb (measured from renders: this die's
## opposite faces are 1/2, 3/4, 5/6 - NOT the addons/dice_roller D6 table).
const D6_FACE_NORMALS: Dictionary = {
	1: Vector3.FORWARD, 2: Vector3.BACK, 3: Vector3.RIGHT,
	4: Vector3.LEFT, 5: Vector3.DOWN, 6: Vector3.UP,
}
## Local direction that points "up on screen" when that face is shown.
const D6_FACE_UP: Dictionary = {
	1: Vector3.UP, 2: Vector3.UP, 3: Vector3.UP,
	4: Vector3.UP, 5: Vector3.FORWARD, 6: Vector3.BACK,
}
const SIDES: int = 6

@export_group("Look")
@export var die_model: PackedScene = D6_MODEL
## Size of the die in the view (1.0 = the model's 2 m cube).
@export var die_scale: float = 0.55
## Colour of the flash light when the die lands.
@export var landing_glow: Color = Color(0.0, 1.0, 0.78)
## Soft shadow under the die.
@export var show_shadow: bool = true
## Show the die resting before the first roll.
@export var visible_before_roll: bool = true

@export_group("Motion")
@export_range(0.4, 4.0, 0.05) var roll_duration: float = 1.5
## Full turns the die spins before settling.
@export_range(0.5, 8.0, 0.25) var spin_turns: float = 3.0
## How high above the table it is dropped from (metres in the dice view).
@export var drop_height: float = 2.2

var is_rolling: bool = false
var last_result: int = 0

var _viewport: SubViewport
var _camera: Camera3D
var _die_pivot: Node3D
var _die: Node3D
var _shadow: MeshInstance3D
var _flash: OmniLight3D
var _final_basis: Basis = Basis.IDENTITY
var _spin_axis: Vector3 = Vector3.RIGHT
var _wobble_axis: Vector3 = Vector3.FORWARD
var _start_offset: Vector3 = Vector3.ZERO
var _impacts_fired: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(220, 200)
	_build_view()
	_set_shown_face(randi_range(1, SIDES))
	_die_pivot.visible = visible_before_roll
	_update_shadow(0.0)


## Rolls the die. `result` 1..6 forces the outcome; anything else is random. Returns the value shown.
func roll(result: int = 0) -> int:
	if is_rolling:
		await rolled
		return last_result
	var value: int = result if result >= 1 and result <= SIDES else randi_range(1, SIDES)
	is_rolling = true
	_impacts_fired = 0
	_die_pivot.visible = true
	_die_pivot.scale = Vector3.ONE
	_set_shown_face(value)
	_spin_axis = Vector3(1.0, randf_range(-0.35, 0.35), randf_range(-0.6, 0.6)).normalized()
	_wobble_axis = Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3)).normalized()
	_start_offset = Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.6, -0.9))
	roll_started.emit()

	var tween: Tween = create_tween()
	tween.tween_method(_animate, 0.0, 1.0, roll_duration)
	await tween.finished
	_animate(1.0)

	# Landing pop + glow
	var pop: Tween = create_tween().set_parallel(true)
	pop.tween_property(_die_pivot, "scale", Vector3.ONE * 1.18, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(_flash, "light_energy", 3.0, 0.09)
	pop.chain().tween_property(_die_pivot, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(_flash, "light_energy", 0.0, 0.5)
	await pop.finished

	last_result = value
	is_rolling = false
	rolled.emit(value)
	return value


## Shows `value` instantly with no animation (e.g. restoring a previous roll).
func show_value(value: int) -> void:
	_die_pivot.visible = true
	_set_shown_face(clampi(value, 1, SIDES))
	_die_pivot.basis = _final_basis
	_die_pivot.position = Vector3.ZERO
	last_result = clampi(value, 1, SIDES)
	_update_shadow(0.0)


# ------------------------------------------------------------------------------
# Animation
# ------------------------------------------------------------------------------
## t 0..1: fall + two bounces (height), sliding in from the back, spinning down onto the final face.
func _animate(t: float) -> void:
	var height: float = _bounce_height(t)
	var slide: float = 1.0 - _ease_out(minf(1.0, t / 0.8), 2.5)
	_die_pivot.position = Vector3(0.0, height, 0.0) + _start_offset * slide

	var settle: float = _ease_out(t, 3.0)
	var spin: float = TAU * spin_turns * (1.0 - settle)
	var wobble: float = 0.9 * sin(t * 9.0) * (1.0 - settle)
	_die_pivot.basis = Basis(_spin_axis, spin) * Basis(_wobble_axis, wobble) * _final_basis
	_update_shadow(height)

	# Table hits at 0.45 / 0.75 / 0.9
	var hits: Array[float] = [0.45, 0.75, 0.9]
	while _impacts_fired < hits.size() and t >= hits[_impacts_fired]:
		var strength: float = [1.0, 0.5, 0.2][_impacts_fired]
		_impacts_fired += 1
		_on_impact(strength)


func _bounce_height(t: float) -> float:
	if t < 0.45:
		var f: float = t / 0.45
		return drop_height * (1.0 - f * f)
	if t < 0.75:
		var s: float = (t - 0.45) / 0.3
		return drop_height * 0.32 * 4.0 * s * (1.0 - s)
	if t < 0.9:
		var s2: float = (t - 0.75) / 0.15
		return drop_height * 0.09 * 4.0 * s2 * (1.0 - s2)
	return 0.0


func _ease_out(t: float, power: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), power)


func _on_impact(strength: float) -> void:
	impact.emit(strength)
	# Small jolt of the whole view
	var kick: Vector2 = Vector2(randf_range(-1.0, 1.0), 1.0) * 6.0 * strength
	var base: Vector2 = position
	var jolt: Tween = create_tween()
	jolt.tween_property(self, "position", base + kick, 0.04)
	jolt.tween_property(self, "position", base, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------------------
# Faces
# ------------------------------------------------------------------------------
## Final orientation: face `value` points at the camera, its "up" direction points up on screen.
func _set_shown_face(value: int) -> void:
	var to_cam: Vector3 = _camera.position.normalized()
	var screen_up: Vector3 = (Vector3.UP - to_cam * Vector3.UP.dot(to_cam)).normalized()
	var n: Vector3 = D6_FACE_NORMALS[value]
	var u: Vector3 = D6_FACE_UP[value]
	var local: Basis = Basis(n, u, n.cross(u))
	var world: Basis = Basis(to_cam, screen_up, to_cam.cross(screen_up))
	_final_basis = world * local.inverse()


# ------------------------------------------------------------------------------
# View setup
# ------------------------------------------------------------------------------
func _build_view() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "DiceViewport"
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.85, 0.9)
	env.ambient_light_energy = 0.55
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 2.4, 3.4)
	_camera.fov = 40.0
	_viewport.add_child(_camera)
	_camera.look_at(Vector3(0.0, 0.25, 0.0), Vector3.UP)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	key.light_energy = 1.25
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
	rim.light_energy = 0.5
	rim.light_color = Color(0.4, 1.0, 0.9)
	_viewport.add_child(rim)

	_flash = OmniLight3D.new()
	_flash.position = Vector3(0.0, 1.2, 1.4)
	_flash.omni_range = 4.0
	_flash.light_color = landing_glow
	_flash.light_energy = 0.0
	_viewport.add_child(_flash)

	_die_pivot = Node3D.new()
	_die_pivot.name = "DiePivot"
	_viewport.add_child(_die_pivot)
	_die = die_model.instantiate() as Node3D
	_die.scale = Vector3.ONE * die_scale
	_die_pivot.add_child(_die)

	if show_shadow:
		_shadow = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.6, 1.6)
		quad.orientation = PlaneMesh.FACE_Y
		_shadow.mesh = quad
		var grad := Gradient.new()
		grad.set_color(0, Color(0, 0, 0, 0.55))
		grad.set_color(1, Color(0, 0, 0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = tex
		_shadow.material_override = mat
		_shadow.position = Vector3(0.0, -die_scale - 0.01, 0.0)
		_viewport.add_child(_shadow)


func _update_shadow(height: float) -> void:
	if not is_instance_valid(_shadow):
		return
	var spread: float = 1.0 + height * 0.25
	_shadow.scale = Vector3(spread, 1.0, spread)
	_shadow.position.x = _die_pivot.position.x
	_shadow.position.z = _die_pivot.position.z
	(_shadow.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, clampf(1.0 - height * 0.3, 0.15, 1.0))
	_shadow.visible = _die_pivot.visible
