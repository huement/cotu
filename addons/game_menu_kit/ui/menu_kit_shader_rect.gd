class_name MenuKitShaderRect
extends ColorRect
## Full-screen rectangle drawn by a shader (animated backgrounds, overlays).
## Keeps the shader's [code]rect_size[/code] uniform up to date.


func _init(shader: Shader = null) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if shader != null:
		var shader_material: ShaderMaterial = ShaderMaterial.new()
		shader_material.shader = shader
		material = shader_material
	resized.connect(_on_resized)


## Sets a shader uniform.
func set_param(param: StringName, value: Variant) -> void:
	var shader_material: ShaderMaterial = material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(param, value)


func _on_resized() -> void:
	set_param(&"rect_size", size)
