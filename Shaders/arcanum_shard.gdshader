shader_type spatial;
render_mode cull_disabled;
// Arcanum Shard: raw corrupting energy.
// - the green lightning painted in the texture glows and pulses
// - extra energy veins crawl up the crystal (procedural, object space)
// - rim glow on the edges, a faint surface shiver
// - "surge" (0..1) is driven by Scripts/Objects/ArcanumShard.gd for the periodic flare-ups
// Cheap on purpose: no screen/depth textures, fine on GL Compatibility + mobile.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 albedo_tint : source_color = vec3(0.75, 0.8, 0.75);
uniform float roughness : hint_range(0.0, 1.0) = 0.35;
uniform float metallic : hint_range(0.0, 1.0) = 0.25;

group_uniforms energy;
uniform vec3 energy_color : source_color = vec3(0.25, 1.0, 0.3);
uniform vec3 hot_color : source_color = vec3(0.9, 1.0, 0.75);
/** Glow of the lightning already painted in the texture. */
uniform float painted_glow : hint_range(0.0, 8.0) = 2.5;
/** Glow of the moving veins. */
uniform float vein_glow : hint_range(0.0, 8.0) = 2.0;
uniform float vein_scale : hint_range(0.2, 6.0) = 1.4;
uniform float vein_sharpness : hint_range(1.0, 16.0) = 7.0;
uniform float flow_speed : hint_range(0.0, 4.0) = 0.6;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.2;

group_uniforms rim;
uniform vec3 rim_color : source_color = vec3(0.45, 1.0, 0.35);
uniform float rim_power : hint_range(0.5, 8.0) = 2.5;
uniform float rim_strength : hint_range(0.0, 6.0) = 1.2;

group_uniforms motion;
/** Surface shiver, in model units. */
uniform float wobble : hint_range(0.0, 0.3) = 0.03;
/** 0..1 flare-up, set from script. */
uniform float surge : hint_range(0.0, 1.0) = 0.0;
uniform float surge_boost : hint_range(0.0, 8.0) = 3.0;

varying vec3 obj_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

void vertex() {
	obj_pos = VERTEX;
	// Push along a direction that depends only on position, so split (flat-shaded) faces stay joined.
	vec3 dir = normalize(VERTEX - vec3(0.0, 0.9, 0.0) + vec3(0.0001));
	float n = noise(VERTEX * 1.3 + vec3(0.0, TIME * 0.8, 0.0)) - 0.5;
	VERTEX += dir * n * wobble * (1.0 + surge * 4.0);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	// How "green lightning" this texel is.
	float painted = smoothstep(0.2, 0.75, tex.g - 0.6 * max(tex.r, tex.b));

	vec3 p = obj_pos * vein_scale;
	float n1 = noise(p + vec3(0.0, -TIME * flow_speed, 0.0));
	float n2 = noise(p * 2.1 + vec3(TIME * flow_speed * 0.7, 0.0, TIME * 0.3));
	float veins = pow(1.0 - abs(n1 * 2.0 - 1.0), vein_sharpness)
		+ 0.5 * pow(1.0 - abs(n2 * 2.0 - 1.0), vein_sharpness + 2.0);

	float pulse = 0.65 + 0.35 * sin(TIME * pulse_speed + obj_pos.y * 1.5);
	float flicker = 0.85 + 0.15 * noise(vec3(TIME * 9.0, 0.0, 0.0));
	float fresnel = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), rim_power);
	float boost = 1.0 + surge * surge_boost;

	ALBEDO = tex.rgb * albedo_tint;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	vec3 glow = energy_color * (painted * painted_glow * pulse + veins * vein_glow);
	glow += hot_color * veins * veins * 0.6;
	glow += rim_color * fresnel * rim_strength;
	EMISSION = glow * flicker * boost;
}
