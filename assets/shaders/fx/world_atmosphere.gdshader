shader_type canvas_item;

uniform float hour_of_day : hint_range(0.0, 24.0) = 12.0;
uniform float fog_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float fog_speed : hint_range(0.01, 1.0) = 0.06;
uniform float fog_density : hint_range(0.5, 5.0) = 1.8;

// --- Noise for fog ---
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

// --- Time-of-day helpers ---
float get_night_factor(float h) {
	if (h < 4.0) return 1.0;
	if (h < 7.0) return smoothstep(4.0, 7.0, h);
	if (h < 18.0) return 0.0;
	if (h < 21.0) return smoothstep(18.0, 21.0, h);
	return 1.0;
}

float get_dawn_factor(float h) {
	if (h < 4.0) return 0.0;
	if (h < 6.0) return smoothstep(4.0, 6.0, h);
	if (h < 8.0) return 1.0 - smoothstep(6.0, 8.0, h);
	return 0.0;
}

float get_dusk_factor(float h) {
	if (h < 16.0) return 0.0;
	if (h < 18.0) return smoothstep(16.0, 18.0, h);
	if (h < 20.0) return 1.0 - smoothstep(18.0, 20.0, h);
	return 0.0;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 col = tex.rgb;

	float h = hour_of_day;
	float night = get_night_factor(h);
	float dawn = get_dawn_factor(h);
	float dusk = get_dusk_factor(h);

	// --- Subtle desaturation at night ---
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float desat_amount = night * 0.35 + dusk * 0.15;
	col = mix(col, vec3(luma), desat_amount);

	// --- Color tinting (multiplicative, keep values bright enough) ---
	vec3 night_tint = vec3(0.55, 0.6, 0.9);
	vec3 dawn_tint = vec3(1.0, 0.85, 0.7);
	vec3 dusk_tint = vec3(0.95, 0.7, 0.55);
	vec3 day_tint = vec3(1.0, 0.99, 0.97);

	float day_w = 1.0 - night - dawn - dusk;
	vec3 tint = night_tint * night + dawn_tint * dawn + dusk_tint * dusk + day_tint * max(day_w, 0.0);
	col *= tint;

	// --- Brightness reduction at night ---
	float brightness = mix(1.0, 0.55, night) * mix(1.0, 0.85, dawn) * mix(1.0, 0.8, dusk);
	col *= brightness;

	// --- Mild contrast boost (deepen shadows slightly) ---
	float contrast = 1.0 + night * 0.12 + dusk * 0.08;
	col = (col - 0.5) * contrast + 0.5;
	col = clamp(col, 0.0, 1.0);

	// --- Fog wisps baked into the texture ---
	if (fog_intensity > 0.001) {
		float t = TIME * fog_speed;
		float fog1 = fbm(UV * fog_density * 3.0 + vec2(t * 0.7, t * 0.3));
		float fog2 = fbm(UV * fog_density * 1.5 + vec2(-t * 0.4, t * 0.6) + 5.0);
		float fog = fog1 * 0.6 + fog2 * 0.4;
		fog = smoothstep(0.3, 0.7, fog);

		// Fog hugs lower portion of the image
		float v_fade = smoothstep(0.0, 0.7, UV.y);
		fog *= v_fade;

		vec3 fog_col = mix(vec3(0.5, 0.48, 0.42), vec3(0.2, 0.22, 0.35), night);
		col = mix(col, fog_col, fog * fog_intensity);
	}

	COLOR = vec4(col, tex.a);
}
