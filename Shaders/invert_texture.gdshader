shader_type canvas_item;

/// Inverts RGB while preserving sampled alpha (horror double-vision flashes).
void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	COLOR = vec4(1.0 - tex_color.rgb, tex_color.a) * COLOR;
}
