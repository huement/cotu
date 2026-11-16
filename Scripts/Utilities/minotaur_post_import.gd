# res://Scripts/3D/minotaur_post_import.gd
@tool
extends EditorScenePostImport

const MAPPING: Dictionary = {
	"Armature|idle": "IDLE",
	"Armature|Walk": "WALK",
	"Armature|Attack": "ATTACK_1",
	"Armature|Attack Double": "ATTACK_SPECIAL",
	"Armature|Death": "DEATH",
	"Armature|Jump": "ATTACK_JUMP"
}

func _post_import(scene: Node) -> Object:
	var anim_player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		for old_name in MAPPING.keys():
			if anim_player.has_animation(old_name):
				var anim: Animation = anim_player.get_animation(old_name)
				var library: AnimationLibrary = anim_player.get_animation_library("")
				if library:
					library.add_animation(MAPPING[old_name], anim)
					library.remove_animation(old_name)
	return scene
