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


## Fallback animation candidate aliases for various 3D model formats (e.g. Ghost, Kenny, Mixamo)
# ==============================================================================
# 2. RUNTIME STATE & ANIMATION MAPPINGS
# ==============================================================================
var _spawned_enemies: Dictionary = {}

## Fallback animation candidate aliases for various 3D model formats
const ANIM_MAPPINGS: Dictionary = {
	&"idle": [&"Idle", &"idle", &"IDLE", &"idle_loop", &"Idle_Loop"],
	&"attack": [&"CastSpell", &"attack-melee-left", &"Attack", &"attack", &"Cast", &"cast", &"SpellCast"],
	&"damage": [&"TakeDamage", &"interact-left", &"Hit", &"hit", &"Damage", &"damage", &"GetHit"],
	&"die": [&"Die", &"die", &"Death", &"death", &"Dead", &"dead"]
}


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
## Resolves any enemy payload variant into a typed Array[Resource] using player proximity for single resources
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

		# 🎯 Proximity-based lookup: Find the closest active overworld WorldEnemy node matching the resource
		if result.is_empty() and payload is Resource:
			var target_res: Resource = payload as Resource
			var overworld_enemies: Array[Node] = get_tree().get_nodes_in_group(&"world_enemies")
			if overworld_enemies.is_empty():
				overworld_enemies = get_tree().root.find_children("*", "WorldEnemy", true, false)

			var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
			var player_cell: Vector2i = player.current_grid_pos if is_instance_valid(player) and ("current_grid_pos" in player) else Vector2i(-9999, -9999)

			var best_node: Node3D = null
			var min_dist: int = 9999

			for node in overworld_enemies:
				if is_instance_valid(node) and ("enemy_group" in node) and node.visible:
					var grp: Variant = node.get("enemy_group")
					var n_data: Variant = node.get("data") if "data" in node else null
					var n_edata: Variant = node.get("enemy_data") if "enemy_data" in node else null

					if (grp is Array and (grp as Array).has(target_res)) or n_data == target_res or n_edata == target_res:
						var n_cell: Vector2i = node.get_grid_pos() if node.has_method("get_grid_pos") else Vector2i(9999, 9999)
						var dist: int = absi(n_cell.x - player_cell.x) + absi(n_cell.y - player_cell.y)
						if dist < min_dist:
							min_dist = dist
							best_node = node as Node3D

			if is_instance_valid(best_node) and ("enemy_group" in best_node):
				var grp: Variant = best_node.get("enemy_group")
				if grp is Array and not (grp as Array).is_empty():
					for item in (grp as Array):
						if item is Resource:
							result.append(item as Resource)

			if result.is_empty():
				var count: int = 1
				if "pack_size" in payload:
					count = max(1, int(payload.get("pack_size")))
				for i in range(count):
					result.append(target_res.duplicate() if count > 1 else target_res)

	return result


func _on_combat_started(enemy_payload: Variant, _player_party: Array, _enemy_facing: String) -> void:
	if not is_instance_valid(camera_node):
		camera_node = get_viewport().get_camera_3d()
		if not is_instance_valid(camera_node):
			push_error("[EnemyVisualManager] ERROR: Could not find an active Camera3D in Scene Tree.")
			return

	_clear_all_enemies()
	visible = true

	# Standardize payload: handles single Resource or Array of Resources
	var enemy_group: Array = []
	if enemy_payload is Array:
		enemy_group = enemy_payload as Array
	elif enemy_payload is Resource:
		enemy_group.append(enemy_payload)
	
	for i in range(enemy_group.size()):
		var e_data: Resource = enemy_group[i] as Resource
		var model_scene: PackedScene = null
		
		if is_instance_valid(e_data) and "model_scene" in e_data:
			model_scene = e_data.get("model_scene") as PackedScene

		var enemy_node: Node3D
		if is_instance_valid(model_scene):
			enemy_node = model_scene.instantiate() as Node3D
			# 🎯 Binds custom_material / texture_path onto child MeshInstance3D nodes
			_apply_material_to_model(enemy_node, e_data)
		else:
			enemy_node = _create_debug_mesh()

		var enemy_id: String = "enemy_%d" % i
		_spawned_enemies[enemy_id] = enemy_node
		add_child(enemy_node)
		
		_position_enemy(enemy_node, i, enemy_group.size())
		play_animation(enemy_node, &"idle", true)


## Automatically resolves and applies texture materials to 3D GLB model meshes
func _apply_material_to_model(model_node: Node3D, e_data: Resource) -> void:
	if not is_instance_valid(model_node) or not is_instance_valid(e_data):
		return

	var mat: Material = null

	# 1. Custom material property on EnemyData
	if "custom_material" in e_data and is_instance_valid(e_data.get("custom_material")):
		mat = e_data.get("custom_material") as Material

	# 2. Texture path property on EnemyData
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

	# 3. Auto-resolve material from the GLB model scene directory
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
		(node as MeshInstance3D).material_override = mat

	for child in node.get_children():
		_apply_material_override_recursive(child, mat)
		

func _position_enemy(enemy_node: Node3D, index: int, total_enemies: int) -> void:
	if not is_instance_valid(camera_node):
		return

	# Dynamically tighten spacing as enemy count increases
	var effective_spacing: float = horizontal_spacing
	if total_enemies >= 3:
		effective_spacing = horizontal_spacing * 0.65  # Squeezes groups of 3+ together

	var horizontal_offset: float = 0.0
	if total_enemies > 1:
		horizontal_offset = (float(index) - (float(total_enemies - 1) / 2.0)) * effective_spacing

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
## Plays an animation for the model based on abstract action key (&"idle", &"attack", &"damage", &"die")
func play_animation(enemy_node: Node3D, action_key: StringName, loop: bool = true) -> void:
	if not is_instance_valid(enemy_node):
		return

	var anim_player: AnimationPlayer = enemy_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not is_instance_valid(anim_player):
		return

	var resolved_anim: StringName = _resolve_animation_name(anim_player, action_key)
	if resolved_anim.is_empty():
		return

	# Explicitly set Godot Animation loop mode on the Animation resource
	var anim: Animation = anim_player.get_animation(resolved_anim)
	if is_instance_valid(anim):
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

	anim_player.play(resolved_anim)

	# Non-looping actions (attack / damage) return to idle upon completion
	if not loop and action_key != &"die":
		anim_player.animation_finished.connect(
			func(_finished_anim: StringName) -> void:
				if is_instance_valid(enemy_node):
					play_animation(enemy_node, &"idle", true),
			CONNECT_ONE_SHOT
		)


## Resolves action state (&"idle", &"attack", &"damage", &"die") to actual animation clip names in the model's AnimationPlayer
func _resolve_animation_name(anim_player: AnimationPlayer, action_key: StringName) -> StringName:
	if not is_instance_valid(anim_player):
		return &""

	var candidates: Array = ANIM_MAPPINGS.get(action_key, [action_key])

	# 1. Exact match check
	for candidate in candidates:
		var cand_name := StringName(str(candidate))
		if anim_player.has_animation(cand_name):
			return cand_name

	# 2. Substring match fallback
	var available: PackedStringArray = anim_player.get_animation_list()
	for candidate in candidates:
		var cand_str: String = str(candidate).to_lower()
		for anim_name in available:
			if cand_str in anim_name.to_lower():
				return StringName(anim_name)

	return &""


func _on_enemy_attack_started(enemy_id: String) -> void:
	if _spawned_enemies.has(enemy_id):
		play_animation(_spawned_enemies[enemy_id], &"attack", false)


func _on_enemy_damaged(enemy_id: String, _damage: int) -> void:
	if _spawned_enemies.has(enemy_id):
		play_animation(_spawned_enemies[enemy_id], &"damage", false)


func _on_enemy_health_changed(enemy_id: String, current_hp: int, _max_hp: int) -> void:
	if current_hp <= 0 and _spawned_enemies.has(enemy_id):
		var enemy_node: Node3D = _spawned_enemies[enemy_id]
		play_animation(enemy_node, &"die", false)

		var anim_player: AnimationPlayer = enemy_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if is_instance_valid(anim_player):
			var resolved_die: StringName = _resolve_animation_name(anim_player, &"die")
			if not resolved_die.is_empty() and anim_player.has_animation(resolved_die):
				await anim_player.animation_finished

		if is_instance_valid(enemy_node):
			enemy_node.queue_free()
		_spawned_enemies.erase(enemy_id)


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
