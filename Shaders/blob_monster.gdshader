// res://Shaders/blob_monster.gdshader
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// --- Surface Aesthetics ---
uniform vec4 base_color : source_color = vec4(0.15, 0.65, 0.35, 1.0);
uniform vec4 rim_color : source_color = vec4(0.45, 0.95, 0.6, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.15;
uniform float specular : hint_range(0.0, 1.0) = 0.8;

// --- Optional Texture ---
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = false;

// --- Organic Wobble (Vertex) ---
uniform float wobble_amount : hint_range(0.0, 0.3) = 0.05;
uniform float wobble_speed : hint_range(0.0, 10.0) = 3.2;

// --- Combat Action Uniforms ---
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hit_color : source_color = vec4(1.0, 0.15, 0.15, 1.0);

uniform float attack_charge : hint_range(0.0, 1.0) = 0.0;
uniform vec4 charge_color : source_color = vec4(1.0, 0.55, 0.1, 1.0);

void vertex() {
	// Living gelatinous wobble; expands and speeds up when charging an attack
	float current_speed = wobble_speed * (1.0 + attack_charge * 1.5);
	float wave = sin(TIME * current_speed + (VERTEX.x + VERTEX.y + VERTEX.z) * 3.5);
	float pulse = cos(TIME * (current_speed * 0.6) + VERTEX.y * 2.5);
	
	float total_wobble = wobble_amount * (1.0 + attack_charge * 1.8);
	VERTEX += NORMAL * (wave * 0.6 + pulse * 0.4) * total_wobble;
}

void fragment() {
	// 1. Base Albedo & Optional Texture Blend
	vec3 surface_col = base_color.rgb;
	if (use_texture) {
		surface_col *= texture(albedo_texture, UV).rgb;
	}

	// 2. Translucent/Wet Fresnel Rim
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	surface_col = mix(surface_col, rim_color.rgb, fresnel * 0.65);

	// 3. Specular Surface
	ALBEDO = surface_col;
	ROUGHNESS = roughness;
	SPECULAR = specular;

	// 4. Emissive Build-up (Rim base + Attack Charge + Hit Reaction)
	vec3 emissive = rim_color.rgb * fresnel * 0.35;
	emissive = mix(emissive, charge_color.rgb * 2.2, attack_charge);

	// Hit flash completely overrides surface and spikes brightness
	ALBEDO = mix(ALBEDO, hit_color.rgb, hit_flash);
	emissive = mix(emissive, hit_color.rgb * 2.5, hit_flash);

	EMISSION = emissive;
}