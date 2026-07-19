shader_type canvas_item;

// Grabs the screen behind the panel
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
uniform vec4 background_tint : source_color = vec4(0.15, 0.15, 0.2, 0.4); // Dark blue/gray tint
uniform float vibrancy : hint_range(1.0, 2.0) = 1.3; // Boosts background colors

void fragment() {
    // 1. Sample the screen behind the UI with a specific blur level
    vec4 blurred = textureLod(screen_texture, SCREEN_UV, blur_amount);
    
    // 2. Increase saturation/vibrancy for a modern look
    float luminance = dot(blurred.rgb, vec3(0.299, 0.587, 0.114));
    vec3 vibrant_color = mix(vec3(luminance), blurred.rgb, vibrancy);
    
    // 3. Blend the vibrant blurred screen with our custom tint window color
    COLOR = vec4(mix(vibrant_color, background_tint.rgb, background_tint.a), 1.0);
}