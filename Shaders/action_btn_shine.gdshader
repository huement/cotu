shader_type canvas_item;

// Sweep Progress (-0.5 to 1.5 - driven by GDScript Tween on hover)
uniform float shine_progress : hint_range(-0.5, 1.5) = -0.5;
uniform float shine_size : hint_range(0.01, 0.5) = 0.18;
uniform float shine_angle : hint_range(0.0, 3.14159) = 0.85; // ~50 degree angle

// Soft Highlight Controls
uniform vec4 shine_color : source_color = vec4(0.12, 0.95, 0.98, 0.5); // Soft Cyan
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.35; // Gentle additive brightness

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	if (tex_color.a < 0.01) {
		discard;
	}

	// Calculate angled UV projection
	vec2 angled_uv = vec2(
		cos(shine_angle) * UV.x - sin(shine_angle) * UV.y,
		sin(shine_angle) * UV.x + cos(shine_angle) * UV.y
	);

	float pos = angled_uv.x;
	float line_start = shine_progress - (shine_size * 0.5);
	float line_end = shine_progress + (shine_size * 0.5);

	// Soft, smooth single-band sweep
	float main_band = smoothstep(line_start, shine_progress, pos) - smoothstep(shine_progress, line_end, pos);

	// Gentle additive highlight blend onto underlying texture
	vec3 final_rgb = tex_color.rgb + (shine_color.rgb * main_band * highlight_strength * tex_color.a);

	COLOR = vec4(final_rgb, tex_color.a);
}