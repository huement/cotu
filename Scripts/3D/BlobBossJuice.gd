# res://Scripts/3D/BlobBossJuice.gd
class_name BlobBossJuice
extends Node3D

const BLOB_SHADER: Shader = preload("res://Shaders/blob_monster.gdshader")
const BLOB_ALBEDO: Texture2D = preload("res://resources/Enemies/blobby_Image_0.png")

@export_group("Juice Tuning")
@export var base_squash_duration: float = 0.8
@export var hit_shake_intensity: float = 0.18
@export var hit_shake_duration: float = 0.25

var _target_mesh_instances: Array[MeshInstance3D] = []
var _shader_mat: ShaderMaterial
var _base_scale: Vector3 = Vector3.ONE
var _active_tween: Tween
var _shake_tween: Tween
var _flash_tween: Tween
var _is_attacking: bool = false


func _ready() -> void:
	_init_shader_material()
	_collect_and_apply_meshes(self)
	_base_scale = scale
	play_idle()


func _init_shader_material() -> void:
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = BLOB_SHADER
	_shader_mat.set_shader_parameter("base_color", Color(1.0, 1.0, 1.0, 1.0))
	_shader_mat.set_shader_parameter("rim_color", Color(0.45, 0.95, 0.6, 1.0))
	_shader_mat.set_shader_parameter("charge_color", Color(1.0, 0.55, 0.1, 1.0))
	_shader_mat.set_shader_parameter("hit_color", Color(1.0, 0.2, 0.2, 1.0))
	_shader_mat.set_shader_parameter("albedo_texture", BLOB_ALBEDO)
	_shader_mat.set_shader_parameter("use_texture", true)


func apply_world_scale(world_scale: float) -> void:
	_base_scale = Vector3.ONE * maxf(0.1, world_scale)
	scale = _base_scale
	play_idle()


func _collect_and_apply_meshes(current_node: Node) -> void:
	if current_node is MeshInstance3D:
		var mi: MeshInstance3D = current_node as MeshInstance3D
		_target_mesh_instances.append(mi)
		_capture_mesh_albedo(mi)
		mi.material_override = _shader_mat

	for child: Node in current_node.get_children():
		_collect_and_apply_meshes(child)


func _capture_mesh_albedo(mi: MeshInstance3D) -> void:
	if not is_instance_valid(_shader_mat) or not is_instance_valid(mi):
		return
	var mat: Material = mi.get_active_material(0)
	if mat is BaseMaterial3D:
		var albedo: Texture2D = (mat as BaseMaterial3D).albedo_texture
		if is_instance_valid(albedo):
			_shader_mat.set_shader_parameter("albedo_texture", albedo)
			_shader_mat.set_shader_parameter("use_texture", true)


func set_growth_tier(tier: int, growth_ratio: float = 0.35) -> void:
	var multiplier: float = 1.0 + (float(tier) * growth_ratio)
	_base_scale = Vector3.ONE * multiplier
	scale = _base_scale


func play_idle() -> void:
	if _is_attacking:
		return
	if is_instance_valid(_active_tween) and _active_tween.is_running():
		_active_tween.kill()

	if is_instance_valid(_shader_mat):
		_shader_mat.set_shader_parameter("attack_charge", 0.0)

	_active_tween = create_tween().set_loops()
	var squashed: Vector3 = Vector3(_base_scale.x * 1.12, _base_scale.y * 0.88, _base_scale.z * 1.12)
	var stretched: Vector3 = Vector3(_base_scale.x * 0.92, _base_scale.y * 1.08, _base_scale.z * 0.92)

	_active_tween.tween_property(self, "scale", squashed, base_squash_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(self, "scale", stretched, base_squash_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func play_attack_animation(target_callback: Callable = Callable()) -> void:
	_is_attacking = true
	if is_instance_valid(_active_tween):
		_active_tween.kill()

	var attack_tween: Tween = create_tween()
	var compressed_scale: Vector3 = Vector3(_base_scale.x * 1.35, _base_scale.y * 0.45, _base_scale.z * 1.35)
	var lunge_scale: Vector3 = Vector3(_base_scale.x * 0.7, _base_scale.y * 1.4, _base_scale.z * 0.7)
	var start_pos: Vector3 = position
	var lunge_pos: Vector3 = start_pos + Vector3(0.0, 0.2, -1.2)

	# 1. Windup Compression + Shader Energy Charge Surge
	attack_tween.parallel().tween_property(self, "scale", compressed_scale, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_shader_mat):
		attack_tween.parallel().tween_method(
			func(val: float) -> void: _shader_mat.set_shader_parameter("attack_charge", val),
			0.0, 1.0, 0.4
		)

	# 2. Forward Spring Strike
	attack_tween.parallel().tween_property(self, "scale", lunge_scale, 0.14) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	attack_tween.parallel().tween_property(self, "position", lunge_pos, 0.14) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	# 3. Strike Peak
	attack_tween.tween_callback(func() -> void:
		if is_instance_valid(SignalBus) and SignalBus.has_user_signal(&"camera_shake_requested"):
			SignalBus.emit_signal(&"camera_shake_requested", 0.5)
		if target_callback.is_valid():
			target_callback.call()
	)

	# 4. Recovery Settle + Fade Energy Charge back to baseline
	attack_tween.tween_property(self, "position", start_pos, 0.38) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	attack_tween.parallel().tween_property(self, "scale", _base_scale, 0.38) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_shader_mat):
		attack_tween.parallel().tween_method(
			func(val: float) -> void: _shader_mat.set_shader_parameter("attack_charge", val),
			1.0, 0.0, 0.38
		)

	attack_tween.finished.connect(func() -> void:
		_is_attacking = false
		play_idle()
	, CONNECT_ONE_SHOT)


func play_hit_shake() -> void:
	# Flash red via shader
	if is_instance_valid(_shader_mat):
		if is_instance_valid(_flash_tween) and _flash_tween.is_running():
			_flash_tween.kill()
		_flash_tween = create_tween()
		_shader_mat.set_shader_parameter("hit_flash", 1.0)
		_flash_tween.tween_method(
			func(val: float) -> void: _shader_mat.set_shader_parameter("hit_flash", val),
			1.0, 0.0, hit_shake_duration
		)

	# Position trauma shake
	if is_instance_valid(_shake_tween) and _shake_tween.is_running():
		_shake_tween.kill()

	_shake_tween = create_tween()
	var original_pos: Vector3 = position
	for i: int in range(4):
		var offset: Vector3 = Vector3(
			randf_range(-hit_shake_intensity, hit_shake_intensity),
			randf_range(-hit_shake_intensity * 0.5, hit_shake_intensity * 0.5),
			randf_range(-hit_shake_intensity, hit_shake_intensity)
		)
		_shake_tween.tween_property(self, "position", original_pos + offset, hit_shake_duration / 4.0)
	_shake_tween.tween_property(self, "position", original_pos, 0.05)


func play_death_sink(on_complete: Callable = Callable()) -> void:
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	if is_instance_valid(_shake_tween):
		_shake_tween.kill()

	var melt_tween: Tween = create_tween()
	var flat_scale: Vector3 = Vector3(_base_scale.x * 1.6, 0.05, _base_scale.z * 1.6)
	var sink_pos: Vector3 = position - Vector3(0.0, 0.6, 0.0)

	melt_tween.parallel().tween_property(self, "scale", flat_scale, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	melt_tween.parallel().tween_property(self, "position", sink_pos, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	melt_tween.finished.connect(func() -> void:
		if on_complete.is_valid():
			on_complete.call()
	, CONNECT_ONE_SHOT)