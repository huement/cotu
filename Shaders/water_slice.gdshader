// res://Shaders/water_slice_attack.gdshader
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float line_width : hint_range(0.01, 0.20) = 0.08;
uniform vec4 line_color : source_color = vec4(0.8, 0.95, 1.0, 1.0);
uniform vec4 water_color : source_color = vec4(0.1, 0.5, 0.9, 0.85);

// Bubble parameters
uniform float bubble_density : hint_range(5.0, 50.0) = 25.0;
uniform float bubble_speed : hint_range(0.5, 5.0) = 2.0;

// Simple pseudo-random generator
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	if (progress <= 0.0 || progress >= 1.0) {
		COLOR = vec4(0.0);
	} else {
		// Diagonal wave slice across screen coordinates (top-left to bottom-right)
		float base_diag = (UV.x - UV.y);
		
		// Add water distortion (sine wave wobble along the slice line)
		float water_wobble = sin(UV.x * 20.0 + TIME * 8.0) * 0.02;
		float diag = base_diag + water_wobble;
		
		float center = (progress - 0.5) * 3.0;
		float dist = abs(diag - center);
		
		if (dist < line_width) {
			float norm_dist = dist / line_width;
			float alpha = 1.0 - norm_dist;
			float fade = sin(progress * 3.14159);
			
			// Procedural Bubble Generation along the cut
			vec2 bubble_uv = UV * bubble_density;
			bubble_uv.y -= TIME * bubble_speed;
			vec2 id = floor(bubble_uv);
			vec2 g_uv = fract(bubble_uv) - 0.5;
			
			float rnd = hash(id);
			float bubble_mask = 0.0;
			if (rnd > 0.65) {
				float radius = 0.15 + 0.1 * sin(TIME * 5.0 + rnd * 6.28);
				float d = length(g_uv);
				bubble_mask = smoothstep(radius, radius - 0.05, d) * smoothstep(0.0, 0.1, d);
			}
			
			// Mix water core color with bright edge line and bubble highlights
			vec4 core_color = mix(line_color, water_color, norm_dist);
			core_color.rgb += vec3(bubble_mask * 0.9);
			
			COLOR = vec4(core_color.rgb, core_color.a * alpha * fade);
		} else {
			COLOR = vec4(0.0);
		}
	}
}