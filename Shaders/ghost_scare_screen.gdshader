shader_type canvas_item;

/// Full-screen scare pulse (GhostScareFX). `intensity` 0 = untouched screen, 1 = full effect.
/// duotone 0: invert + red/blue split + tinted vignette (ghost jump scare).
/// duotone 1: the picture crushed to two colours - black shadows, `tint` highlights (red/black boss strobe).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float split_amount : hint_range(0.0, 0.06) = 0.018;
uniform vec4 tint : source_color = vec4(0.62, 0.08, 1.0, 1.0);
uniform float duotone : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 off = vec2(split_amount * intensity, split_amount * 0.35 * intensity);
	vec3 col = vec3(
		texture(screen_tex, uv + off).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - off).b);
	float vignette = smoothstep(0.22, 0.78, distance(uv, vec2(0.5)));

	// Ghost mode: inverted colours, tinted corners.
	vec3 scare = mix(col, vec3(1.0) - col, intensity);
	scare = mix(scare, tint.rgb * (0.35 + 0.65 * dot(scare, vec3(0.333))), vignette * intensity * 0.7);

	// Blood mode: black shadows, tint-coloured highlights, darker corners.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 duo = mix(vec3(0.0), tint.rgb * 1.15, smoothstep(0.12, 0.62, luma));
	duo *= 1.0 - vignette * 0.85;
	vec3 blood = mix(col, duo, intensity);

	COLOR = vec4(mix(scare, blood, duotone), 1.0);
}
