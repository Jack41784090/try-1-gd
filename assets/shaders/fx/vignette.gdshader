shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.45;
uniform float softness : hint_range(0.1, 1.0) = 0.45;
uniform float roundness : hint_range(0.5, 2.0) = 1.0;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV - 0.5;
	// Elliptical distance for non-square screens
	uv.x *= roundness;
	float dist = length(uv);

	// Smooth falloff from center to edges
	float vignette = smoothstep(softness, softness - 0.35, dist);
	float darkness = (1.0 - vignette) * intensity;

	COLOR = vec4(vignette_color.rgb, darkness);
}
