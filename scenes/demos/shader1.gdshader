shader_type canvas_item;

uniform float progress: hint_range(0, 1);
uniform float color_bands = 8.0;
uniform float animation_speed= 1.0;
uniform bool auto_repeat = true;

vec3 palette(float t) {
	// [[0.660 0.560 0.680] [0.718 0.438 0.720] [0.520 0.800 0.520] [-0.430 -0.397 -0.083]]
	vec3 c0 = vec3(0.660, 0.560, 0.680);
	vec3 c1 = vec3(0.718, 0.438, 0.720);
	vec3 c2 = vec3(0.520, 0.800, 0.520);
	vec3 c3 = vec3(-0.430, -0.397, -0.083);
	
	return c0 + c1 * cos(6.28318 * (c2 * t + c3));
}

void fragment() {
	float real_progress = progress;
	if (auto_repeat) {
		real_progress = mod(TIME / animation_speed, 2.0);
	}
	// door
	 //if (abs(UV.x - 0.5) * 2. > progress) {
	 	//discard;
	 //}
	
	// middle diamond
	//if (abs(UV.x-.5) + abs(UV.y-.5) > progress) {
		//discard;
	//}
	
	// corner sweep
	float xycomb = (UV.x + UV.y);
	if (xycomb / 2. > real_progress) {
		discard;
	}
	
	// some bullshit
	float sin_freq = 12.;
	float divide_freq = 1.25;
	float close_spd = 1.;
	float bs = fract(sin(xycomb * sin_freq) * divide_freq);
	if (bs / close_spd > real_progress) {
		discard;
	}
	
	// colors
	float palette_t = bs;
	palette_t = floor(palette_t * color_bands) / color_bands;
	COLOR = vec4(palette(palette_t), 1);
}
