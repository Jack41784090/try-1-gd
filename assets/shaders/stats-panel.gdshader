shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 2.0) = 0.3;
uniform vec4 glow_color : source_color = vec4(0.6, 0.5, 0.3, 1.0);
uniform float edge_glow_width : hint_range(0.0, 0.1) = 0.02;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;

void fragment() {
    vec4 base_color = texture(TEXTURE, UV);
    
    // Calculate distance from edges
    vec2 edge_dist = min(UV, 1.0 - UV);
    float min_edge_dist = min(edge_dist.x, edge_dist.y);
    
    // Create pulsing effect
    // float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    
    // Edge glow
    float edge_glow = smoothstep(edge_glow_width, 0.0, min_edge_dist);
    edge_glow *= glow_intensity * (0.7 + 0.3 );
    
    // Apply glow
    vec3 final_color = base_color.rgb + glow_color.rgb * edge_glow;
    
    COLOR = vec4(final_color, base_color.a);
}
