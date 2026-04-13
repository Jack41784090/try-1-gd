shader_type canvas_item;

// Rugged grain overlay — gives characters a rough, hand-drawn texture
// Apply as ShaderMaterial on a ColorRect overlay covering the viewport

uniform float grain_intensity : hint_range(0.0, 0.3) = 0.12;
uniform float grain_size : hint_range(0.5, 4.0) = 1.5;
uniform float scratch_intensity : hint_range(0.0, 0.2) = 0.06;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.2;
uniform float speed : hint_range(0.1, 10.0) = 4.0;
uniform float desaturation : hint_range(0.0, 0.5) = 0.15;

// High-quality noise hash
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

// Value noise for larger-scale roughness
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 screen_coords = uv * vec2(1920.0, 1080.0) / grain_size;
	float t = TIME * speed;

	// Fine grain — salt and pepper noise
	float fine = hash12(screen_coords + t);
	float grain = (fine - 0.5) * 2.0 * grain_intensity;

	// Coarser noise for texture roughness
	float coarse = value_noise(screen_coords * 0.3 + t * 0.5);
	float rough = (coarse - 0.5) * grain_intensity * 0.6;

	// Vertical scratches — sparse, thin lines
	float scratch_seed = floor(screen_coords.x * 0.1) + floor(t * 0.3);
	float scratch_chance = hash12(vec2(scratch_seed, 0.0));
	float scratch = 0.0;
	if (scratch_chance > 0.97) {
		float line_x = fract(screen_coords.x * 0.1);
		scratch = smoothstep(0.48, 0.5, line_x) * smoothstep(0.52, 0.5, line_x);
		scratch *= scratch_intensity * hash12(vec2(scratch_seed, screen_coords.y * 0.01 + t));
	}

	// Vignette — darkened edges
	vec2 vig_uv = uv * 2.0 - 1.0;
	float vig = 1.0 - dot(vig_uv, vig_uv) * vignette_strength;
	vig = clamp(vig, 0.0, 1.0);

	// Combine: grain modulates brightness, scratches add white lines
	float combined = grain + rough + scratch;

	// Slightly desaturate by outputting grey with varying alpha
	float is_light = step(0.0, combined);
	vec3 col = vec3(is_light);
	float alpha = abs(combined) * vig;

	// Slight amber/sepia tint to dark grains for aged look
	if (!bool(is_light)) {
		col = vec3(0.1, 0.08, 0.05);
	}

	COLOR = vec4(col, clamp(alpha, 0.0, 0.5));
}
