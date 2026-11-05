// res://Shaders/big_slash.gdshader
// One big tapered slash that draws itself across the screen, flashes, then fades.
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Direction of the cut (0 = horizontal, negative = top-left to bottom-right)
uniform float angle_degrees : hint_range(-90.0, 90.0) = -28.0;
// Thickness at the middle of the slash (fraction of screen height)
uniform float max_width : hint_range(0.01, 0.3) = 0.075;
// Length of the slash (1.0 ~= screen width)
uniform float length_ratio : hint_range(0.3, 2.0) = 1.15;
// Portion of the animation spent drawing the cut; the rest is the fade
uniform float draw_portion : hint_range(0.05, 0.9) = 0.28;
uniform vec4 core_color : source_color = vec4(1.0, 0.97, 0.93, 1.0);
uniform vec4 glow_color : source_color = vec4(0.85, 0.07, 0.04, 0.85);
// Glow width as a multiple of the core width
uniform float glow_size : hint_range(1.0, 8.0) = 3.2;
// Full-screen red flash when the cut completes
uniform float flash_strength : hint_range(0.0, 1.0) = 0.3;

float hash(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

void fragment() {
	if (progress <= 0.0 || progress >= 1.0) {
		COLOR = vec4(0.0);
	} else {
		float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x; // width / height
		vec2 p = UV - 0.5;
		p.x *= aspect;

		float a = radians(angle_degrees);
		vec2 dir = vec2(cos(a), sin(a));
		vec2 nrm = vec2(-dir.y, dir.x);

		float half_len = 0.5 * length_ratio * aspect;
		float u = dot(p, dir) / half_len; // -1 .. 1 along the slash
		float across = abs(dot(p, nrm));

		// The cut is drawn from one end to the other
		float draw_t = clamp(progress / draw_portion, 0.0, 1.0);
		float head = mix(-1.0, 1.0, draw_t);
		float drawn = smoothstep(head + 0.03, head - 0.03, u);

		// Tapered blade shape with a slightly ragged edge
		float taper = sqrt(max(0.0, 1.0 - u * u));
		float ragged = 0.82 + 0.18 * hash(floor((u + 1.0) * 45.0));
		float fade = 1.0 - smoothstep(draw_portion, 1.0, progress);
		float width = max_width * taper * ragged * mix(0.6, 1.0, fade);

		float core_mask = smoothstep(width * 0.55, width * 0.1, across);
		float glow_w = width * glow_size * (1.0 + (1.0 - fade) * 0.8);
		float glow_mask = smoothstep(glow_w, 0.0, across) * glow_color.a;

		vec3 col = mix(glow_color.rgb, core_color.rgb, core_mask);
		float alpha = max(core_mask * core_color.a, glow_mask) * drawn * fade;

		// Red flash right as the cut lands
		float flash = flash_strength * exp(-pow((progress - draw_portion) * 9.0, 2.0));
		col = mix(glow_color.rgb, col, alpha / max(alpha + flash, 0.001));
		alpha = clamp(alpha + flash, 0.0, 1.0);

		COLOR = vec4(col, alpha);
	}
}
