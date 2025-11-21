shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.9;
uniform vec4 high_morale_color : source_color = vec4(0.2, 0.8, 0.3, 1.0);
uniform vec4 mid_morale_color : source_color = vec4(0.9, 0.7, 0.2, 1.0);
uniform vec4 low_morale_color : source_color = vec4(0.9, 0.2, 0.2, 1.0);
uniform vec4 background_color : source_color = vec4(0.15, 0.15, 0.2, 0.8);
uniform float knot_scale : hint_range(1.0, 10.0) = 3.0;
uniform float knot_speed : hint_range(0.0, 2.0) = 0.5;
uniform float knot_thickness : hint_range(0.01, 0.2) = 0.08;
uniform float wave_amplitude : hint_range(0.0, 0.5) = 0.15;

// Norse knotwork pattern using interwoven sine waves
float norse_knot(vec2 uv, float time) {
    // Horizontal position with animation - use TWO_PI for seamless tiling
    float x = (uv.x * knot_scale + time * knot_speed) * 6.28318; // 2*PI
    
    // Create three interwoven sine waves at different vertical positions
    // Each wave oscillates around its own center line
    float center1 = 0.25;  // Top third
    float center2 = 0.5;   // Middle
    float center3 = 0.75;  // Bottom third
    
    float wave1 = center1 + sin(x) * wave_amplitude;
    float wave2 = center2 + sin(x + 2.094) * wave_amplitude; // +120 degrees
    float wave3 = center3 + sin(x + 4.189) * wave_amplitude; // +240 degrees
    
    // Add secondary harmonics for complexity (also seamless)
    wave1 += sin(x * 2.0 + time * 2.0) * wave_amplitude * 0.2;
    wave2 += sin(x * 2.0 + time * 2.0 + 2.094) * wave_amplitude * 0.2;
    wave3 += sin(x * 2.0 + time * 2.0 + 4.189) * wave_amplitude * 0.2;
    
    // Calculate distance from current pixel to each wave
    float dist1 = abs(uv.y - wave1);
    float dist2 = abs(uv.y - wave2);
    float dist3 = abs(uv.y - wave3);
    
    // Create weaving pattern - use fract on x position for seamless repeat
    float phase = fract((uv.x * knot_scale + time * knot_speed) * 1.5);
    
    // Draw each strand with smooth falloff
    float strand1 = 1.0 - smoothstep(0.0, knot_thickness, dist1);
    float strand2 = 1.0 - smoothstep(0.0, knot_thickness, dist2);
    float strand3 = 1.0 - smoothstep(0.0, knot_thickness, dist3);
    
    // Smooth weaving transitions using smoothstep
    float mask1 = smoothstep(0.0, 0.1, phase) * (1.0 - smoothstep(0.233, 0.333, phase));
    float mask2 = smoothstep(0.233, 0.333, phase) * (1.0 - smoothstep(0.566, 0.666, phase));
    float mask3 = smoothstep(0.566, 0.666, phase) + (1.0 - smoothstep(0.9, 1.0, phase));
    
    // Combine strands with smooth weaving
    float pattern = max(max(strand1 * mask1, strand2 * mask2), strand3 * mask3);
    
    // Add underlayer strands with reduced opacity
    float underlay = (strand1 * (1.0 - mask1) + 
                      strand2 * (1.0 - mask2) + 
                      strand3 * (1.0 - mask3)) * 0.4;
    
    return clamp(pattern + underlay, 0.0, 1.0);
}

void fragment() {
    vec2 uv = UV;
    
    // Determine morale color based on progress
    vec4 morale_color;
    if (progress > 0.6) {
        morale_color = mix(mid_morale_color, high_morale_color, (progress - 0.6) / 0.4);
    } else if (progress > 0.3) {
        morale_color = mix(low_morale_color, mid_morale_color, (progress - 0.3) / 0.3);
    } else {
        morale_color = low_morale_color;
    }
    
    // Generate Norse knotwork pattern
    float knot_pattern = norse_knot(uv, TIME);
    
    // Apply pattern to morale color
    vec3 pattern_color = mix(morale_color.rgb * 0.7, morale_color.rgb * 1.3, knot_pattern);
    
    // Fill bar based on progress
    float fill = step(uv.x, progress);
    
    // Add subtle gradient overlay
    float gradient = 1.0 - (uv.y * 0.2);
    pattern_color *= gradient;
    
    // Mix between background and filled morale bar
    vec3 final_color = mix(background_color.rgb, pattern_color, fill);
    
    // Add border highlight
    float border = 0.0;
    if (uv.x < 0.01 || uv.x > 0.99 || uv.y < 0.05 || uv.y > 0.95) {
        border = 0.3;
    }
    final_color += vec3(border);
    
    COLOR = vec4(final_color, 1.0);
}