// res://Shaders/pixel_sky.gdshader
// Pixel-art sky for outdoor maps: banded gradient, drifting pixel clouds, pixel sun.
// At night the clouds fade out and the main-menu space scene (nebula + parallax pixel
// stars + glowing giants, ported from Shaders/space_pixel.gdshader) fades in.
//
// Driven by DayNightCycle each frame:  day_amount (0 night .. 1 day) and sun_direction.
// Everything is snapped to an "art pixel" grid on the sky dome (pixel_density), so
// clouds, the sun and stars are chunky pixels like the menu background.
shader_type sky;

group_uniforms pixel_look;
/** Art pixels per radian of sky. Lower = chunkier pixels. */
uniform float pixel_density : hint_range(40.0, 600.0, 1.0) = 160.0;
/** Colour bands in the sky gradient (fewer = more retro). */
uniform int color_steps : hint_range(2, 24) = 7;

group_uniforms time_of_day;
/** Set by DayNightCycle: 0 = night, 1 = full day. */
uniform float day_amount : hint_range(0.0, 1.0) = 1.0;
/** Set by DayNightCycle: direction toward the sun. */
uniform vec3 sun_direction = vec3(0.0, 0.7, 0.7);

group_uniforms day_sky;
uniform vec3 day_top : source_color = vec3(0.30, 0.50, 0.72);
uniform vec3 day_horizon : source_color = vec3(0.68, 0.78, 0.82);

group_uniforms night_sky;
uniform vec3 night_top : source_color = vec3(0.010, 0.014, 0.035);
uniform vec3 night_horizon : source_color = vec3(0.035, 0.045, 0.085);

group_uniforms sun_and_sunset;
uniform vec3 sun_color : source_color = vec3(1.0, 0.94, 0.78);
/** Sun disc radius in radians (0 = no disc). */
uniform float sun_size : hint_range(0.0, 0.2, 0.005) = 0.045;
uniform vec3 sunset_color : source_color = vec3(0.95, 0.48, 0.28);
uniform float sunset_strength : hint_range(0.0, 2.0, 0.05) = 0.8;

group_uniforms clouds;
/** 0 = clear, 1 = fully overcast. */
uniform float cloud_coverage : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float cloud_softness : hint_range(0.01, 0.5, 0.01) = 0.12;
uniform float cloud_scale : hint_range(0.1, 5.0, 0.05) = 1.2;
/** Bigger = clouds stay higher / flatter toward the horizon. */
uniform float cloud_height : hint_range(0.05, 1.0, 0.01) = 0.25;
/** Drift per second (sky units). */
uniform vec2 wind = vec2(0.010, 0.004);
/** Shading bands inside each cloud. */
uniform int cloud_bands : hint_range(2, 6) = 3;
uniform vec3 cloud_day_lit : source_color = vec3(0.96, 0.96, 0.94);
uniform vec3 cloud_day_shadow : source_color = vec3(0.56, 0.61, 0.70);
uniform vec3 cloud_night_lit : source_color = vec3(0.085, 0.095, 0.14);
uniform vec3 cloud_night_shadow : source_color = vec3(0.025, 0.03, 0.055);

group_uniforms night_space;
/** How much of the menu-style space scene shows at full night (0 = plain dark sky). */
uniform float space_amount : hint_range(0.0, 1.0, 0.01) = 1.0;
/** Clouds left at full night (0 = clouds fade out completely, 1 = clouds never fade). */
uniform float night_cloud_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
/** Sky drift in art pixels per second. Near star layers move faster. */
uniform vec2 space_drift = vec2(0.5, -0.2);
uniform float space_seed : hint_range(0.0, 100.0) = 7.0;
uniform vec3 nebula_dark : source_color = vec3(0.12, 0.03, 0.022);
uniform vec3 nebula_mid : source_color = vec3(0.25, 0.075, 0.04);
uniform vec3 nebula_bright : source_color = vec3(0.42, 0.16, 0.07);
uniform float nebula_intensity : hint_range(0.0, 2.0) = 0.85;
uniform float nebula_scale : hint_range(0.2, 6.0) = 1.0;
uniform float nebula_coverage : hint_range(0.0, 1.0) = 0.55;
uniform float nebula_grain : hint_range(0.0, 1.0) = 0.45;
uniform float nebula_warp : hint_range(0.0, 3.0) = 1.4;
uniform float dust_lanes : hint_range(0.0, 1.0) = 0.55;
uniform float nebula_evolve : hint_range(0.0, 0.2) = 0.015;

group_uniforms stars;
uniform float far_star_density : hint_range(0.0, 1.0) = 0.5;
uniform float mid_star_density : hint_range(0.0, 1.0) = 0.3;
uniform float near_star_density : hint_range(0.0, 1.0) = 0.2;
uniform float giant_star_density : hint_range(0.0, 1.0) = 0.3;
/** Glow radius of giant stars in art pixels. */
uniform float giant_glow : hint_range(1.0, 16.0) = 6.0;
uniform float star_brightness : hint_range(0.0, 3.0, 0.05) = 1.0;
uniform float star_twinkle : hint_range(0.0, 1.0, 0.05) = 0.5;
uniform float twinkle_speed : hint_range(0.0, 8.0) = 1.6;
uniform vec3 star_cool : source_color = vec3(1.0, 0.33, 0.16);
uniform vec3 star_warm : source_color = vec3(1.0, 0.62, 0.30);
uniform vec3 star_hot : source_color = vec3(1.0, 0.95, 0.82);
group_uniforms;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * amp;
		p = p * 2.03 + vec2(17.1, 9.7);
		amp *= 0.5;
	}
	return v;
}

float band(float v, int steps) {
	float s = float(steps);
	return floor(clamp(v, 0.0, 1.0) * s + 0.5) / s;
}

// TIME is only visible inside sky() on the Compatibility renderer, so it is passed in as tm.
// ---- Night space layer (ported from space_pixel.gdshader) ----
const float SPACE_STEPS = 10.0;
const float SPACE_DITHER = 0.45;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float bayer4(vec2 cell) {
	int x = int(mod(cell.x, 4.0));
	int y = int(mod(cell.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[x + y * 4]) + 0.5) / 16.0;
}

vec3 star_tint(float h) {
	if (h < 0.45) {
		return star_cool;
	}
	if (h < 0.85) {
		return star_warm;
	}
	return star_hot;
}

vec3 pixel_stars(vec2 q, float cell_px, float density, float layer_seed, float bright, bool plus_shape, float tm) {
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
			float tw = 1.0 - star_twinkle * 0.9 * (0.5 + 0.5 * sin(tm * twinkle_speed * (0.6 + h * 2.5) + h * 40.0));
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

vec3 giant_stars(vec2 q, float cell_px, float density, float layer_seed, float tm) {
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
			float pulse = 1.0 - star_twinkle * 0.4 * (0.5 + 0.5 * sin(tm * twinkle_speed * 0.7 + h * 31.0));
			float glow = exp(-r2 / (size * size)) * 0.75 * pulse;
			float core = r2 < 0.5 ? 1.0 : (r2 < 1.5 ? 0.75 : (r2 < 2.5 ? 0.45 : 0.0));
			vec3 tint = star_tint(0.4 + 0.6 * hash12(c + layer_seed + 2.0));
			col = max(col, tint * glow + star_hot * core * pulse);
		}
	}
	return col;
}

// Nebula + stars drawn over `base` (the night gradient). cell = art-pixel coords on the dome.
vec3 night_space(vec2 cell, vec3 base, float tm) {
	vec2 cam = space_drift * tm;
	vec2 np = (cell + cam * 0.25) / (180.0 * nebula_scale) + space_seed;
	float t = tm * nebula_evolve;
	vec2 warp = vec2(fbm(np * 1.3 + vec2(t, -t)), fbm(np * 1.3 + vec2(5.2 - t, 1.3 + t)));
	float n = fbm(np * 2.0 + warp * nebula_warp);
	float ridge = 1.0 - abs(2.0 * fbm(np * 3.1 - warp * 0.8 + 11.0) - 1.0);
	float cover = smoothstep(1.0 - nebula_coverage - 0.15, 1.0 - nebula_coverage + 0.45, n);
	float neb = cover * (0.65 + 0.55 * ridge * ridge);
	float dust = smoothstep(0.45, 0.75, fbm(np * 4.0 + warp * 2.0 + 31.0));
	neb *= 1.0 - dust_lanes * dust;
	float grain = vnoise((cell + cam * 0.25) * 0.3 + space_seed * 13.0) * 0.6 + vnoise((cell + cam * 0.25) * 0.11 + 3.0) * 0.4;
	neb *= mix(1.0, 0.45 + grain * 1.1, nebula_grain);
	neb += nebula_grain * 0.12 * smoothstep(0.55, 0.9, grain) * (1.0 - cover);
	neb *= nebula_intensity;
	float bd = bayer4(cell) - 0.5;
	neb = clamp(floor(clamp(neb, 0.0, 1.0) * SPACE_STEPS + 0.5 + bd * SPACE_DITHER) / SPACE_STEPS, 0.0, 1.0);

	vec3 col = base;
	col = mix(col, nebula_dark, smoothstep(0.0, 0.35, neb));
	col = mix(col, nebula_mid, smoothstep(0.3, 0.7, neb));
	col = mix(col, nebula_bright, smoothstep(0.65, 1.0, neb));

	vec3 stars = vec3(0.0);
	stars = max(stars, pixel_stars(cell + cam * 0.35, 9.0, far_star_density, space_seed + 1.0, 0.45, false, tm));
	stars = max(stars, pixel_stars(cell + cam * 0.6, 17.0, mid_star_density, space_seed + 2.0, 0.8, false, tm));
	stars = max(stars, pixel_stars(cell + cam * 1.0, 31.0, near_star_density, space_seed + 3.0, 1.0, true, tm));
	stars = max(stars, giant_stars(cell + cam * 1.15, 70.0, giant_star_density, space_seed + 4.0, tm));
	stars *= star_brightness;
	stars = max(floor(stars * SPACE_STEPS + 0.5 + bd * SPACE_DITHER * 0.5) / SPACE_STEPS, vec3(0.0));
	return col + stars;
}

void sky() {
	vec3 sd = normalize(sun_direction);
	float night = 1.0 - day_amount;
	// Cross-fade: clouds out, space in, as night falls.
	float space_fade = space_amount * smoothstep(0.1, 0.9, night);

	// Snap the view direction to the art-pixel grid on the dome.
	vec3 cell = floor(EYEDIR * pixel_density);
	vec3 dir = AT_CUBEMAP_PASS ? EYEDIR : normalize((cell + 0.5) / pixel_density);

	// Banded gradient
	float h = clamp(dir.y, 0.0, 1.0);
	float t = band(sqrt(h), color_steps);
	vec3 col = mix(mix(night_horizon, night_top, t), mix(day_horizon, day_top, t), day_amount);

	// Sunset / sunrise glow near the horizon on the sun's side
	float sun_low = 1.0 - smoothstep(0.0, 0.4, abs(sd.y));
	float toward = max(dot(dir, sd), 0.0);
	float glow = band(pow(toward, 4.0) * (1.0 - h) * sun_low * sunset_strength, color_steps);
	col += sunset_color * glow;

	// Below the horizon (usually hidden by terrain)
	if (dir.y < 0.0) {
		col *= mix(1.0, 0.5, clamp(-dir.y * 4.0, 0.0, 1.0));
	}

	if (AT_CUBEMAP_PASS) {
		// Ambient / reflection pass: gradient only (cheap, no flicker in lighting).
		COLOR = col;
	} else {
		// Pixel sun disc
		if (sun_size > 0.0 && sd.y > -0.05 && dot(dir, sd) > cos(sun_size)) {
			col = mix(col, sun_color, clamp(day_amount * 1.5, 0.0, 1.0));
		}

		// Clouds projected on a flat ceiling
		float cloud = 0.0;
		if (dir.y > 0.0) {
			vec2 uv = dir.xz / (dir.y + cloud_height) * cloud_scale + wind * TIME;
			float n = fbm(uv);
			float edge = 1.0 - cloud_coverage;
			cloud = smoothstep(edge, edge + cloud_softness, n);
			cloud *= smoothstep(0.0, 0.12, dir.y);
			cloud = band(cloud, 3);
			cloud *= 1.0 - space_fade * (1.0 - night_cloud_amount);

			// Lit on the sun side: compare density a little toward the sun.
			vec2 light_dir = length(sd.xz) > 0.001 ? normalize(sd.xz) : vec2(0.0, 1.0);
			float n2 = fbm(uv + light_dir * 0.08);
			float shade = clamp((n - n2) * 5.0 + 0.55, 0.0, 1.0);
			shade = floor(shade * float(cloud_bands)) / float(cloud_bands - 1);
			shade = clamp(shade, 0.0, 1.0);

			vec3 lit = mix(cloud_night_lit, cloud_day_lit, day_amount);
			vec3 shadow = mix(cloud_night_shadow, cloud_day_shadow, day_amount);
			vec3 ccol = mix(shadow, lit, shade) + sunset_color * glow * 0.6;
			col = mix(col, ccol, cloud);
		}

		// Menu-style space scene at night (own 2D art-pixel grid on the dome), hidden by clouds
		if (space_fade > 0.001 && EYEDIR.y > 0.0) {
			vec2 q = EYEDIR.xz / (1.0 + EYEDIR.y) * pixel_density * 1.5;
			float amount = space_fade * smoothstep(0.0, 0.25, EYEDIR.y) * (1.0 - cloud);
			col = mix(col, night_space(floor(q), col, TIME), amount);
		}
		COLOR = col;
	}
}
