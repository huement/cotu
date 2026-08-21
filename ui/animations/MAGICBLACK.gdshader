shader_type canvas_item;

uniform float black_threshold : hint_range(0.0, 0.5) = 0.03;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Determine pixel brightness using peak color channel
    float brightness = max(tex_color.r, max(tex_color.g, tex_color.b));
    
    if (brightness < black_threshold) {
        tex_color.a = 0.0;
    } else {
        // Multiply alpha by brightness to eliminate dark edge halos
        tex_color.a *= brightness;
    }
    
    COLOR = tex_color;
}