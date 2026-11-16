# res://Scripts/Enemies/SlimeDroneModel.gd
extends Node3D
## slime.glb's rest pose lies on its back; its one animation clip is what stands the slime up.
## So the clip must always be playing, in the world and in battle, or the two disagree
## (upright in one, tipped 90 degrees in the other). This starts it looping on spawn.


func _ready() -> void:
	var anim_player: AnimationPlayer = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not is_instance_valid(anim_player):
		return
	var clips: PackedStringArray = anim_player.get_animation_list()
	if clips.is_empty():
		return
	var clip := StringName(clips[0])
	var anim: Animation = anim_player.get_animation(clip)
	if is_instance_valid(anim):
		anim.loop_mode = Animation.LOOP_LINEAR
	anim_player.play(clip)
	# Pose the skeleton now so the first rendered frame is already upright.
	anim_player.advance(0.0)
