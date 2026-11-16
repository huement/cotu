# res://Scripts/3D/model_animation_importer.gd
@tool
extends EditorScenePostImport

## Map raw GLB animation names to standardized game animation names
const ANIMATION_MAP: Dictionary = {
	"Armature|idle": "IDLE",
	"Armature|Walk": "WALK",
	"Armature|Attack": "ATTACK_1",
	"Armature|Attack Double": "ATTACK_SPECIAL",
	"Armature|Death": "DEATH",
	"Armature|Jump": "ATTACK_JUMP"
}

func _post_import(scene: Node) -> Object:
	var anim_player: AnimationPlayer = _find_animation_player(scene)
	if anim_player:
		var libraries: Array[StringName] = anim_player.get_animation_library_list()
		for lib_name in libraries:
			var library: AnimationLibrary = anim_player.get_animation_library(lib_name)
			if not library:
				continue
			
			for old_name in ANIMATION_MAP.keys():
				if library.has_animation(old_name):
					var new_name: String = ANIMATION_MAP[old_name]
					var anim: Animation = library.get_animation(old_name)
					
					# Enable looping for IDLE and WALK
					if new_name in ["IDLE", "WALK"]:
						anim.loop_mode = Animation.LOOP_LINEAR
					
					library.add_animation(new_name, anim)
					library.remove_animation(old_name)
	return scene

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found:
			return found
	return null
