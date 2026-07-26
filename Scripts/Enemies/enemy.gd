# res://scenes/enemies/enemy.gd
extends Node3D

@export var data: EnemyData
@export var initial_cell: Vector2i = Vector2i(2, 0)
@export var initial_facing: int = 3

@onready var model_holder: Node3D = $ModelHolder
@onready var enemy_ai: Node = $EnemyAI

var current_health: int = 0
var anim_player: AnimationPlayer = null

func _ready() -> void:
	if data:
		_initialize_enemy(data)

func _initialize_enemy(enemy_data: EnemyData) -> void:
	current_health = enemy_data.max_health
	
	# Instantiate the 3D model from our Resource
	if enemy_data.model_scene:
		var model_instance: Node3D = enemy_data.model_scene.instantiate() as Node3D
		model_holder.add_child(model_instance)
		
		# Apply the scale from EnemyData
		model_holder.scale = enemy_data.model_scale
		
		# Find the built-in AnimationPlayer inside Kenney's .glb file
		anim_player = _find_animation_player(model_instance)
		
		# Start playing the built-in idle loop
		play_animation("idle")

func play_animation(anim_name: String) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	
	if current_health <= 0:
		play_animation("die")
		# Emit signal to global bus for phased combat resolution
		SignalBus.enemy_damaged.emit(get_instance_id(), amount)
	else:
		# Play a quick hit reaction or flash effect
		SignalBus.enemy_damaged.emit(get_instance_id(), amount)

# Helper function to locate the AnimationPlayer in imported GLTF scenes
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found:
			return found
			
	return null
