shader_type spatial;
uniform sampler2D normal_map : hint_normal;
uniform sampler2D albedo_texture : source_color;
uniform float fade_start = -12.0;
uniform float fade_end = 7.5;
varying float fade_weight;

void vertex() {
	VERTEX *= vec3(2,1,1);
	float denom = max(0.0001, fade_end - fade_start);
	float t = clamp((VERTEX.z - fade_start) / denom, 0.0, 1.0);
	fade_weight = t;
}

void fragment() {
	vec4 albedo = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a * fade_weight;
	NORMAL_MAP = texture(normal_map, UV).xyz;
}

void light() {
}
