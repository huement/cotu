// Neon style background: retro sky, twinkling stars, striped sun and a grid
// scrolling towards the player.
shader_type canvas_item;

uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec4 grid_color : source_color = vec4(0.208, 0.941, 1.0, 1.0);
uniform vec4 horizon_color : source_color = vec4(1.0, 0.247, 0.706, 1.0);
uniform vec4 sky_top : source_color = vec4(0.016, 0.008, 0.043, 1.0);
uniform vec4 sky_middle : source_color = vec4(0.086, 0.024, 0.173, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.227, 0.043, 0.31, 1.0);
uniform vec4 floor_color : source_color = vec4(0.027, 0.012, 0.059, 1.0);
uniform vec4 sun_top : source_color = vec4(1.0, 0.878, 0.478, 1.0);
uniform vec4 sun_middle : source_color = vec4(1.0, 0.478, 0.42, 1.0);
uniform vec4 sun_bottom : source_color = vec4(1.0, 0.247, 0.706, 1.0);
uniform float horizon = 0.6;
uniform float sun_x = 0.74;
uniform float sun_radius = 0.23;
uniform float speed = 0.45;
uniform float star_density = 0.065;
uniform bool show_sun = true;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float line_mask(float distance_px, float half_width) {
	return 1.0 - smoothstep(half_width, half_width + 1.0, distance_px);
}

void fragment() {
	vec2 px = UV * rect_size;
	float w = rect_size.x;
	float h = rect_size.y;
	float hz = h * horizon;
	float lw = max(1.0, h / 540.0);
	vec3 col;
	if (px.y < hz) {
		float k = px.y / hz;
		col = k < 0.7 ? mix(sky_top.rgb, sky_middle.rgb, k / 0.7) : mix(sky_middle.rgb, sky_bottom.rgb, (k - 0.7) / 0.3);
		// Stars (upper part of the sky only).
		float cell = h / 38.0;
		vec2 c = floor(px / cell);
		if (hash(c) < star_density && px.y < h * 0.55) {
			vec2 star = (c + vec2(hash(c + 1.3), hash(c + 7.1))) * cell;
			float star_size = (hash(c + 3.7) * 1.4 + 0.4) * h / 700.0;
			float d = max(abs(px.x - star.x), abs(px.y - star.y));
			float twinkle = 0.25 + 0.75 * abs(sin(TIME * (0.5 + hash(c + 5.0) * 2.0) + hash(c + 9.0) * 6.283));
			col = mix(col, vec3(0.81, 0.94, 1.0), twinkle * line_mask(d, star_size * 0.5));
		}
		// Striped sun sitting on the horizon.
		if (show_sun) {
			float sr = h * sun_radius;
			float top = hz - sr;
			if (px.y >= top) {
				float kk = (px.y - top) / sr;
				float band = sr * 0.09;
				float gap = kk < 0.4 ? 0.0 : sr * 0.05 * (kk - 0.4) * 2.2;
				float stripe = 1.0 - smoothstep(band - gap - 0.5, band - gap + 0.5, mod(px.y - top, band));
				float inside = 1.0 - smoothstep(sr - 1.0, sr + 0.5, distance(px, vec2(w * sun_x, hz)));
				vec3 sun = kk < 0.55 ? mix(sun_top.rgb, sun_middle.rgb, kk / 0.55) : mix(sun_middle.rgb, sun_bottom.rgb, (kk - 0.55) / 0.45);
				col = mix(col, sun, inside * stripe);
			}
		}
		// Pink haze above the horizon.
		float haze = clamp((px.y - (hz - h * 0.12)) / (h * 0.14), 0.0, 1.0);
		col = mix(col, horizon_color.rgb, haze * 0.35);
	} else {
		col = floor_color.rgb;
		float s = (px.y - hz) / (h - hz);
		// Lines going to the vanishing point.
		float spacing = w * (0.012 + 0.118 * s);
		float fi = (px.x - w * 0.5) / spacing;
		float ni = floor(fi + 0.5);
		float slope = ni * w * 0.118 / (h - hz);
		float dx = abs(fi - ni) * spacing / sqrt(1.0 + slope * slope);
		float columns = step(abs(ni), 18.0);
		// Horizontal lines moving towards the player.
		float d = (1.0 / max(s, 0.0001) - 1.0) / 0.55;
		float fd = d + fract(TIME * speed);
		float nd = floor(fd + 0.5);
		float dy = abs(fd - nd) * (h - hz) * 0.55 / pow(1.0 + 0.55 * d, 2.0);
		float rows = (nd >= 1.0 && nd <= 26.0) ? 1.0 : 0.0;
		float core = max(line_mask(dx, lw * 0.5) * columns, line_mask(dy, lw * 0.5) * rows);
		float glow = max(line_mask(dx, lw * 2.5) * columns, line_mask(dy, lw * 2.5) * rows);
		col = mix(col, grid_color.rgb, glow * 0.18);
		col = mix(col, grid_color.rgb, core * 0.85);
		col = mix(col, floor_color.rgb, 1.0 - clamp(s / 0.45, 0.0, 1.0));
	}
	col = mix(col, horizon_color.rgb, 0.9 * line_mask(abs(px.y - (hz - lw * 0.25)), lw * 0.75));
	COLOR = vec4(col, 1.0);
}
