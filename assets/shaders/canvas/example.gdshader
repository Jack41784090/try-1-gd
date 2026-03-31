shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.3;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float pulse = sin(TIME * pulse_speed) * pulse_amount + (1.0 - pulse_amount);
	vec4 tinted = mix(tex, tex * tint_color, tint_strength);
	COLOR = tinted * vec4(vec3(pulse), 1.0);
	COLOR.a = tex.a;
}
