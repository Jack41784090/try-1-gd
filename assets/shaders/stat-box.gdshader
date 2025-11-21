shader_type canvas_item;

uniform sampler2D background_texture : source_color;
uniform float texture_scale : hint_range(0.1, 5.0) = 1.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.3);
uniform float border_thickness : hint_range(0.0, 0.05) = 0.01;
uniform vec4 border_color : source_color = vec4(0.6, 0.5, 0.3, 0.8);

void fragment() {
    vec4 base_color = texture(TEXTURE, UV);
    
    // Sample background texture with scaling
    vec2 scaled_uv = UV * texture_scale;
    vec4 bg = texture(background_texture, scaled_uv);
    
    // Create border
    vec2 edge_dist = min(UV, 1.0 - UV);
    float min_edge_dist = min(edge_dist.x, edge_dist.y);
    float border = smoothstep(border_thickness, border_thickness * 0.5, min_edge_dist);
    
    // Blend background with tint
    vec3 background = mix(bg.rgb, tint_color.rgb, 0.5) * tint_color.a;
    
    // Apply border
    vec3 final_color = mix(base_color.rgb + background, border_color.rgb, border * border_color.a);
    
    COLOR = vec4(final_color, base_color.a);
}
