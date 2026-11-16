# res://Scripts/3D/EnemyHitReaction.gd
extends RefCounted
## Code-driven "enemy got hit" feedback for any 3D model: one white flash, plus a short shake.
## Used by EnemyVisualManager for every battle model that has no VisualJuice node of its own
## (blobs / tentacles / lake monster already flash and shake themselves).
##
##   flash(node)  - white overlay on every mesh, fading out once.
##   shake(node)  - quick sideways jitter that settles back exactly where it started.
##   collapse(node) - death for models with no death clip: flash, squash flat, sink.
##
## Both are safe to call again mid-reaction (the old one is replaced) and safe against the
## battle layout moving the model while it shakes (the shake only adds / removes its own offset).

const FLASH_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const FLASH_TIME: float = 0.22
const SHAKE_TIME: float = 0.3
## Sideways travel in metres (models are ~0.4 scale, a few metres from the camera).
const SHAKE_STRENGTH: float = 0.09
const SHAKE_STEPS: int = 6

## Code death for models with no death clip: flash, then shrink and sink.
const DEATH_TIME: float = 0.55
const DEATH_SINK: float = 0.35

const _META_FLASH_TWEEN: StringName = &"_hit_flash_tween"
const _META_FLASH_MESHES: StringName = &"_hit_flash_meshes"
const _META_SHAKE_TWEEN: StringName = &"_hit_shake_tween"
const _META_SHAKE_OFFSET: StringName = &"_hit_shake_offset"


static func flash(node: Node3D, color: Color = FLASH_COLOR, duration: float = FLASH_TIME) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	_end_flash(node)

	var meshes: Array[GeometryInstance3D] = []
	_collect_meshes(node, meshes)
	if meshes.is_empty():
		return

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	for mesh: GeometryInstance3D in meshes:
		mesh.material_overlay = mat
	node.set_meta(_META_FLASH_MESHES, meshes)

	var tween: Tween = node.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if is_instance_valid(node):
			_clear_flash_meshes(node))
	node.set_meta(_META_FLASH_TWEEN, tween)


static func shake(node: Node3D, strength: float = SHAKE_STRENGTH, duration: float = SHAKE_TIME) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var old: Tween = node.get_meta(_META_SHAKE_TWEEN, null) as Tween
	if old != null and old.is_valid():
		old.kill()
	_set_shake_offset(Vector3.ZERO, node)

	# Shake across the screen: the model faces the camera, so its local X is screen-sideways.
	var side: Vector3 = node.transform.basis.x.normalized()
	var tween: Tween = node.create_tween()
	var step_time: float = duration / float(SHAKE_STEPS + 1)
	var apply: Callable = func(offset: Vector3) -> void: _set_shake_offset(offset, node)
	var prev: Vector3 = Vector3.ZERO
	for i: int in SHAKE_STEPS:
		var falloff: float = 1.0 - float(i) / float(SHAKE_STEPS)
		var dir: float = 1.0 if i % 2 == 0 else -1.0
		var target: Vector3 = side * strength * falloff * dir + Vector3.UP * randf_range(-0.15, 0.15) * strength * falloff
		tween.tween_method(apply, prev, target, step_time)
		prev = target
	tween.tween_method(apply, prev, Vector3.ZERO, step_time)
	node.set_meta(_META_SHAKE_TWEEN, tween)


## Death for a model with no death clip: one flash, then it shrinks into the floor over
## DEATH_TIME. The caller frees / hides the node afterwards.
static func collapse(node: Node3D, duration: float = DEATH_TIME) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var old: Tween = node.get_meta(_META_SHAKE_TWEEN, null) as Tween
	if old != null and old.is_valid():
		old.kill()
	flash(node, FLASH_COLOR, duration * 0.6)
	var tween: Tween = node.create_tween().set_parallel(true)
	tween.tween_property(node, "scale", node.scale * Vector3(1.25, 0.02, 1.25), duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "position:y", node.position.y - DEATH_SINK, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# ------------------------------------------------------------------------------
# internals
# ------------------------------------------------------------------------------
## Moves the node by the difference between the new offset and the one already applied, so
## anything else that repositions the node mid-shake (battle layout) is left intact.
static func _set_shake_offset(offset: Vector3, node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var applied: Vector3 = node.get_meta(_META_SHAKE_OFFSET, Vector3.ZERO) as Vector3
	node.position += offset - applied
	node.set_meta(_META_SHAKE_OFFSET, offset)


static func _end_flash(node: Node3D) -> void:
	var old: Tween = node.get_meta(_META_FLASH_TWEEN, null) as Tween
	if old != null and old.is_valid():
		old.kill()
	_clear_flash_meshes(node)


static func _clear_flash_meshes(node: Node3D) -> void:
	var meshes: Array = node.get_meta(_META_FLASH_MESHES, []) as Array
	for mesh: Variant in meshes:
		if is_instance_valid(mesh):
			(mesh as GeometryInstance3D).material_overlay = null
	if node.has_meta(_META_FLASH_MESHES):
		node.remove_meta(_META_FLASH_MESHES)


static func _collect_meshes(node: Node, out: Array[GeometryInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as GeometryInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child, out)
