shader_type canvas_item;

uniform float shine_progress : hint_range(-0.5, 1.5) = -0.5;
uniform float shine_size : hint_range(0.01, 0.8) = 0.25;
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 0.8, 0.6);
// Identity by default so a single texture sweeps as before. Sliced buttons
// remap each piece into the full control so one band crosses the whole button.
uniform vec2 shine_uv_scale = vec2(1.0, 1.0);
uniform vec2 shine_uv_offset = vec2(0.0, 0.0);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	vec2 sweep_uv = UV * shine_uv_scale + shine_uv_offset;
	float pos = (sweep_uv.x + sweep_uv.y) * 0.5;
	float line_start = shine_progress - (shine_size * 0.5);
	float line_end = shine_progress + (shine_size * 0.5);

	// Calculate smooth band intensity
	float alpha = smoothstep(line_start, shine_progress, pos) - smoothstep(shine_progress, line_end, pos);

	// Blend shine color with underlying texture opacity
	vec3 final_rgb = tex_color.rgb + (shine_color.rgb * alpha * shine_color.a * tex_color.a);
	COLOR = vec4(final_rgb, tex_color.a);
}
