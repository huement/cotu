// res://Shaders/pixel_rain.gdshader
// Fullscreen retro pixel-art rain overlay driven by PixelRainOverlay / WeatherController.
shader_type canvas_item;

group_uniforms rain_look;
/** 0.0 = dry, 1.0 = torrential downpour. */
uniform float rain_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
/** Vertical art-pixel resolution; horizontal columns scale automatically for square pixels. */
uniform float pixel_rows : hint_range(60.0, 360.0, 1.0) = 135.0;
/** Horizontal slant per vertical pixel (- = left, + = right). Driven by camera vs. storm_front. */
uniform float wind_slant : hint_range(-1.5, 1.5, 0.01) = 0.15;
/** Base fall speed in screen-heights per second. */
uniform float fall_speed : hint_range(0.5, 8.0, 0.1) = 3.2;
uniform vec4 rain_color : source_color = vec4(0.66, 0.78, 0.90, 0.45);
/** Intensity of subtle pixel splash ticks near the lower viewport edge. */
uniform float splash_amount : hint_range(0.0, 1.0, 0.01) = 0.55;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float rain_layer(vec2 cell, float grid_h, float seed, float speed_mult, float streak_len, float density) {
	float slanted_x = cell.x + floor(cell.y * wind_slant);
	float col_hash = hash12(vec2(slanted_x, seed));
	if (col_hash > density) {
		return 0.0;
	}

	float col_speed = fall_speed * speed_mult * (0.8 + 0.4 * hash12(vec2(slanted_x, seed + 19.3)));
	float y_px = cell.y - floor(TIME * grid_h * col_speed);
	float period = streak_len * 4.5 + floor(hash12(vec2(slanted_x, seed + 7.1)) * 12.0);
	float seg_idx = floor(y_px / period);
	float local_y = mod(y_px, period);

	// Skip random segments so columns don't look like uniform dotted lines
	if (hash12(vec2(slanted_x, seg_idx + seed * 3.0)) > 0.65) {
		return 0.0;
	}

	if (local_y < streak_len) {
		// Slightly brighter leading tip at the bottom of each streak
		return (local_y >= streak_len - 1.0) ? 1.0 : 0.65;
	}
	return 0.0;
}

void fragment() {
	if (rain_amount <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.00001);
		vec2 grid_size = vec2(max(1.0, floor(pixel_rows * aspect)), pixel_rows);
		vec2 cell = floor(UV * grid_size);

		// Two parallax layers: dense distant mist-streaks + sparser close drops
		float far_drops = rain_layer(cell, grid_size.y, 11.0, 0.75, 3.0, rain_amount * 0.48) * 0.55;
		float near_drops = rain_layer(cell, grid_size.y, 37.0, 1.15, 5.0, rain_amount * 0.28);
		float intensity = max(far_drops, near_drops);

		// Sparse 1-pixel splash flickers near the lower edge of the screen
		if (splash_amount > 0.01 && UV.y > 0.84) {
			float tick = floor(TIME * 14.0);
			float h = hash12(cell + vec2(tick * 13.7, 53.0));
			float edge_weight = smoothstep(0.84, 0.99, UV.y);
			if (h < rain_amount * splash_amount * edge_weight * 0.045) {
				intensity = max(intensity, 0.75);
			}
		}

		// Quantize alpha into 4 retro steps so transparency stays crisp
		float alpha = clamp(intensity * rain_color.a * smoothstep(0.0, 0.2, rain_amount), 0.0, 1.0);
		alpha = floor(alpha * 4.0 + 0.5) / 4.0;

		COLOR = vec4(rain_color.rgb, alpha);
	}
}