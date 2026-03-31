shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.12;
uniform float speed : hint_range(0.01, 1.0) = 0.08;
uniform float density : hint_range(0.5, 5.0) = 1.8;
uniform vec4 fog_color : source_color = vec4(0.6, 0.58, 0.52, 1.0);
uniform float vertical_fade : hint_range(0.0, 1.0) = 0.7;

// Value noise functions
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amp * noise(p);
		p *= 2.2;
		amp *= 0.45;
	}
	return value;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	// Two layers of fog moving at different speeds and scales
	float fog1 = fbm(uv * density * 3.0 + vec2(t * 0.7, t * 0.3));
	float fog2 = fbm(uv * density * 1.5 + vec2(-t * 0.4, t * 0.6) + 5.0);

	// Wispy combination: subtract layers for tendril-like shapes
	float fog = fog1 * 0.6 + fog2 * 0.4;
	fog = smoothstep(0.3, 0.7, fog);

	// Fade fog towards top of screen (fog hugs the ground)
	float v_fade = smoothstep(0.0, vertical_fade, uv.y);
	fog *= v_fade;

	// Slight horizontal edge fade
	float h_fade = smoothstep(0.0, 0.15, uv.x) * smoothstep(0.0, 0.15, 1.0 - uv.x);
	fog *= h_fade;

	float alpha = fog * intensity;
	COLOR = vec4(fog_color.rgb, alpha);
}
