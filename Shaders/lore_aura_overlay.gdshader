shader_type canvas_item;

uniform float noise_scale : hint_range(0.1, 10.0) = 3.0;
uniform float density_scale : hint_range(0.1, 5.0) = 1.2;
uniform float rotation_speed : hint_range(-5.0, 5.0) = 0.4;
uniform vec2 rotation_pivot = vec2(0.5);

uniform vec4 albedo_color_a : source_color = vec4(0.8, 0.05, 0.1, 0.85);
uniform vec4 albedo_color_b : source_color = vec4(0.35, 0.0, 0.5, 0.85);
uniform vec4 emission_color : source_color = vec4(1.0, 0.1, 0.15, 0.6);

vec2 hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(mix(dot(hash(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
				   dot(hash(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
			   mix(dot(hash(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
				   dot(hash(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		val += amp * noise(p);
		p *= 2.01;
		amp *= 0.5;
	}
	return val * 0.5 + 0.5;
}

vec2 rotate(vec2 uv, vec2 pivot, float angle) {
	mat2 rotation = mat2(
		vec2(cos(angle), -sin(angle)),
		vec2(sin(angle), cos(angle))
	);
	uv -= pivot;
	uv = uv * rotation;
	uv += pivot;
	return uv;
}

void fragment() {
	vec2 uv = UV;
	float rot_final = TIME * rotation_speed;
	vec2 noise_uv = rotate(uv, rotation_pivot, rot_final);

	float noi1 = fbm(noise_uv * noise_scale);
	float dist = length(uv - rotation_pivot);

	float dens = clamp((noi1 * 1.3) - (dist * 0.35), 0.0, 1.0) * density_scale;
	vec4 mixed_color = mix(albedo_color_a, albedo_color_b, dens);
	vec4 final_color = mixed_color + (emission_color * dens * 0.75);

	COLOR = vec4(final_color.rgb, dens * final_color.a);
}