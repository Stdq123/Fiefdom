shader_type canvas_item;

uniform float motion_phase = 0.0;
uniform bool lanterns_lit = false;

// Locations on the shared 2560 × 1440 camera frame.
const vec2 SPRING = vec2(1779.0, 1115.0);
const vec2 LEFT_LANTERN = vec2(1330.0, 535.0);
const vec2 RIGHT_LANTERN = vec2(1558.0, 535.0);

float spring_ripple(vec2 pixel, vec3 surface, float phase) {
	vec2 point = floor(pixel / 3.0) * 3.0 - SPRING;
	vec2 edge = abs(point / vec2(60.0, 18.0));
	float basin = 1.0 - smoothstep(0.68, 1.0, max(edge.x, edge.y));
	// Only the blue-green basin ripples. The stones and the rim keep their texture.
	float water = smoothstep(0.04, 0.12, min(surface.g, surface.b) - surface.r);
	float bend = sin(point.x * 0.105 + phase * 6.0) * 0.85;
	float wave = sin(point.y * 0.62 - phase * 11.0 + bend);
	float highlights = sin(point.x * 0.155 + point.y * 0.12 - phase * 7.0);
	float crest = smoothstep(0.49, 0.94, wave) * smoothstep(-0.25, 0.78, highlights);
	return basin * water * (crest * 0.105 - 0.022);
}

float lantern_light(vec2 pixel, vec2 origin, float phase, float offset) {
	vec2 relative = (pixel - origin) / vec2(94.0, 90.0);
	float falloff = 1.0 - smoothstep(0.04, 1.0, dot(relative, relative));
	float flame = sin(phase * 21.0 + offset) * 0.052
		+ sin(phase * 37.0 + offset * 2.0) * 0.036;
	return falloff * (flame - 0.018);
}

void fragment() {
	if (COLOR.a > 0.0) {
		vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
		float phase = motion_phase * TAU;
		vec2 basin = abs(pixel - SPRING);
		if (basin.x < 63.0 && basin.y < 21.0) {
			COLOR.rgb += vec3(0.63, 0.91, 0.88) * spring_ripple(pixel, COLOR.rgb, phase);
		}
		if (lanterns_lit && pixel.x > 1236.0 && pixel.x < 1652.0 && abs(pixel.y - 535.0) < 90.0) {
			float flicker = lantern_light(pixel, LEFT_LANTERN, phase, 0.0)
				+ lantern_light(pixel, RIGHT_LANTERN, phase, 2.2);
			COLOR.rgb *= 1.0 + flicker;
		}
	}
}
