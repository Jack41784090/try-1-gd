shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.9, 0.75, 0.3, 1.0);
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 8.0) = 3.0;
uniform float is_glowing : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.15) = 0.05;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);

	vec2 edge_dist = min(UV, 1.0 - UV);
	float min_edge_dist = min(edge_dist.x, edge_dist.y);

	float pulse = sin(TIME * pulse_speed) * 0.35 + 0.65;
	float glow_factor = smoothstep(edge_width, 0.0, min_edge_dist);

	float active_glow = glow_factor * glow_intensity * pulse * step(0.5, is_glowing);

	vec3 final_color = base_color.rgb + glow_color.rgb * active_glow;
	COLOR = vec4(final_color, base_color.a + active_glow * 0.4);
}
