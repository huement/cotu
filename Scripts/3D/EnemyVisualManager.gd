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

## Closest a spawned mesh is allowed to sit to the camera after layout.
@export var min_camera_clearance: float = 1.8

## Uniform scale multiplier for 3D enemy models.
@export var model_scale: Vector3 = Vector3(0.4, 0.4, 0.4)

## Horizontal spacing when multiple enemies are spawned.
@export var horizontal_spacing: float = 1.2


# ==============================================================================
# 2. RUNTIME STATE & ANIMATION MAPPINGS
# ==============================================================================
var _spawned_enemies: Dictionary = {}
var _adopted_world_models: Dictionary = {}

## Fallback animation candidate aliases for various 3D model formats (including Minotaur GLB)
const ANIM_MAPPINGS: Dictionary = {
	&"idle": [&"IDLE", &"Idle", &"idle", &"Armature|idle", &"idle_loop", &"Idle_Loop", &"ArmatureAction", &"Armature|ArmatureAction"],
	&"walk": [&"WALK", &"Walk", &"walk", &"Armature|Walk", &"walk_loop", &"Walk_Loop"],
	&"attack": [&"ATTACK_1", &"Attack", &"attack", &"Armature|Attack", &"CastSpell", &"attack-melee-left", &"Cast", &"cast", &"ArmatureAction", &"Armature|ArmatureAction"],
	&"attack_special": [&"ATTACK_SPECIAL", &"Armature|Attack Double", &"Attack Double", &"attack_double", &"SpecialAttack"],
	&"attack_jump": [&"ATTACK_JUMP", &"Armature|Jump", &"Jump", &"jump", &"JumpAttack"],
	&"damage": [&"TakeDamage", &"interact-left", &"Hit", &"hit", &"Damage", &"damage", &"GetHit", &"hurt", &"Hurt", &"HURT"],
	&"die": [&"DEATH", &"Die", &"die", &"Death", &"death", &"Armature|Death", &"Dead", &"dead"]
}

var enemy_group: Array[Resource]
## Per-level height correction for battle models, read from the active map's SpawnPoint
## metadata "battle_vertical_offset". Use it with a taller eye_height so enemies stay on the ground.
var _level_battle_offset: float = 0.0

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
			var best_node: Node3D = _find_nearest_world_enemy(target_res)

			if is_instance_valid(best_node) and ("enemy_group" in best_node):
				var grp: Variant = best_node.get("enemy_group")
				if grp is Array and not (grp as Array).is_empty():
					for item in (grp as Array):
						if item is Resource:
							result.append(item as Resource)

			if result.is_empty():
				var count: int = 1
				if is_instance_valid(best_node) and "pack_size" in best_node:
					count = max(1, int(best_node.get("pack_size")))
				elif "pack_size" in payload:
					count = max(1, int(payload.get("pack_size")))
				for i in range(count):
					result.append(target_res.duplicate(true) if count > 1 else target_res)

	return result


func _find_nearest_world_enemy(target_res: Resource) -> Node3D:
	var overworld_enemies: Array[Node] = get_tree().get_nodes_in_group(&"world_enemies")
	if overworld_enemies.is_empty():
		overworld_enemies = get_tree().root.find_children("*", "WorldEnemy", true, false)
		overworld_enemies.append_array(get_tree().root.find_children("*", "OutdoorEnemy", true, false))
		overworld_enemies.append_array(get_tree().root.find_children("*", "TentacleEnemyController", true, false))

	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var player_pos: Vector3 = player.global_position if is_instance_valid(player) else Vector3.ZERO
	var player_cell: Vector2i = player.current_grid_pos if is_instance_valid(player) and ("current_grid_pos" in player) else Vector2i(-9999, -9999)

	var best_node: Node3D = null
	var min_dist: float = INF

	for node in overworld_enemies:
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var enemy_node: Node3D = node as Node3D
		if not enemy_node.visible and not ("_is_in_active_combat" in enemy_node and bool(enemy_node.get("_is_in_active_combat"))):
			continue

		var grp: Variant = enemy_node.get("enemy_group") if "enemy_group" in enemy_node else null
		var n_data: Variant = enemy_node.get("data") if "data" in enemy_node else null
		var n_edata: Variant = enemy_node.get("enemy_data") if "enemy_data" in enemy_node else null

		var matches: bool = n_data == target_res or n_edata == target_res
		if not matches and grp is Array:
			matches = (grp as Array).has(target_res)

		if not matches:
			continue

		var dist: float = enemy_node.global_position.distance_to(player_pos)
		if enemy_node.has_method("get_grid_pos") and player_cell != Vector2i(-9999, -9999):
			var n_cell: Vector2i = enemy_node.get_grid_pos()
			dist = float(absi(n_cell.x - player_cell.x) + absi(n_cell.y - player_cell.y))

		if dist < min_dist:
			min_dist = dist
			best_node = enemy_node

	return best_node


func _ensure_camera() -> bool:
	if is_instance_valid(camera_node):
		return true

	camera_node = get_viewport().get_camera_3d()
	if not is_instance_valid(camera_node):
		var player_node: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
		if is_instance_valid(player_node):
			camera_node = player_node.find_child("Camera3D", true, false) as Camera3D

	if not is_instance_valid(camera_node):
		push_error("[EnemyVisualManager] ERROR: Could not find an active Camera3D in Scene Tree.")
		return false
	return true


func _on_combat_started(enemy_payload: Variant, _player_party: Array, _enemy_facing: String) -> void:
	if visible and not _spawned_enemies.is_empty():
		return
	if not _ensure_camera():
		return

	_clear_all_enemies()
	visible = true
	_level_battle_offset = _read_level_battle_offset()

	enemy_group = _resolve_enemy_resources(enemy_payload)

	for i in range(enemy_group.size()):
		var e_data: Resource = enemy_group[i] as Resource
		if _uses_world_combat_node(e_data):
			continue
		var enemy_id: String = "enemy_%d" % i
		var enemy_node: Node3D = _spawn_or_adopt_combat_model(e_data, enemy_id)
		if not is_instance_valid(enemy_node):
			continue
		_spawned_enemies[enemy_id] = enemy_node
		play_animation(enemy_node, &"idle", true)

	layout_combat_models()
	call_deferred("layout_combat_models")
	# Safety: lay out again once the camera has fully settled (party was mid-step or mid-turn).
	get_tree().create_timer(0.25).timeout.connect(_relayout_if_fighting, CONNECT_ONE_SHOT)
	get_tree().create_timer(0.6).timeout.connect(_relayout_if_fighting, CONNECT_ONE_SHOT)

	if is_instance_valid(GameLogger):
		GameLogger.combat("EnemyVisualManager spawning %d combat model(s)" % _spawned_enemies.size())


func _relayout_if_fighting() -> void:
	if visible and not _spawned_enemies.is_empty():
		layout_combat_models()


func _read_level_battle_offset() -> float:
	var map_mgr: Node = get_tree().root.find_child("MapManager", true, false)
	if not is_instance_valid(map_mgr) or not "active_map_instance" in map_mgr:
		return 0.0
	var map_root: Node = map_mgr.get("active_map_instance") as Node
	if not is_instance_valid(map_root):
		return 0.0
	var spawn: Node = map_root.get_node_or_null("SpawnPoint")
	if is_instance_valid(spawn) and spawn.has_meta("battle_vertical_offset"):
		return float(spawn.get_meta("battle_vertical_offset"))
	return 0.0


func _uses_world_combat_node(e_data: Resource) -> bool:
	if not is_instance_valid(e_data):
		return false
	if e_data.has_meta(&"use_world_combat_model"):
		return true
	return "combat_uses_world_node" in e_data and bool(e_data.get("combat_uses_world_node"))


func _spawn_or_adopt_combat_model(e_data: Resource, _enemy_id: String) -> Node3D:
	var model_scene: PackedScene = null
	if is_instance_valid(e_data) and "model_scene" in e_data:
		model_scene = e_data.get("model_scene") as PackedScene

	var enemy_node: Node3D
	if is_instance_valid(model_scene):
		enemy_node = model_scene.instantiate() as Node3D
		_apply_material_to_model(enemy_node, e_data)
	else:
		enemy_node = _create_debug_mesh()

	add_child(enemy_node)
	return enemy_node


## Places every combat model in front of the camera. Call this at battle start
## and any time the fight roster changes.
func layout_combat_models() -> void:
	if not _ensure_camera():
		return

	var ids: Array = _spawned_enemies.keys()
	ids.sort()
	var total: int = ids.size()
	for i in range(total):
		var enemy_id: String = str(ids[i])
		var enemy_node: Node3D = _spawned_enemies[enemy_id] as Node3D
		if not is_instance_valid(enemy_node):
			continue
		var slot_index: int = int(enemy_id.trim_prefix("enemy_"))
		var e_data: Resource = null
		if slot_index >= 0 and slot_index < enemy_group.size():
			e_data = enemy_group[slot_index]
		if _uses_world_combat_node(e_data):
			continue
		_position_enemy(enemy_node, i, total, e_data)


func _position_enemy(enemy_node: Node3D, index: int, total_enemies: int, e_data: Resource = null) -> void:
	if not is_instance_valid(camera_node) or not is_instance_valid(enemy_node):
		return

	var is_world_model: bool = is_instance_valid(e_data) and e_data.has_meta(&"use_world_combat_model")

	var effective_spacing: float = horizontal_spacing
	if total_enemies >= 3:
		effective_spacing = horizontal_spacing * 0.65

	var horizontal_offset: float = 0.0
	if total_enemies > 1:
		horizontal_offset = (float(index) - (float(total_enemies - 1) / 2.0)) * effective_spacing

	var v_offset: float = vertical_offset
	if is_instance_valid(e_data) and "vertical_offset" in e_data:
		v_offset = float(e_data.get("vertical_offset"))
	v_offset += _level_battle_offset

	if not is_world_model:
		var target_scale: Vector3 = model_scale
		if is_instance_valid(e_data) and "model_scale" in e_data and e_data.get("model_scale") != Vector3.ZERO:
			target_scale = e_data.get("model_scale") as Vector3
		enemy_node.scale = target_scale

	var cam_distance: float = forward_distance
	if is_instance_valid(e_data) and "combat_forward_distance" in e_data:
		var custom_dist: float = float(e_data.get("combat_forward_distance"))
		if custom_dist > 0.0:
			cam_distance = custom_dist

	var cam_transform: Transform3D = camera_node.global_transform
	var spawn_pos: Vector3 = cam_transform.origin \
			- (cam_transform.basis.z * cam_distance) \
			+ (cam_transform.basis.x * horizontal_offset) \
			+ (cam_transform.basis.y * v_offset)

	enemy_node.global_position = spawn_pos

	var target_look_at: Vector3 = Vector3(cam_transform.origin.x, enemy_node.global_position.y, cam_transform.origin.z)
	if enemy_node.global_position.distance_squared_to(target_look_at) > 0.0001:
		enemy_node.look_at(target_look_at, Vector3.UP)

	var yaw_offset_deg: float = 0.0 if is_world_model else 180.0
	if is_instance_valid(e_data) and "combat_yaw_offset_degrees" in e_data:
		yaw_offset_deg = float(e_data.get("combat_yaw_offset_degrees"))
	if not is_zero_approx(yaw_offset_deg):
		enemy_node.rotate_object_local(Vector3.UP, deg_to_rad(yaw_offset_deg))

	_push_back_from_camera(enemy_node)


func _push_back_from_camera(enemy_node: Node3D) -> void:
	if not is_instance_valid(camera_node) or not is_instance_valid(enemy_node):
		return

	var aabb: AABB = _get_visual_aabb(enemy_node)
	if aabb.size == Vector3.ZERO:
		return

	var cam_origin: Vector3 = camera_node.global_position
	var forward: Vector3 = -camera_node.global_transform.basis.z
	var min_depth: float = INF
	var corners: Array[Vector3] = [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
		aabb.position + Vector3(0.0, aabb.size.y, 0.0),
		aabb.position + Vector3(0.0, 0.0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
		aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
		aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size,
	]
	for corner: Vector3 in corners:
		min_depth = minf(min_depth, (corner - cam_origin).dot(forward))

	if min_depth < min_camera_clearance:
		enemy_node.global_position += forward * (min_camera_clearance - min_depth)


func _get_visual_aabb(node: Node3D) -> AABB:
	var merged: AABB = AABB()
	var has_any: bool = false
	var visuals: Array[Node] = node.find_children("*", "VisualInstance3D", true, false)
	if node is VisualInstance3D:
		visuals.append(node)

	for child in visuals:
		var vis: VisualInstance3D = child as VisualInstance3D
		if not is_instance_valid(vis):
			continue
		var local_aabb: AABB = vis.get_aabb()
		if local_aabb.size == Vector3.ZERO:
			continue
		var world_aabb: AABB = vis.global_transform * local_aabb
		if not has_any:
			merged = world_aabb
			has_any = true
		else:
			merged = merged.merge(world_aabb)

	return merged if has_any else AABB()


func _apply_material_to_model(model_node: Node3D, e_data: Resource) -> void:
	if not is_instance_valid(model_node) or not is_instance_valid(e_data):
		return

	var mat: Material = null

	if "custom_material" in e_data and is_instance_valid(e_data.get("custom_material")):
		mat = e_data.get("custom_material") as Material

	if mat == null and "texture_path" in e_data and not str(e_data.get("texture_path")).is_empty():
		var tex_path: String = str(e_data.get("texture_path"))
		var tres_path: String = tex_path.replace(".png", ".tres")
		if ResourceLoader.exists(tres_path):
			mat = load(tres_path) as Material
		elif ResourceLoader.exists(tex_path):
			var tex: Texture2D = load(tex_path) as Texture2D
			if is_instance_valid(tex):
				var std_mat := StandardMaterial3D.new()
				std_mat.albedo_texture = tex
				std_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				std_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mat = std_mat

	if mat == null and "model_scene" in e_data and is_instance_valid(e_data.get("model_scene")):
		var model_scene: PackedScene = e_data.get("model_scene") as PackedScene
		var path: String = model_scene.resource_path
		var dir: String = path.get_base_dir()
		var base_file: String = path.get_file().get_basename()
		var tex_name: String = base_file.replace("character-", "texture-")

		var candidates: Array[String] = [
			dir + "/" + tex_name + ".tres",
			dir + "/" + tex_name + ".png",
			dir + "/texture-l.tres",
			dir + "/texture-l.png",
			dir + "/texture-d.png"
		]

		for cand in candidates:
			if ResourceLoader.exists(cand):
				if cand.ends_with(".tres"):
					mat = load(cand) as Material
					break
				elif cand.ends_with(".png"):
					var tex: Texture2D = load(cand) as Texture2D
					if is_instance_valid(tex):
						var std_mat := StandardMaterial3D.new()
						std_mat.albedo_texture = tex
						std_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
						std_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
						mat = std_mat
						break

	if is_instance_valid(mat):
		_apply_material_override_recursive(model_node, mat)


func _apply_material_override_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node as MeshInstance3D
		# If the mesh has multiple material surfaces (like a mouth + body), 
		# do not stomp them with a single global material_override.
		if mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 1:
			return
		mesh_inst.material_override = mat

	for child: Node in node.get_children():
		_apply_material_override_recursive(child, mat)


# ==============================================================================
# 5. ANIMATION & FX
# ==============================================================================
func play_animation(enemy_node: Node3D, action_key: StringName, loop: bool = true) -> void:
	if not is_instance_valid(enemy_node):
		return

	# 1. Models with a VisualJuice node (blobs, tentacles...) are animated procedurally.
	#    Never play their GLB animations: e.g. blobby.glb's only clip rotates the body
	#    bone 90 degrees and tips the blob onto its side.
	var juice: Node = enemy_node.find_child("VisualJuice", true, false)
	if is_instance_valid(juice):
		if action_key == &"damage" and juice.has_method("play_hit_shake"):
			juice.call("play_hit_shake")
		return

	if action_key == &"damage" and enemy_node.has_method("on_take_hit"):
		enemy_node.call("on_take_hit")

	# 2. Locate AnimationPlayer
	var anim_player: AnimationPlayer = enemy_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not is_instance_valid(anim_player):
		return

	# 3. Resolve animation name against ANIM_MAPPINGS
	var resolved_anim: StringName = _resolve_animation_name(anim_player, action_key)
	if resolved_anim.is_empty():
		return

	# 4. Do not restart if already looping the requested animation
	if loop and anim_player.current_animation == resolved_anim and anim_player.is_playing():
		return

	# 5. Enforce loop mode on the Animation resource in Godot 4
	var anim: Animation = anim_player.get_animation(resolved_anim)
	if is_instance_valid(anim):
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

	anim_player.play(resolved_anim)

	# 6. Automatically return to idle once a one-shot attack or interaction finishes
	if not loop and action_key != &"die":
		anim_player.animation_finished.connect(
			func(_finished_anim: StringName) -> void:
				if is_instance_valid(enemy_node):
					play_animation(enemy_node, &"idle", true),
			CONNECT_ONE_SHOT
		)


func _resolve_animation_name(anim_player: AnimationPlayer, action_key: StringName) -> StringName:
	if not is_instance_valid(anim_player):
		return &""

	var candidates: Array = ANIM_MAPPINGS.get(action_key, [action_key])

	for candidate in candidates:
		var cand_name := StringName(str(candidate))
		if anim_player.has_animation(cand_name):
			return cand_name

	var available: PackedStringArray = anim_player.get_animation_list()
	for candidate in candidates:
		var cand_str: String = str(candidate).to_lower()
		for anim_name in available:
			if cand_str in anim_name.to_lower():
				return StringName(anim_name)

	if available.size() > 0:
		return StringName(available[0])

	return &""


## Lets a world-placed combat node (e.g. BlobBossController and its minions)
## receive hit shakes and death sinks. Adopted nodes are hidden on death, never freed,
## because their owner manages their lifetime.
func register_world_combat_model(enemy_id: String, node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	_spawned_enemies[enemy_id] = node
	_adopted_world_models[enemy_id] = true


func _on_enemy_attack_started(enemy_id: String) -> void:
	if not _spawned_enemies.has(enemy_id):
		return
	var enemy_node: Node3D = _spawned_enemies[enemy_id] as Node3D
	if not is_instance_valid(enemy_node):
		return
	# Models without an AnimationPlayer attack (e.g. blobs) use their VisualJuice lunge
	var juice: Node = enemy_node.find_child("VisualJuice", true, false)
	if is_instance_valid(juice) and juice.has_method("play_attack_animation"):
		juice.call("play_attack_animation")
		return
	play_animation(enemy_node, &"attack", false)


func _on_enemy_damaged(enemy_id: String, _damage: int) -> void:
	if _spawned_enemies.has(enemy_id):
		play_animation(_spawned_enemies[enemy_id], &"damage", false)


func _on_enemy_health_changed(enemy_id: String, current_hp: int, _max_hp: int) -> void:
	if current_hp <= 0 and _spawned_enemies.has(enemy_id):
		var enemy_node: Node3D = _spawned_enemies[enemy_id]
		
		# Check for procedural sink first
		var juice: Node = enemy_node.find_child("VisualJuice", true, false)
		if is_instance_valid(juice) and juice.has_method("play_death_sink"):
			juice.call("play_death_sink")
			var sink_depth: Variant = juice.get("sink_depth")
			var sink_speed: Variant = juice.get("sink_speed")
			var sink_time: float = 1.2
			if sink_depth != null and sink_speed != null:
				sink_time = float(sink_depth) / maxf(0.1, float(sink_speed))
			await get_tree().create_timer(sink_time).timeout
		else:
			play_animation(enemy_node, &"die", false)
			var anim_player: AnimationPlayer = enemy_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if is_instance_valid(anim_player):
				var resolved_die: StringName = _resolve_animation_name(anim_player, &"die")
				if not resolved_die.is_empty() and anim_player.has_animation(resolved_die):
					await anim_player.animation_finished

		if is_instance_valid(enemy_node):
			if _adopted_world_models.has(enemy_id):
				enemy_node.visible = false
			else:
				enemy_node.queue_free()
		_spawned_enemies.erase(enemy_id)
		_adopted_world_models.erase(enemy_id)


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


func _on_combat_ended(_victory: bool) -> void:
	_clear_all_enemies()
	visible = false


func _clear_all_enemies() -> void:
	for enemy_id in _spawned_enemies:
		if _adopted_world_models.has(enemy_id):
			continue
		if is_instance_valid(_spawned_enemies[enemy_id]):
			_spawned_enemies[enemy_id].queue_free()
	_spawned_enemies.clear()
	_adopted_world_models.clear()


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
