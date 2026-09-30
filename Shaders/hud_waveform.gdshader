shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.0, 1.0, 0.9, 0.8);
uniform float energy : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	
	// Create animated sine wave line centered vertically
	float wave = sin(uv.x * 15.0 + TIME * 10.0) * (0.05 + energy * 0.25);
	float distance_to_line = abs(uv.y - 0.5 - wave);
	
	// Soft glow Falloff
	float alpha = smoothstep(0.08, 0.0, distance_to_line) * line_color.a;
	
	COLOR = vec4(line_color.rgb, alpha * (0.2 + energy * 0.8));
}