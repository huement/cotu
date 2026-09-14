# res://Scripts/3D/EnemyVisualManager.gd
class_name EnemyVisualManager
extends Node3D

## Spawns, positions, and animates 3D enemy models in front of the Player Camera3D
## during combat encounters.

# ==============================================================================
# 1. EXPORTED CONFIGURATION & POSITION TUNING
# ==============================================================================
@export var camera_node: Camera3D

## Distance in front of camera (-Z vector).
@export var forward_distance: float = 2.5

## Vertical offset (-Y vector). Lower to ground feet onto the floor plane.
@export var vertical_offset: float = -0.85

## Uniform scale multiplier for 3D enemy models.
@export var model_scale: Vector3 = Vector3(0.4, 0.4, 0.4)

## Horizontal spacing when multiple enemies are spawned.
@export var horizontal_spacing: float = 1.2

# ==============================================================================
# 2. RUNTIME STATE
# ==============================================================================
var _spawned_enemies: Dictionary = {}

# ==============================================================================
# 3. LIFECYCLE & INITIALIZATION
# ==============================================================================
func _ready() -> void:
	visible = false
	_connect_to_signal_bus()


func _connect_to_signal_bus() -> void:
	var sb: Node = SignalBus
	if not is_instance_valid(sb):
		push_error("EnemyVisualManager requires the SignalBus singleton.")
		return

	if not sb.combat_started.is_connected(_on_combat_started):
		sb.combat_started.connect(_on_combat_started)
	if not sb.combat_ended.is_connected(_on_combat_ended):
		sb.combat_ended.connect(_on_combat_ended)
	if not sb.enemy_attack_started.is_connected(_on_enemy_attack_started):
		sb.enemy_attack_started.connect(_on_enemy_attack_started)
	if not sb.enemy_damaged_visual.is_connected(_on_enemy_damaged):
		sb.enemy_damaged_visual.connect(_on_enemy_damaged)
	if not sb.enemy_health_changed.is_connected(_on_enemy_health_changed):
		sb.enemy_health_changed.connect(_on_enemy_health_changed)
	if not sb.target_vfx_requested.is_connected(play_target_vfx):
		sb.target_vfx_requested.connect(play_target_vfx)


# ==============================================================================
# 4. SPAWNING & RESOLUTION
# ==============================================================================
func _resolve_enemy_resources(payload: Variant) -> Array[Resource]:
	var result: Array[Resource] = []

	if payload is Array:
		for item in (payload as Array):
			if item is Resource:
				result.append(item as Resource)
			elif is_instance_valid(item) and "enemy_group" in item:
				var group_array: Variant = item.get("enemy_group")
				if group_array is Array:
					for sub_item in (group_array as Array):
						if sub_item is Resource:
							result.append(sub_item as Resource)

	elif is_instance_valid(payload):
		if "enemy_group" in payload:
			var group_val: Variant = payload.get("enemy_group")
			if group_val is Array and not (group_val as Array).is_empty():
				for item in (group_val as Array):
					if item is Resource:
						result.append(item as Resource)

		if result.is_empty() and "members" in payload:
			var members_val: Variant = payload.get("members")
			if members_val is Array and not (members_val as Array).is_empty():
				for item in (members_val as Array):
					if item is Resource:
						result.append(item as Resource)

		if result.is_empty() and payload is Resource:
			var target_res: Resource = payload as Resource
			var overworld_enemies: Array[Node] = get_tree().get_nodes_in_group(&"world_enemies")
			if overworld_enemies.is_empty():
				overworld_enemies = get_tree().root.find_children("*", "WorldEnemy", true, false)

			for node in overworld_enemies:
				if is_instance_valid(node) and ("enemy_group" in node):
					var grp: Variant = node.get("enemy_group")
					var n_data: Variant = node.get("data") if "data" in node else null
					var n_edata: Variant = node.get("enemy_data") if "enemy_data" in node else null

					if (grp is Array and (grp as Array).has(target_res)) or n_data == target_res or n_edata == target_res:
						if grp is Array and not (grp as Array).is_empty():
							for item in (grp as Array):
								if item is Resource:
									result.append(item as Resource)
							break

			if result.is_empty():
				var count: int = 1
				if "pack_size" in payload:
					count = max(1, int(payload.get("pack_size")))
				for i in range(count):
					result.append(target_res.duplicate() if count > 1 else target_res)

	return result


func _on_combat_started(enemy_payload: Variant, _player_party: Array) -> void:
	if not is_instance_valid(camera_node):
		camera_node = get_viewport().get_camera_3d()

	if not is_instance_valid(camera_node):
		push_error("[EnemyVisualManager] ERROR: Could not find an active Camera3D in Scene Tree.")
		return

	_clear_all_enemies()
	visible = true

	var enemy_resources: Array[Resource] = _resolve_enemy_resources(enemy_payload)

	for i in range(enemy_resources.size()):
		var e_data: Resource = enemy_resources[i]
		if not is_instance_valid(e_data):
			continue

		var model_scene: PackedScene = e_data.get("model_scene") as PackedScene if "model_scene" in e_data else null
		var enemy_node: Node3D
		if is_instance_valid(model_scene):
			enemy_node = model_scene.instantiate() as Node3D
		else:
			enemy_node = _create_debug_mesh()

		var enemy_id: String = "enemy_%d" % i
		_spawned_enemies[enemy_id] = enemy_node
		add_child(enemy_node)

		_position_enemy(enemy_node, i, enemy_resources.size())
		play_animation(enemy_node, &"idle", true)


func _position_enemy(enemy_node: Node3D, index: int, total_enemies: int) -> void:
	if not is_instance_valid(camera_node):
		return

	var horizontal_offset: float = 0.0
	if total_enemies > 1:
		horizontal_offset = (float(index) - (float(total_enemies - 1) / 2.0)) * horizontal_spacing

	var cam_transform: Transform3D = camera_node.global_transform

	var spawn_pos: Vector3 = cam_transform.origin \
			- (cam_transform.basis.z * forward_distance) \
			+ (cam_transform.basis.x * horizontal_offset) \
			+ (cam_transform.basis.y * vertical_offset)

	enemy_node.global_position = spawn_pos
	enemy_node.scale = model_scale

	var target_look_at: Vector3 = Vector3(cam_transform.origin.x, enemy_node.global_position.y, cam_transform.origin.z)
	enemy_node.look_at(target_look_at, Vector3.UP)
	enemy_node.rotate_object_local(Vector3.UP, PI)


# ==============================================================================
# 5. ANIMATION & FX
# ==============================================================================
func play_animation(enemy_node: Node3D, anim_name: StringName, loop: bool = true) -> void:
	if not is_instance_valid(enemy_node):
		return

	var anim_player: AnimationPlayer = enemy_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if is_instance_valid(anim_player) and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
		if not loop:
			anim_player.animation_finished.connect(
				func(finished_anim: StringName) -> void:
					if finished_anim != &"die" and is_instance_valid(enemy_node):
						play_animation(enemy_node, &"idle", true),
				CONNECT_ONE_SHOT
			)


func _create_debug_mesh() -> Node3D:
	var container := Node3D.new()
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.6, 1.0)
	mesh_inst.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	mesh_inst.material_override = mat
	container.add_child(mesh_inst)
	return container


func _on_enemy_attack_started(enemy_id: String) -> void:
	if _spawned_enemies.has(enemy_id):
		play_animation(_spawned_enemies[enemy_id], &"attack-melee-left", false)


func _on_enemy_damaged(enemy_id: String, _damage: int) -> void:
	if _spawned_enemies.has(enemy_id):
		play_animation(_spawned_enemies[enemy_id], &"interact-left", false)


func _on_enemy_health_changed(enemy_id: String, current_hp: int, _max_hp: int) -> void:
	if current_hp <= 0 and _spawned_enemies.has(enemy_id):
		var enemy_node: Node3D = _spawned_enemies[enemy_id]
		play_animation(enemy_node, &"die", false)

		var anim_player: AnimationPlayer = enemy_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if is_instance_valid(anim_player) and anim_player.has_animation(&"die"):
			await anim_player.animation_finished

		if is_instance_valid(enemy_node):
			enemy_node.queue_free()
		_spawned_enemies.erase(enemy_id)


func _on_combat_ended(_victory: bool) -> void:
	_clear_all_enemies()
	visible = false


func _clear_all_enemies() -> void:
	for enemy_id in _spawned_enemies:
		if is_instance_valid(_spawned_enemies[enemy_id]):
			_spawned_enemies[enemy_id].queue_free()
	_spawned_enemies.clear()


func play_target_vfx(enemy_id: String, vfx_frames: SpriteFrames, trauma_amount: float = 0.3) -> void:
	if not _spawned_enemies.has(enemy_id) or vfx_frames == null:
		return

	var enemy_node: Node3D = _spawned_enemies[enemy_id] as Node3D
	if not is_instance_valid(enemy_node):
		return

	var vfx_sprite := AnimatedSprite3D.new()
	vfx_sprite.sprite_frames = vfx_frames
	vfx_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	vfx_sprite.no_depth_test = true
	vfx_sprite.position = Vector3(0.0, 0.8, 0.2)

	enemy_node.add_child(vfx_sprite)

	var anim_names: PackedStringArray = vfx_frames.get_animation_names()
	if anim_names.size() > 0:
		vfx_sprite.play(anim_names[0])
		vfx_sprite.animation_finished.connect(vfx_sprite.queue_free, CONNECT_ONE_SHOT)
	else:
		vfx_sprite.queue_free()

	var sb: Node = SignalBus
	if is_instance_valid(sb) and sb.has_signal(&"camera_shake_requested"):
		sb.camera_shake_requested.emit(trauma_amount)
