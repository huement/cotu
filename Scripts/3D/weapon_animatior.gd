# res://Scripts/3D/weapon_animatior.gd
extends Node3D
class_name WeaponAnimator

signal animation_completed
signal weapon_impact

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var sword_model: Node3D = $Pivot/SwordModel
@onready var staff_model: Node3D = $Pivot/StaffModel
@onready var bow_model: Node3D = $Pivot/BowModel if has_node("Pivot/BowModel") else null
@onready var potion_model: Node3D = $Pivot/PotionModel if has_node("Pivot/PotionModel") else null
@onready var explosion_sprite: Sprite3D = $ExplosionSprite if has_node("ExplosionSprite") else null

func _ready() -> void:
	visible = false
	_hide_all_weapons()
	
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	
	if is_instance_valid(SignalBus):
		if SignalBus.has_signal(&"weapon_swing_requested"):
			SignalBus.weapon_swing_requested.connect(play_swing)

func _hide_all_weapons() -> void:
	if is_instance_valid(sword_model):
		sword_model.visible = false
	if is_instance_valid(staff_model):
		staff_model.visible = false
	if is_instance_valid(bow_model):
		bow_model.visible = false
	if is_instance_valid(potion_model):
		potion_model.visible = false
	if is_instance_valid(explosion_sprite):
		explosion_sprite.visible = false


func trigger_impact() -> void:
	weapon_impact.emit()
	if is_instance_valid(SignalBus):
		if SignalBus.has_signal(&"camera_shake_requested"):
			SignalBus.camera_shake_requested.emit(0.5)
		if SignalBus.has_signal(&"weapon_impact_occurred"):
			SignalBus.weapon_impact_occurred.emit()


func play_swing(anim_name: String = "sword_swing") -> void:
	if not is_instance_valid(animation_player):
		return

	var target_anim: String = anim_name
	if not animation_player.has_animation(target_anim):
		target_anim = "sword_swing"

	if animation_player.has_animation(target_anim):
		_hide_all_weapons()
		
		match target_anim:
			"staff_bash":
				if is_instance_valid(staff_model):
					staff_model.visible = true
			"bow_shot":
				if is_instance_valid(bow_model):
					bow_model.visible = true
			"potion_throw":
				if is_instance_valid(potion_model):
					potion_model.visible = true
			_:
				if is_instance_valid(sword_model):
					sword_model.visible = true

		visible = true
		animation_player.play(target_anim)

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	visible = false
	_hide_all_weapons()
	animation_completed.emit()
	if is_instance_valid(SignalBus):
		if SignalBus.has_signal(&"weapon_animation_finished"):
			SignalBus.weapon_animation_finished.emit()
