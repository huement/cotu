shader_type canvas_item;

uniform float scanline_count : hint_range(0.0, 800.0) = 160.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float scan_speed : hint_range(0.0, 10.0) = 1.5;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.3;

void fragment() {
	vec2 c_uv = UV;
	vec4 col = texture(TEXTURE, c_uv);
	
	// Animated scrolling scanlines using built-in TIME
	float scanline = sin((c_uv.y - TIME * scan_speed * 0.05) * scanline_count * 3.14159 * 2.0);
	scanline = (scanline + 1.0) * 0.5;
	col.rgb -= scanline * scanline_intensity * col.rgb;
	
	// Flat corner vignette
	float vignette = c_uv.x * c_uv.y * (1.0 - c_uv.x) * (1.0 - c_uv.y);
	vignette = clamp(pow(16.0 * vignette, vignette_intensity), 0.0, 1.0);
	col.rgb *= vignette;
	
	COLOR = col;
}