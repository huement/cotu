# res://Scripts/3D/WaterBossJuice.gd
class_name BossVisualJuice
extends Node3D

@export var shake_intensity: float = 0.25
@export var shake_duration: float = 0.4
@export var sink_speed: float = 1.5
@export var sink_depth: float = 3.0

var _is_shaking: bool = false
var _shake_timer: float = 0.0
var _is_sinking: bool = false
var _initial_position: Vector3
var _target_sink_y: float = 0.0

func _ready() -> void:
	_initial_position = position

func _process(delta: float) -> void:
	if _is_shaking:
		_shake_timer -= delta
		if _shake_timer <= 0.0:
			_is_shaking = false
			position = _initial_position
		else:
			var offset_x: float = randf_range(-shake_intensity, shake_intensity)
			var offset_z: float = randf_range(-shake_intensity, shake_intensity)
			position = _initial_position + Vector3(offset_x, 0.0, offset_z)
			
	if _is_sinking:
		position.y = move_toward(position.y, _target_sink_y, sink_speed * delta)
		if is_equal_approx(position.y, _target_sink_y):
			_is_sinking = false
			visible = false

## Call this method when the boss takes damage
func play_hit_shake() -> void:
	_is_shaking = true
	_shake_timer = shake_duration

## Call this method when the boss is defeated
func play_death_sink() -> void:
	_is_shaking = false
	_is_sinking = true
	_target_sink_y = _initial_position.y - sink_depth