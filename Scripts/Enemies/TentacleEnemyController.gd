# res://Scripts/Enemies/TentacleEnemyController.gd
class_name TentacleEnemyController
extends Node3D

## Aliased to 'data' for full compatibility with WorldEncounterModule and CombatManager
@export var data: EnemyData:
	get:
		return _enemy_data
	set(val):
		_enemy_data = val
		if _enemy_data:
			current_health = _enemy_data.max_health

## Kept for Inspector backward compatibility
@export var enemy_data: EnemyData:
	get:
		return _enemy_data
	set(val):
		_enemy_data = val
		if _enemy_data:
			current_health = _enemy_data.max_health

var _enemy_data: EnemyData
var current_health: int = 60

@onready var visual_juice: Node3D = $VisualJuice
@onready var model_instance: Node3D = $VisualJuice/ModelInstance

var _anim_player: AnimationPlayer

func _ready() -> void:
	if _enemy_data:
		current_health = _enemy_data.max_health
	_setup_animation_player()
	play_idle()

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
	if _anim_player and _anim_player.has_animation("idle"):
		var anim: Animation = _anim_player.get_animation("idle")
		anim.loop_mode = Animation.LOOP_LINEAR
		_anim_player.play("idle")

func play_attack() -> void:
	if _anim_player and _anim_player.has_animation("attack"):
		_anim_player.play("attack")
		if not _anim_player.animation_finished.is_connected(_on_animation_finished):
			_anim_player.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)

func _on_animation_finished(_anim_name: StringName) -> void:
	play_idle()

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
