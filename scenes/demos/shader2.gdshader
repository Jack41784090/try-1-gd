shader_type canvas_item;

uniform float progress: hint_range(0, 1);
uniform float color_bands: hint_range(1, 20) = 8.0;

vec3 palette(float t) {
	// [[0.398 0.585 0.573] [0.767 0.224 0.183] [1.231 1.432 0.892] [1.622 0.619 2.742]]
	vec3 c0 = vec3(0.398, 0.585, 0.573);
	vec3 c1 = vec3(0.767, 0.224, 0.183);
	vec3 c2 = vec3(1.231, 1.432, 0.892);
	vec3 c3 = vec3(1.622, 0.619, 2.742);
	
	return c0 + c1 * cos(6.28318 * (c2 * t + c3));
}

void fragment() {
	vec2 uv = UV * 2. - 1.;
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv0 = uv;
	
	//uv *= 2.;
	uv = fract(uv);
	uv -= .5;
	
	float d= length(uv);
	vec3 colour = palette(d + TIME);
	
	d = sin(d*8.+(TIME*2.5))/8.;
	d = abs(d);
	//d = smoothstep(0,0.1, d);
	d = .025/d;
	
	colour *= d;

	COLOR = vec4(colour,1);
}
