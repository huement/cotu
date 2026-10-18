# res://Scripts/Enemies/TentacleEnemyController.gd
class_name TentacleEnemyController
extends Node3D

## TEST ONLY. true = boss appears after the first tentacle pack is killed.
## Set back to false for the real game (all lake tentacles must die).
const DEBUG_REVEAL_BOSS_AFTER_ONE_KILL: bool = true

@export var data: EnemyData:
	get:
		return _enemy_data
	set(val):
		_enemy_data = val
		if _enemy_data:
			current_health = _enemy_data.max_health
		_update_enemy_group()

## Number of tentacles to spawn in combat (1, 2, or 3)
@export_range(1, 3) var pack_size: int = 1:
	set(val):
		pack_size = val
		_update_enemy_group()

## If true, permanently removes this overworld node from the map when defeated in combat.
@export var destroy_on_victory: bool = true

var _enemy_data: EnemyData
var current_health: int = 60
var _is_in_active_combat: bool = false
var enemy_group: Array[Resource] = []

@onready var visual_juice: Node3D = $VisualJuice
@onready var model_instance: Node3D = $VisualJuice/ModelInstance
@onready var activation_area: Area3D = get_node_or_null("ActivationArea") as Area3D

var _anim_player: AnimationPlayer


func _ready() -> void:
	add_to_group(&"world_enemies")
	add_to_group(&"lake_tentacles")
	if _enemy_data:
		current_health = _enemy_data.max_health
	_update_enemy_group()
	_setup_animation_player()
	_connect_signal_bus()
	play_idle()


## Rebuilds the combat pack from EnemyData. Combat uses EnemyData.model_scale, not the overworld node scale.
func _update_enemy_group() -> void:
	enemy_group.clear()
	if not is_instance_valid(_enemy_data):
		return

	for i in range(pack_size):
		var res: EnemyData = _enemy_data.duplicate(true) as EnemyData
		if "model_scene" in _enemy_data and _enemy_data.get("model_scene") != null:
			res.set("model_scene", _enemy_data.get("model_scene"))
		if "custom_material" in _enemy_data and _enemy_data.get("custom_material") != null:
			res.set("custom_material", _enemy_data.get("custom_material"))
		if "texture_path" in _enemy_data and not str(_enemy_data.get("texture_path")).is_empty():
			res.set("texture_path", _enemy_data.get("texture_path"))
		enemy_group.append(res)


func _connect_signal_bus() -> void:
	var sb: Node = SignalBus
	if is_instance_valid(sb):
		if not sb.combat_started.is_connected(_on_combat_started):
			sb.combat_started.connect(_on_combat_started)
		if not sb.combat_ended.is_connected(_on_combat_ended):
			sb.combat_ended.connect(_on_combat_ended)

	if is_instance_valid(activation_area):
		if not activation_area.body_entered.is_connected(_on_body_entered):
			activation_area.body_entered.connect(_on_body_entered)


func _setup_animation_player() -> void:
	if not model_instance:
		return
	for child: Node in model_instance.get_children():
		if child is AnimationPlayer:
			_anim_player = child
			break
	if not _anim_player:
		_anim_player = model_instance.find_child("AnimationPlayer", true, false)


func play_idle() -> void:
	if _anim_player and _anim_player.has_animation(&"idle"):
		var anim: Animation = _anim_player.get_animation(&"idle")
		anim.loop_mode = Animation.LOOP_LINEAR
		_anim_player.play(&"idle")


func play_attack() -> void:
	if _anim_player and _anim_player.has_animation(&"attack"):
		_anim_player.play(&"attack")
		if not _anim_player.animation_finished.is_connected(_on_animation_finished):
			_anim_player.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)


func _on_animation_finished(_anim_name: StringName) -> void:
	play_idle()


func get_grid_pos() -> Vector2i:
	var map_mgr: Node = get_tree().root.find_child("MapManager", true, false)
	if is_instance_valid(map_mgr) and map_mgr.has_method("world_to_grid"):
		var cell: Vector3i = map_mgr.call("world_to_grid", global_position) as Vector3i
		return Vector2i(cell.x, cell.z)
	return Vector2i(roundi(global_position.x / 2.0), roundi(global_position.z / 2.0))


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(&"player") or body.name == "Player" or body is CharacterBody3D:
		trigger_combat_encounter()


## WorldEnemy-compatible combat entry used by Player / MapManager bump encounters.
func trigger_combat_encounter() -> void:
	if _is_in_active_combat:
		return

	var cm: Node = get_tree().root.get_node_or_null("CombatManager")
	if is_instance_valid(cm):
		if cm.get("is_combat_active") or ("is_transitioning_out" in cm and cm.get("is_transitioning_out")):
			return

	if enemy_group.is_empty():
		_update_enemy_group()

	_is_in_active_combat = true
	visible = false

	var party_slots: Array = []
	if "current_party" in GameState and GameState.current_party != null:
		if "slots" in GameState.current_party:
			party_slots = GameState.current_party.slots

	if is_instance_valid(GameLogger):
		GameLogger.combat("Player engaged tentacle pack (%d) at cell Vector2i%s" % [enemy_group.size(), get_grid_pos()])

	SignalBus.combat_started.emit(enemy_group, party_slots, "SOUTH")


func trigger_battle() -> void:
	trigger_combat_encounter()


func _payload_matches_this_pack(combat_enemy_data: Variant) -> bool:
	if combat_enemy_data is Array:
		var arr: Array = combat_enemy_data as Array
		if arr == enemy_group:
			return true
		for item in arr:
			if enemy_group.has(item):
				return true
		return false

	if is_instance_valid(combat_enemy_data):
		if combat_enemy_data == data or enemy_group.has(combat_enemy_data):
			return true
		if "members" in combat_enemy_data:
			var members: Array = combat_enemy_data.get("members") as Array
			if members != null:
				for item in members:
					if enemy_group.has(item) or item == data:
						return true
	return false


func _on_combat_started(combat_enemy_data: Variant, _player_party: Array = [], _enemy_facing: String = "") -> void:
	if _is_in_active_combat or not visible:
		return

	if _payload_matches_this_pack(combat_enemy_data):
		_is_in_active_combat = true
		visible = false


func _on_combat_ended(victory: bool) -> void:
	if not _is_in_active_combat:
		return

	_is_in_active_combat = false

	if victory:
		if destroy_on_victory:
			var tree: SceneTree = get_tree()
			tree_exited.connect(func() -> void:
				_reveal_boss_if_last_tentacle(tree)
			, CONNECT_ONE_SHOT)
			queue_free()
		else:
			visible = false
			_reveal_boss_if_last_tentacle(get_tree())
	else:
		visible = true


func _reveal_boss_if_last_tentacle(tree: SceneTree) -> void:
	if not is_instance_valid(tree):
		return

	if not DEBUG_REVEAL_BOSS_AFTER_ONE_KILL:
		for node: Node in tree.get_nodes_in_group(&"lake_tentacles"):
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				return

	for boss: Node in tree.get_nodes_in_group(&"lake_boss"):
		if is_instance_valid(boss) and boss.has_method("queue_reveal_after_loot"):
			boss.call("queue_reveal_after_loot")


func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	on_take_hit()
	if current_health <= 0:
		on_defeated()


func on_take_hit() -> void:
	if visual_juice and visual_juice.has_method("play_hit_shake"):
		visual_juice.call("play_hit_shake")


func on_defeated() -> void:
	if visual_juice and visual_juice.has_method("play_death_sink"):
		visual_juice.call("play_death_sink")
