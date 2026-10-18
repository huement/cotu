# res://Scripts/3D/WaterBossEncounter.gd
class_name WaterBossEncounter
extends Node3D

enum EncounterPhase { PHASE_1_TENTACLES, PHASE_2_LAKE_MONSTER, DEFEATED }

@export var trigger_area: Area3D
@export var tentacles_node: Node3D
@export var monster_node: Node3D

@export var phase_1_group: EnemyGroupData
@export var phase_2_group: EnemyGroupData

var current_phase: EncounterPhase = EncounterPhase.PHASE_1_TENTACLES

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)
	
	_update_visuals()

func _update_visuals() -> void:
	match current_phase:
		EncounterPhase.PHASE_1_TENTACLES:
			if tentacles_node: tentacles_node.visible = true
			if monster_node: monster_node.visible = false
		EncounterPhase.PHASE_2_LAKE_MONSTER:
			if tentacles_node: tentacles_node.visible = false
			if monster_node: monster_node.visible = true
		EncounterPhase.DEFEATED:
			if tentacles_node: tentacles_node.visible = false
			if monster_node: monster_node.visible = false

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("Player"):
		return
		
	match current_phase:
		EncounterPhase.PHASE_1_TENTACLES:
			if phase_1_group:
				_start_boss_battle(phase_1_group)
		EncounterPhase.PHASE_2_LAKE_MONSTER:
			if phase_2_group:
				_start_boss_battle(phase_2_group)

func _start_boss_battle(group_data: EnemyGroupData) -> void:
	# Signal CombatManager to initiate battle with this group
	SignalBus.battle_initiated.emit(group_data)

func on_boss_defeated() -> void:
	if current_phase == EncounterPhase.PHASE_1_TENTACLES:
		current_phase = EncounterPhase.PHASE_2_LAKE_MONSTER
	elif current_phase == EncounterPhase.PHASE_2_LAKE_MONSTER:
		current_phase = EncounterPhase.DEFEATED
	
	_update_visuals()