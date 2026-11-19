shader_type canvas_item;

uniform float water_clock = 0.0;
uniform float current_speed = 0.0;
uniform bool raining = false;
uniform bool ravine_flow = false;
uniform bool still_water = false;
uniform bool masked = false;
uniform sampler2D shore_mask : hint_default_white, filter_linear, repeat_disable;
uniform vec2 mask_scale;
uniform vec2 mask_offset;

varying vec2 ground_position;

void vertex() {
	ground_position = VERTEX;
}

float grain(vec2 cell) {
	vec2 seed = fract(cell * vec2(0.1031, 0.11369));
	return fract((seed.x + seed.y) * (19.19 + 37.17 * seed.x));
}

float ripple(vec2 point, vec2 spacing) {
	vec2 cell = floor(point / spacing);
	vec2 within = mod(point, spacing);
	float seed = grain(cell);
	vec2 start = vec2(2.0 + floor(seed * 8.0), 2.0 + floor(grain(cell + 23.0) * (spacing.y - 4.0)));
	float length = 3.0 + floor(grain(cell - 11.0) * 9.0);
	float crest = step(start.x, within.x) * (1.0 - step(start.x + length, within.x));
	crest *= 1.0 - step(1.0, abs(within.y - start.y));
	float shimmer = 0.65 + 0.35 * sin(water_clock * 1.35 + seed * TAU);
	return crest * shimmer * step(0.29, seed);
}

float rain_ring(vec2 pixel) {
	vec2 cell = floor(pixel / 29.0);
	float seed = grain(cell + 31.0);
	vec2 center = vec2(7.0, 7.0) + floor(vec2(seed, grain(cell - 13.0)) * 14.0);
	float drop = fract(water_clock * 0.91 + seed);
	vec2 offset = (mod(pixel, 29.0) - center) * vec2(1.0, 1.75);
	float line = 1.0 - step(0.9, abs(length(offset) - drop * 7.0));
	return line * (1.0 - smoothstep(0.18, 0.84, drop)) * step(0.5, seed);
}

// Short, curved wave fronts passing in and out of reflected light on standing water.
float wind_crests(vec2 p) {
	float bend = 1.4 * sin(p.x * 0.14 + p.y * 0.08 + water_clock * 0.65)
		+ 0.75 * sin(p.x * 0.26 - p.y * 0.09 - water_clock * 0.44);
	float row = sin(p.y * 0.41 + bend + water_clock * 1.05);
	float light = 0.58 * sin(p.x * 0.15 + p.y * 0.18 - water_clock * 0.51)
		+ 0.42 * sin(p.x * 0.27 - p.y * 0.13 + water_clock * 0.83);
	return smoothstep(0.87, 0.99, row) * smoothstep(0.32, 0.83, light);
}

void fragment() {
	vec2 pixel = floor(ground_position);
	vec2 flow = pixel + vec2(0.0, -floor(water_clock * current_speed));
	float swell = sin(flow.x * 0.24 + flow.y * 0.07) + sin(flow.x * 0.13 - flow.y * 0.11 + 1.7);
	float shadow = smoothstep(0.25, 1.9, -swell) * 0.18;
	float glint = ripple(flow, vec2(23.0, 18.0)) * 0.36;
	glint += ripple(flow + vec2(12.0, 7.0), vec2(31.0, 25.0)) * 0.17;
	if (still_water) {
		pixel = floor(ground_position * 2.0) * 0.5;
		glint = wind_crests(pixel) * 0.24;
		shadow = smoothstep(0.35, 1.8, -swell) * 0.045;
	} else if (ravine_flow) {
		// Breaking crests intersect narrow reflected runs down the creek.
		vec2 woven = flow + vec2(floor(sin(flow.y * 0.07) * 3.0), 0.0);
		vec2 streak = vec2(woven.y, woven.x);
		float current = ripple(streak + vec2(3.0, 8.0), vec2(28.0, 13.0));
		float broken = ripple(woven + vec2(7.0, 11.0), vec2(29.0, 23.0));
		glint = glint * 0.48 + current * 0.28 + broken * 0.16;
		shadow *= 0.80;
	}
	if (raining) {
		glint *= 0.56;
		glint += rain_ring(pixel) * 0.4;
	}
	vec3 light_color = mix(vec3(0.14, 0.29, 0.29), COLOR.rgb, smoothstep(0.0, 0.11, glint));
	float wet_area = masked ? texture(shore_mask, ground_position * mask_scale + mask_offset).a : 1.0;
	COLOR = vec4(light_color, max(shadow, glint) * wet_area);
}
