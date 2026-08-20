# res://Scripts/Utilities/TextureMaterialGenerator.gd
@tool
extends EditorScript

const KENNY_DIR: String = "res://resources/Enemies/Kenny/"


func _run() -> void:
	generate_all_materials()


func generate_all_materials() -> void:
	var count: int = 0
	var letters: Array[String] = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r"]

	for letter in letters:
		var png_path: String = KENNY_DIR + "texture-" + letter + ".png"
		var tres_path: String = KENNY_DIR + "texture-" + letter + ".tres"

		if not FileAccess.file_exists(png_path):
			continue

		var tex := load(png_path) as Texture2D
		if tex == null:
			continue

		var mat := StandardMaterial3D.new()
		mat.resource_name = "texture-" + letter
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

		var err := ResourceSaver.save(mat, tres_path)
		if err == OK:
			count += 1
		else:
			printerr("TextureMaterialGenerator Error saving %s: %d" % [tres_path, err])

	print("TextureMaterialGenerator: Successfully generated %d texture-*.tres files." % count)
