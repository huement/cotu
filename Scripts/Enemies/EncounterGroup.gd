# res://Scripts/Enemies/EncounterGroup.gd
class_name EncounterGroup
extends Node3D

## Pre-calculated 3x3 local offsets relative to the center of the encounter tile
const SLOT_OFFSETS: Array[Vector3] = [
	# Front Row (Slots 0, 1, 2)
	Vector3(-0.6, 0.0, 0.4),  # Front Left
	Vector3(0.0,  0.0, 0.4),  # Front Center
	Vector3(0.6,  0.0, 0.4),  # Front Right
	
	# Middle Row (Slots 3, 4, 5)
	Vector3(-0.6, 0.0, -0.2), # Middle Left
	Vector3(0.0,  0.0, -0.2), # Middle Center
	Vector3(0.6,  0.0, -0.2), # Middle Right
	
	# Back Row (Slots 6, 7, 8)
	Vector3(-0.6, 0.0, -0.8), # Back Left
	Vector3(0.0,  0.0, -0.8), # Back Center
	Vector3(0.6,  0.0, -0.8)  # Back Right
]

@export var group_data: EnemyGroupData
var active_enemies: Dictionary = {} # Maps slot_index (int) -> Node3D enemy model

func _ready() -> void:
	if group_data:
		spawn_encounter(group_data)

func spawn_encounter(data: EnemyGroupData) -> void:
	# Clear any previous combatants
	for child in get_children():
		child.queue_free()
	active_enemies.clear()

	# Spawn up to 9 enemies into their designated formation slots
	for i in range(mini(data.members.size(), 9)):
		var enemy_info: EnemyData = data.members[i]
		if enemy_info == null or enemy_info.model_scene == null:
			continue

		# Instantiate the model scene
		var enemy_instance: Node3D = enemy_info.model_scene.instantiate() as Node3D
		add_child(enemy_instance)
		
		# Set local position in the 3x3 matrix and scale down slightly for swarms
		enemy_instance.position = SLOT_OFFSETS[i]
		enemy_instance.scale = enemy_info.model_scale * 0.75 
		
		active_enemies[i] = enemy_instance

func remove_enemy_at_slot(slot_index: int) -> void:
	if active_enemies.has(slot_index):
		var enemy_node: Node3D = active_enemies[slot_index]
		active_enemies.erase(slot_index)
		enemy_node.queue_free()
