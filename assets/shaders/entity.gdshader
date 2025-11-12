shader_type spatial;
// render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color;
// uniform sampler2D normal_map: hint_normal;

// Flash effect parameters
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec4 albedo = texture(albedo_texture, UV);
	vec3 flashed = albedo.rgb + (flash_color.rgb * flash_intensity);	
	ALBEDO = flashed;
	ALPHA = albedo.a;
}
