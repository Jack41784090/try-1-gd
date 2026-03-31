shader_type canvas_item;

uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 pulse_color : source_color = vec4(0.6, 0.02, 0.02, 1.0);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);

	// Red vignette radiating inward from edges
	float pulse_vignette = smoothstep(inner_radius, 0.7, dist);
	pulse_vignette *= pulse_vignette;

	float alpha = pulse_vignette * pulse_intensity;
	COLOR = vec4(pulse_color.rgb, alpha);
}
