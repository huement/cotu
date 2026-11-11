# res://Scripts/3D/ThrowAnimator.gd
extends Node3D
class_name ThrowAnimator
## First-person throw animations (throwing knives, throwing stars, big special potions).
## Sits next to WeaponAnimator under the player camera. Basic flask attacks stay in WeaponAnimator.
##
## Play one with SignalBus.throw_requested.emit("knife_throw"), or ThrowAnimator.ANIMS has every clip.
## Each clip shows the model listed in CLIP_MODELS. In a clip, key a Call Method track on "." ->
## trigger_impact at the moment the throw lands (damage numbers and camera shake hook onto it).
##
## To add a new throw: add a model under Pivot, add the clip to the AnimationPlayer, add it to CLIP_MODELS.

signal animation_completed
signal throw_impact

## Clip name -> node under Pivot that is shown while it plays.
const CLIP_MODELS: Dictionary = {
	"big_potion_throw": "BigPotionModel",
	"knife_throw": "KnifeModel",
	"star_throw": "StarModel",
}

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var pivot: Node3D = $Pivot
@onready var explosion_sprite: Sprite3D = $ExplosionSprite if has_node("ExplosionSprite") else null


static func has_clip(anim_name: String) -> bool:
	return CLIP_MODELS.has(anim_name)


func _ready() -> void:
	visible = false
	_hide_all_models()
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
	if is_instance_valid(SignalBus) and SignalBus.has_signal(&"throw_requested"):
		SignalBus.throw_requested.connect(play_throw)


func _hide_all_models() -> void:
	for model_name: String in CLIP_MODELS.values():
		var model: Node3D = pivot.get_node_or_null(model_name) as Node3D
		if is_instance_valid(model):
			model.visible = false
	if is_instance_valid(explosion_sprite):
		explosion_sprite.visible = false


func play_throw(anim_name: String) -> void:
	if not is_instance_valid(animation_player) or not animation_player.has_animation(anim_name):
		push_warning("ThrowAnimator: no clip '%s'" % anim_name)
		return
	_hide_all_models()
	var model: Node3D = pivot.get_node_or_null(str(CLIP_MODELS.get(anim_name, ""))) as Node3D
	if is_instance_valid(model):
		model.visible = true
	visible = true
	animation_player.play(anim_name)


## Called from each clip's method track when the throw lands.
func trigger_impact() -> void:
	throw_impact.emit()
	if is_instance_valid(SignalBus):
		if SignalBus.has_signal(&"camera_shake_requested"):
			SignalBus.camera_shake_requested.emit(0.5)
		if SignalBus.has_signal(&"weapon_impact_occurred"):
			SignalBus.weapon_impact_occurred.emit()


func _on_animation_finished(_anim_name: StringName) -> void:
	visible = false
	_hide_all_models()
	animation_completed.emit()
	if is_instance_valid(SignalBus) and SignalBus.has_signal(&"throw_animation_finished"):
		SignalBus.throw_animation_finished.emit()
