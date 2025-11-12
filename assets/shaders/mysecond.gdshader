shader_type spatial;
// render_mode unshaded;

uniform sampler2D normal_map : hint_normal;

void vertex() {
	// VERTEX.x += cos(TIME + VERTEX.x + VERTEX.y) * 2.;
	// VERTEX.y += cos(TIME + VERTEX.x + VERTEX.y) * 2.;
	// VERTEX.z += cos(TIME) * 2.;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);  // billboard
	VERTEX *= vec3(5);
}


uniform bool effect_enabled;
uniform sampler2D albedo_texture : source_color;
// uniform sampler2D albedo_texture : source_color, hint_albedo;

void fragment() {
	if (effect_enabled) {
		ALBEDO = vec3(1.0, 1.0, 1.0); //White colour
	} else {
		ALBEDO = texture(albedo_texture, UV).rgb;
	}
	ALPHA = texture(albedo_texture, UV).a;
	NORMAL_MAP = texture(normal_map, UV).xyz;

}

void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
}
