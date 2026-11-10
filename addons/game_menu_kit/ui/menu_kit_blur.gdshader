shader_type canvas_item;
// Blurred and darkened copy of the screen, behind the pause menu.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec4 tint : source_color = vec4(0.02, 0.01, 0.05, 0.7);
// Blur radius in pixels at 720p.
uniform float radius = 7.0;
// 0 = clear game view, 1 = full effect (animated when the menu opens).
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float r_px = radius * amount / (SCREEN_PIXEL_SIZE.y * 720.0);
	vec3 sum = vec3(0.0);
	float total = 0.0;
	for (int i = 0; i < 24; i++) {
		float t = (float(i) + 0.5) / 24.0;
		float a = float(i) * 2.39996;
		vec2 offset = vec2(cos(a), sin(a)) * sqrt(t) * r_px * SCREEN_PIXEL_SIZE;
		float w = 1.0 - t * 0.6;
		sum += texture(screen_texture, SCREEN_UV + offset).rgb * w;
		total += w;
	}
	vec3 color = sum / total;
	COLOR = vec4(mix(color, tint.rgb, tint.a * amount), 1.0);
}
