// Neon style overlay: thin scanlines and a dark vignette.
shader_type canvas_item;

uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float line_alpha = 0.04;
uniform float vignette = 0.6;

void fragment() {
	vec2 px = UV * rect_size;
	float period = 3.0 * max(1.0, floor(rect_size.y / 720.0));
	float line = mod(px.y, period) < period / 3.0 ? line_alpha : 0.0;
	float r = length((UV - 0.5) * 2.0) / sqrt(2.0);
	float v = clamp((r - 0.55) / 0.45, 0.0, 1.0) * vignette;
	float alpha = 1.0 - (1.0 - line) * (1.0 - v);
	COLOR = vec4(vec3(alpha > 0.0 ? line * (1.0 - v) / alpha : 0.0), alpha);
}
