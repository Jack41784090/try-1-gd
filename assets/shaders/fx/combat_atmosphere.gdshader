shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float desaturation : hint_range(0.0, 1.0) = 0.5;
uniform float contrast : hint_range(0.5, 2.0) = 1.2;
uniform float red_shift : hint_range(0.0, 0.15) = 0.06;
uniform float darkness : hint_range(0.0, 0.5) = 0.1;
uniform float mix_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 screen = texture(screen_texture, SCREEN_UV);
	vec3 col = screen.rgb;

	// Desaturate
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 gray = vec3(lum);
	col = mix(col, gray, desaturation * mix_amount);

	// Slight red shift for blood/tension
	col.r += red_shift * mix_amount;

	// Contrast boost centered on 0.5
	col = (col - 0.5) * mix(1.0, contrast, mix_amount) + 0.5;

	// Overall darkening
	col *= 1.0 - darkness * mix_amount;

	col = clamp(col, 0.0, 1.0);
	COLOR = vec4(col, screen.a);
}
