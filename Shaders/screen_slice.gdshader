shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float line_width : hint_range(0.01, 0.15) = 0.04;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.2, 0.8, 1.0, 0.8);

void fragment() {
	if (progress <= 0.0 || progress >= 1.0) {
		COLOR = vec4(0.0);
	} else {
		// Diagonal line across screen coordinates (top-left to bottom-right)
		float diag = (UV.x - UV.y);
		float center = (progress - 0.5) * 3.0;
		float dist = abs(diag - center);
		
		if (dist < line_width) {
			float alpha = 1.0 - (dist / line_width);
			float fade = sin(progress * 3.14159);
			vec4 final_color = mix(glow_color, line_color, alpha * alpha);
			COLOR = vec4(final_color.rgb, final_color.a * alpha * fade);
		} else {
			COLOR = vec4(0.0);
		}
	}
}