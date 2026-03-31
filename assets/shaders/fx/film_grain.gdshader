shader_type canvas_item;

uniform float intensity : hint_range(0.0, 0.15) = 0.035;
uniform float speed : hint_range(0.1, 20.0) = 8.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 seed = UV * vec2(1920.0, 1080.0) + TIME * speed;
	float noise = hash(seed);

	// Grain that both lightens and darkens: white speckles + dark speckles
	float grain = (noise - 0.5) * 2.0;
	float is_light = step(0.0, grain);
	vec3 col = vec3(is_light);
	float alpha = abs(grain) * intensity;

	COLOR = vec4(col, alpha);
}
