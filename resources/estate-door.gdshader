shader_type canvas_item;

uniform vec2 aperture_origin;
uniform vec2 aperture_size;
uniform bool has_leaves = false;
uniform float opening : hint_range(0.0, 1.0) = 0.0;
uniform float lamp_glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 window_left;
uniform vec4 window_right;
uniform float window_rail_y = -128.0;
uniform float window_glow : hint_range(0.0, 1.0) = 0.0;

varying vec2 facade_position;
varying vec4 facade_tint;

void vertex() {
	facade_position = VERTEX;
	facade_tint = COLOR;
}

float window_paper(vec2 pixel, vec4 bounds) {
	vec2 pane = pixel - bounds.xy;
	if (any(lessThan(pane, vec2(0.0))) || any(greaterThanEqual(pane, bounds.zw))) {
		return 0.0;
	}
	// The wood posts lie on every third pixel in the facade atlas.
	float mullions = 1.0 - step(2.0, mod(floor(pane.x), 3.0));
	float rail = step(1.0, abs(floor(pixel.y) - window_rail_y));
	float falloff = 0.72 + 0.28 * sin((pane.y / bounds.w) * PI);
	return mullions * rail * falloff;
}

void fragment() {
	vec2 pixel = floor(facade_position) + vec2(0.5);
	vec2 doorway = (pixel - aperture_origin) / aperture_size;
	if (opening > 0.0 && all(greaterThanEqual(doorway, vec2(0.0))) && all(lessThan(doorway, vec2(1.0)))) {
		float across = abs(doorway.x - 0.5);
		float floor_depth = smoothstep(0.62, 1.0, doorway.y);
		if (has_leaves) {
			// The original painted panels recede about the two jambs.
			float hinge = step(0.5, doorway.x);
			float angle = opening * 1.28;
			float leaf_width = cos(angle);
			float leaf_x = (doorway.x - hinge) / leaf_width;
			float setback = abs(leaf_x) * 8.0 * sin(angle);
			float leaf_y = doorway.y + setback / aperture_size.y;
			if (abs(leaf_x) < 0.5 && leaf_y < 1.0) {
				vec2 source = vec2(hinge + leaf_x, leaf_y);
				vec2 offset = (source - doorway) * aperture_size;
				COLOR.rgb = texture(TEXTURE, UV + offset * TEXTURE_PIXEL_SIZE).rgb * facade_tint.rgb;
				float shaded = mix(0.92, 0.74, hinge);
				COLOR.rgb *= mix(1.0, shaded, opening);
			} else {
				// A dark recess gives way to the first planks inside the threshold.
				float joint = step(1.0, mod(floor(pixel.y), 4.0));
				float light_edge = smoothstep(0.51, 0.93, doorway.y) * (1.0 - across * 0.9);
				vec3 wood = vec3(0.42, 0.32, 0.22) * mix(0.72, 1.0, joint);
				COLOR.rgb = mix(vec3(0.13, 0.11, 0.09), wood, light_edge) * facade_tint.rgb;
			}
		}
		float amber = lamp_glow * floor_depth * (1.0 - smoothstep(0.12, 0.50, across));
		COLOR.rgb += vec3(0.25, 0.15, 0.055) * amber;
	}
	if (window_glow > 0.0) {
		float paper = window_paper(pixel, window_left) + window_paper(pixel, window_right);
		COLOR.rgb += vec3(0.61, 0.34, 0.12) * facade_tint.rgb * paper * window_glow;
	}
}
