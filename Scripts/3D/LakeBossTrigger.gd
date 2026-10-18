# res://Scripts/3D/LakeBossTrigger.gd
class_name LakeBossTrigger
extends Node3D

enum BossPhase { TENTACLES, MONSTER, DEFEATED }

@export_group("Visual Nodes")
@export var tentacle_model: Node3D
@export var monster_model: Node3D

@export_group("Encounter Data")
@export var tentacle_enemy_data: EnemyData
@export var monster_enemy_data: EnemyData

@export_group("Trigger Settings")
## Distance in world units from this node to trigger combat
@export var trigger_distance: float = 6.0

var current_phase: BossPhase = BossPhase.TENTACLES
var _combat_in_progress: bool = false
var _player_ref: Node3D = null

func _ready() -> void:
	_update_stage_visibility()
	_connect_signals()

func _connect_signals() -> void:
	if SignalBus:
		if not SignalBus.party_moved.is_connected(_on_party_moved):
			SignalBus.party_moved.connect(_on_party_moved)
		if not SignalBus.combat_ended.is_connected(_on_combat_ended):
			SignalBus.combat_ended.connect(_on_combat_ended)

func _update_stage_visibility() -> void:
	match current_phase:
		BossPhase.TENTACLES:
			if is_instance_valid(tentacle_model):
				tentacle_model.visible = true
			if is_instance_valid(monster_model):
				monster_model.visible = false
		BossPhase.MONSTER:
			if is_instance_valid(tentacle_model):
				tentacle_model.visible = false
			if is_instance_valid(monster_model):
				monster_model.visible = true
		BossPhase.DEFEATED:
			if is_instance_valid(tentacle_model):
				tentacle_model.visible = false
			if is_instance_valid(monster_model):
				monster_model.visible = false

func _on_party_moved(_grid_pos: Vector3i, _facing: String) -> void:
	if _combat_in_progress or current_phase == BossPhase.DEFEATED:
		return

	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("Player")
		if not is_instance_valid(_player_ref):
			# Fallback: search for DungeonPlayer by type
			_player_ref = get_parent().find_child("Player", true, false)

	if is_instance_valid(_player_ref):
		var distance: float = global_position.distance_to(_player_ref.global_position)
		if distance <= trigger_distance:
			_start_boss_combat()

func _start_boss_combat() -> void:
	_combat_in_progress = true

	var target_enemy: EnemyData = null
	if current_phase == BossPhase.TENTACLES:
		target_enemy = tentacle_enemy_data
	elif current_phase == BossPhase.MONSTER:
		target_enemy = monster_enemy_data

	if is_instance_valid(target_enemy):
		SignalBus.combat_started.emit(target_enemy, [])

func _on_combat_ended(victory: bool) -> void:
	_combat_in_progress = false

	if not victory:
		return

	# Advance to the next phase upon winning
	if current_phase == BossPhase.TENTACLES:
		current_phase = BossPhase.MONSTER
	elif current_phase == BossPhase.MONSTER:
		current_phase = BossPhase.DEFEATED

	_update_stage_visibility()