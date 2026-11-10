// res://Shaders/space_pixel.gdshader
// Pixel-art "drifting through space": warm nebula + parallax star layers + big glowing stars.
// Use on a full-screen ColorRect (see Scenes/UI/SpaceBackground.tscn / Scripts/UI/SpaceBackground.gd).
// Inspired by godotshaders.com "2D Nebula" (CC0) and "Star Nest" (MIT, Pablo Andrioli) - no code copied.
//
// Everything is computed on a grid of `pixel_size` screen pixels, so stars move one chunky pixel at a time.
// `calm` (0..1) is the one knob for "make it quiet enough to put text over it".
shader_type canvas_item;
render_mode unshaded;

group_uniforms Pixels;
/** Size of one art pixel in screen pixels. */
uniform float pixel_size : hint_range(1.0, 12.0, 1.0) = 3.0;
/** Brightness levels per colour (lower = more retro banding). 0 = off. */
uniform float color_steps : hint_range(0.0, 32.0, 1.0) = 10.0;
/** Ordered dither between bands (0 = flat bands). */
uniform float dither : hint_range(0.0, 1.0) = 0.45;

group_uniforms Motion;
/** Camera drift in art pixels per second (x right, y down). Near layers move faster. */
uniform vec2 drift = vec2(2.2, -0.9);
/** How fast the nebula itself churns. */
uniform float nebula_evolve : hint_range(0.0, 0.2) = 0.015;
/** Star twinkle speed. */
uniform float twinkle_speed : hint_range(0.0, 8.0) = 1.6;
/** Extra seed so different screens can look different. */
uniform float seed : hint_range(0.0, 100.0) = 7.0;

group_uniforms Palette;
uniform vec4 space_color : source_color = vec4(0.055, 0.012, 0.012, 1.0);
uniform vec4 nebula_dark : source_color = vec4(0.12, 0.03, 0.022, 1.0);
uniform vec4 nebula_mid : source_color = vec4(0.25, 0.075, 0.04, 1.0);
uniform vec4 nebula_bright : source_color = vec4(0.42, 0.16, 0.07, 1.0);
uniform vec4 star_cool : source_color = vec4(1.0, 0.33, 0.16, 1.0);
uniform vec4 star_warm : source_color = vec4(1.0, 0.62, 0.30, 1.0);
uniform vec4 star_hot : source_color = vec4(1.0, 0.95, 0.82, 1.0);

group_uniforms Nebula;
/** Overall nebula strength. */
uniform float nebula_intensity : hint_range(0.0, 2.0) = 0.85;
/** Bigger = larger cloud shapes. */
uniform float nebula_scale : hint_range(0.2, 6.0) = 1.0;
/** How much of the screen is cloud (0 = wisps only, 1 = everywhere). */
uniform float nebula_coverage : hint_range(0.0, 1.0) = 0.6;
/** Small-scale mottling (the grainy clumps between clouds). */
uniform float nebula_grain : hint_range(0.0, 1.0) = 0.45;
/** Twisty filament structure. */
uniform float nebula_warp : hint_range(0.0, 3.0) = 1.4;
/** Dark dust lanes cutting through the clouds. */
uniform float dust_lanes : hint_range(0.0, 1.0) = 0.55;

group_uniforms Stars;
/** Chance per cell of a far (1px, dim) star. */
uniform float far_star_density : hint_range(0.0, 1.0) = 0.55;
/** Chance per cell of a mid star. */
uniform float mid_star_density : hint_range(0.0, 1.0) = 0.35;
/** Chance per cell of a near star (brighter, + shaped). */
uniform float near_star_density : hint_range(0.0, 1.0) = 0.25;
/** Chance per (big) cell of a glowing giant star. */
uniform float giant_star_density : hint_range(0.0, 1.0) = 0.35;
/** Glow radius of giant stars in art pixels. */
uniform float giant_glow : hint_range(1.0, 16.0) = 6.0;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;

group_uniforms Calm;
/** 0 = full scene, 1 = quiet backdrop for text (fewer stars, faint nebula, no twinkle). */
uniform float calm : hint_range(0.0, 1.0) = 0.0;
/** Darkened area for a window: x, y, width, height in 0..1 of the screen. */
uniform vec4 focus_rect = vec4(0.5, 0.5, 0.0, 0.0);
/** How dark the focus area gets (0 = off). */
uniform float focus_dim : hint_range(0.0, 1.0) = 0.0;
/** Soft edge of the focus area (0..1 of screen height). */
uniform float focus_softness : hint_range(0.0, 0.5) = 0.12;
/** Darken the screen edges. */
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

// ------------------------------------------------------------------------------
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = rot * p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v;
}

float bayer4(vec2 cell) {
	int x = int(mod(cell.x, 4.0));
	int y = int(mod(cell.y, 4.0));
	int idx = x + y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[idx]) + 0.5) / 16.0;
}

float quantize(float v, vec2 cell) {
	if (color_steps < 1.0) {
		return v;
	}
	float d = (bayer4(cell) - 0.5) * dither;
	return clamp(floor(v * color_steps + 0.5 + d) / color_steps, 0.0, 1.0);
}

vec3 star_tint(float h) {
	if (h < 0.45) {
		return star_cool.rgb;
	}
	if (h < 0.85) {
		return star_warm.rgb;
	}
	return star_hot.rgb;
}

// One layer of single-pixel stars. q = art-pixel coords (already drifted for this layer).
// Returns rgb (0 when no star here).
vec3 pixel_stars(vec2 q, float cell_px, float density, float layer_seed, float bright, bool plus_shape) {
	vec3 col = vec3(0.0);
	vec2 cell = floor(q / cell_px);
	for (int oy = -1; oy <= 1; oy++) {
		for (int ox = -1; ox <= 1; ox++) {
			if (!plus_shape && (ox != 0 || oy != 0)) {
				continue;
			}
			vec2 c = cell + vec2(float(ox), float(oy));
			float h = hash12(c + layer_seed);
			if (h > density) {
				continue;
			}
			vec2 star_px = c * cell_px + floor(hash22(c + layer_seed * 1.7) * (cell_px - 2.0)) + 1.0;
			vec2 d = abs(floor(q) - star_px);
			float tw = 1.0 - (1.0 - calm) * 0.45 * (0.5 + 0.5 * sin(TIME * twinkle_speed * (0.6 + h * 2.5) + h * 40.0));
			float k = 0.0;
			if (d.x + d.y < 0.5) {
				k = 1.0;
			} else if (plus_shape && d.x + d.y < 1.5) {
				k = 0.35;
			}
			float b = bright * (0.55 + 0.45 * hash12(c * 3.1 + layer_seed)) * tw;
			col = max(col, star_tint(hash12(c + layer_seed + 5.0)) * k * b);
		}
	}
	return col;
}

// Big stars with a blocky glow halo (a few per screen).
vec3 giant_stars(vec2 q, float cell_px, float density, float layer_seed) {
	vec3 col = vec3(0.0);
	vec2 cell = floor(q / cell_px);
	for (int oy = -1; oy <= 1; oy++) {
		for (int ox = -1; ox <= 1; ox++) {
			vec2 c = cell + vec2(float(ox), float(oy));
			float h = hash12(c + layer_seed);
			if (h > density) {
				continue;
			}
			vec2 star_px = c * cell_px + floor(hash22(c + layer_seed) * (cell_px - 8.0)) + 4.0;
			vec2 d = floor(q) - star_px;
			float r2 = dot(d, d);
			float size = giant_glow * (0.5 + hash12(c * 7.7 + layer_seed));
			float pulse = 1.0 - (1.0 - calm) * 0.2 * (0.5 + 0.5 * sin(TIME * twinkle_speed * 0.7 + h * 31.0));
			float glow = exp(-r2 / (size * size)) * 0.75 * pulse;
			float core = r2 < 0.5 ? 1.0 : (r2 < 1.5 ? 0.75 : (r2 < 2.5 ? 0.45 : 0.0));
			vec3 tint = star_tint(0.4 + 0.6 * hash12(c + layer_seed + 2.0));
			col = max(col, tint * glow + star_hot.rgb * core * pulse);
		}
	}
	return col;
}

void fragment() {
	vec2 screen_px = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / pixel_size); // art pixel
	vec2 art_res = screen_px / pixel_size;

	float quiet = 1.0 - calm;
	vec2 cam = drift * TIME;

	// ---- Nebula (slowest parallax) ----
	vec2 np = (cell + cam * 0.25) / (art_res.y * 0.5 * nebula_scale) + seed;
	float t = TIME * nebula_evolve;
	vec2 warp = vec2(fbm(np * 1.3 + vec2(t, -t)), fbm(np * 1.3 + vec2(5.2 - t, 1.3 + t)));
	float n = fbm(np * 2.0 + warp * nebula_warp);
	float ridge = 1.0 - abs(2.0 * fbm(np * 3.1 - warp * 0.8 + 11.0) - 1.0);
	float cover = smoothstep(1.0 - nebula_coverage - 0.15, 1.0 - nebula_coverage + 0.45, n);
	float neb = cover * (0.65 + 0.55 * ridge * ridge);
	float dust = smoothstep(0.45, 0.75, fbm(np * 4.0 + warp * 2.0 + 31.0));
	neb *= 1.0 - dust_lanes * dust;
	float grain = vnoise((cell + cam * 0.25) * 0.3 + seed * 13.0) * 0.6 + vnoise((cell + cam * 0.25) * 0.11 + 3.0) * 0.4;
	neb *= mix(1.0, 0.45 + grain * 1.1, nebula_grain);
	neb += nebula_grain * 0.12 * smoothstep(0.55, 0.9, grain) * (1.0 - cover);
	neb *= nebula_intensity * mix(0.35, 1.0, quiet);
	neb = quantize(clamp(neb, 0.0, 1.0), cell);

	vec3 col = space_color.rgb;
	col = mix(col, nebula_dark.rgb, smoothstep(0.0, 0.35, neb));
	col = mix(col, nebula_mid.rgb, smoothstep(0.3, 0.7, neb));
	col = mix(col, nebula_bright.rgb, smoothstep(0.65, 1.0, neb));

	// ---- Stars (three parallax layers + giants) ----
	float density_scale = mix(0.25, 1.0, quiet);
	vec3 stars = vec3(0.0);
	stars = max(stars, pixel_stars(cell + cam * 0.35, 9.0, far_star_density * density_scale, seed + 1.0, 0.45, false));
	stars = max(stars, pixel_stars(cell + cam * 0.6, 17.0, mid_star_density * density_scale, seed + 2.0, 0.8, false));
	stars = max(stars, pixel_stars(cell + cam * 1.0, 31.0, near_star_density * density_scale, seed + 3.0, 1.0, true));
	stars = max(stars, giant_stars(cell + cam * 1.15, 70.0, giant_star_density * mix(0.0, 1.0, quiet), seed + 4.0));
	stars *= star_brightness;
	if (color_steps >= 1.0) {
		stars = floor(stars * color_steps + 0.5 + (bayer4(cell) - 0.5) * dither * 0.5) / color_steps;
	}
	col += stars;

	// ---- Focus area, vignette, brightness ----
	vec2 uv = (floor(SCREEN_UV * art_res) + 0.5) / art_res; // top-left origin, per art pixel
	if (focus_dim > 0.0 && focus_rect.z > 0.0) {
		vec2 half_size = focus_rect.zw * 0.5;
		vec2 q = abs(uv - (focus_rect.xy + half_size));
		vec2 dq = max(q - half_size, vec2(0.0));
		float aspect = art_res.x / art_res.y;
		float dist = length(vec2(dq.x * aspect, dq.y));
		float inside = 1.0 - smoothstep(0.0, max(0.001, focus_softness), dist);
		col *= 1.0 - focus_dim * inside;
	}
	vec2 vc = uv - 0.5;
	col *= 1.0 - vignette * smoothstep(0.25, 0.85, length(vc * vec2(1.0, 1.25)));
	COLOR = vec4(col * brightness, 1.0);
}
