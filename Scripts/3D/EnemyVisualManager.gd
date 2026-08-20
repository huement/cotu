# res://Scripts/3D/EnemyVisualManager.gd
class_name EnemyVisualManager
extends Node3D

@export var camera_node: Camera3D
@export var forward_distance: float = 2.5
@export var vertical_offset: float = -0.85
@export var model_scale: Vector3 = Vector3(0.4, 0.4, 0.4)
@export var horizontal_spacing: float = 0.85

var _spawned_enemies: Dictionary = { }


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

# res://Scripts/3D/EnemyVisualManager.gd


func _on_combat_started(enemy_data_or_group: Variant, _player_party: Array) -> void:
	if not is_instance_valid(camera_node):
		camera_node = get_viewport().get_camera_3d()
		if not is_instance_valid(camera_node):
			push_error("[EnemyVisualManager] ERROR: Could not find an active Camera3D in Scene Tree.")
			return

	_clear_all_enemies()
	visible = true

	var enemy_group: Array = []
	if enemy_data_or_group is Array:
		enemy_group = enemy_data_or_group as Array
	elif is_instance_valid(enemy_data_or_group):
		if "members" in enemy_data_or_group and enemy_data_or_group.get("members") is Array:
			enemy_group = enemy_data_or_group.get("members") as Array
		elif enemy_data_or_group is Resource:
			enemy_group = [enemy_data_or_group as Resource]

	for i in range(enemy_group.size()):
		var e_data: EnemyData = enemy_group[i] as EnemyData
		var model_scene: PackedScene = null

		if is_instance_valid(e_data):
			model_scene = e_data.model_scene

		var enemy_node: Node3D = null
		if is_instance_valid(model_scene):
			enemy_node = model_scene.instantiate() as Node3D

			# Apply external custom_material if assigned (leaves embedded GLB textures untouched)
			var mat_to_apply: Material = e_data.custom_material if is_instance_valid(e_data) else null
			if mat_to_apply != null:
				_apply_material_override_recursive(enemy_node, mat_to_apply)
		else:
			enemy_node = _create_debug_mesh()

		var enemy_id: String = "enemy_%d" % i
		_spawned_enemies[enemy_id] = enemy_node
		add_child(enemy_node)

		_position_enemy(enemy_node, i, enemy_group.size())
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


func play_animation(enemy_node: Node3D, anim_name: StringName, loop: bool = true) -> void:
	if not is_instance_valid(enemy_node):
		return

	var anim_player: AnimationPlayer = enemy_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if is_instance_valid(anim_player) and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
		if not loop:
			# 🎯 Cleanly auto-disconnect using Godot 4's CONNECT_ONE_SHOT flag
			anim_player.animation_finished.connect(
				func(finished_anim: StringName) -> void:
					if finished_anim != &"die" and is_instance_valid(enemy_node):
						play_animation(enemy_node, &"idle", true),
				CONNECT_ONE_SHOT,
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


## Instantiates 3D enemy model and applies compiled texture materials
func spawn_enemy_model(enemy_data: EnemyData) -> Node3D:
	if not is_instance_valid(enemy_data) or enemy_data.model_scene == null:
		return null

	var model_instance := enemy_data.model_scene.instantiate() as Node3D
	add_child(model_instance)
	model_instance.scale = enemy_data.model_scale

	var mat_to_apply: Material = enemy_data.custom_material
	if mat_to_apply == null and not enemy_data.texture_path.is_empty():
		var tres_path: String = enemy_data.texture_path.replace(".png", ".tres")
		if ResourceLoader.exists(tres_path):
			mat_to_apply = load(tres_path) as StandardMaterial3D

	if mat_to_apply != null:
		_apply_material_override_recursive(model_instance, mat_to_apply)

	return model_instance


func _apply_material_override_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat

	for child in node.get_children():
		_apply_material_override_recursive(child, mat)
