shader_type canvas_item;

uniform float shine_progress : hint_range(-0.5, 1.5) = -0.5;
uniform float shine_size : hint_range(0.01, 0.8) = 0.25;
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 0.8, 0.6);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Diagonal sweep position across UV coordinates
	float pos = (UV.x + UV.y) * 0.5;
	float line_start = shine_progress - (shine_size * 0.5);
	float line_end = shine_progress + (shine_size * 0.5);

	// Calculate smooth band intensity
	float alpha = smoothstep(line_start, shine_progress, pos) - smoothstep(shine_progress, line_end, pos);

	// Blend shine color with underlying texture opacity
	vec3 final_rgb = tex_color.rgb + (shine_color.rgb * alpha * shine_color.a * tex_color.a);
	COLOR = vec4(final_rgb, tex_color.a);
}
