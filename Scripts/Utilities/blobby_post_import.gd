# res://Scripts/Utilities/blobby_post_import.gd
@tool
extends EditorScenePostImport

## blobby.glb is authored Z-up. Rotate the imported root +90 X so Godot Y-up
## instances stand correctly without per-level rotation.
func _post_import(scene: Node) -> Object:
	if scene is Node3D:
		var root: Node3D = scene as Node3D
		root.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	return scene
