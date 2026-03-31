shader_type canvas_item;

uniform float hour_of_day : hint_range(0.0, 24.0) = 12.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float h = hour_of_day;

	// Night color: deep cold blue
	vec3 night_col = vec3(0.02, 0.03, 0.12);
	// Dawn color: warm amber
	vec3 dawn_col = vec3(0.25, 0.12, 0.03);
	// Day color: very subtle warm
	vec3 day_col = vec3(0.05, 0.03, 0.0);
	// Dusk color: deep burnt orange
	vec3 dusk_col = vec3(0.22, 0.06, 0.02);

	// Night darkness level (alpha)
	float night_alpha = 0.45;
	float dawn_alpha = 0.18;
	float day_alpha = 0.04;
	float dusk_alpha = 0.25;

	// Phase blending using smoothstep transitions
	// 0-4: deep night
	// 4-6: night → dawn
	// 6-8: dawn → day
	// 8-16: day
	// 16-18: day → dusk
	// 18-20: dusk → night
	// 20-24: deep night

	float night_w = 0.0;
	float dawn_w = 0.0;
	float day_w = 0.0;
	float dusk_w = 0.0;

	if (h < 4.0) {
		night_w = 1.0;
	} else if (h < 6.0) {
		float t = smoothstep(4.0, 6.0, h);
		night_w = 1.0 - t;
		dawn_w = t;
	} else if (h < 8.0) {
		float t = smoothstep(6.0, 8.0, h);
		dawn_w = 1.0 - t;
		day_w = t;
	} else if (h < 16.0) {
		day_w = 1.0;
	} else if (h < 18.0) {
		float t = smoothstep(16.0, 18.0, h);
		day_w = 1.0 - t;
		dusk_w = t;
	} else if (h < 20.0) {
		float t = smoothstep(18.0, 20.0, h);
		dusk_w = 1.0 - t;
		night_w = t;
	} else {
		night_w = 1.0;
	}

	vec3 tint = night_col * night_w + dawn_col * dawn_w + day_col * day_w + dusk_col * dusk_w;
	float alpha = night_alpha * night_w + dawn_alpha * dawn_w + day_alpha * day_w + dusk_alpha * dusk_w;

	COLOR = vec4(tint, alpha * intensity);
}
