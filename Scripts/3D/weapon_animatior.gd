extends Node3D
class_name WeaponAnimator

signal animation_completed

@onready var animation_player: AnimationPlayer = %AnimationPlayer

func _ready() -> void:
	visible = false
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	
	if is_instance_valid(SignalBus):
		SignalBus.weapon_swing_requested.connect(play_swing)
		
func play_swing() -> void:
	visible = true
	animation_player.play("sword_swing")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"sword_swing":
		visible = false
		animation_completed.emit()
