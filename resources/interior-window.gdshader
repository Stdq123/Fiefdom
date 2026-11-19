shader_type canvas_item;

uniform vec2 room_origin;
uniform vec2 beam_origin;
uniform float beam_depth = 34.0;
uniform float direct_light : hint_range(0.0, 1.0) = 0.0;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (direct_light > 0.0) {
		// The two rooms share a rear window with four panes across and one crossbar.
		vec2 floor_pixel = floor(world_position - room_origin) + vec2(0.5);
		float depth = floor_pixel.y - beam_origin.y;
		float across = floor_pixel.x - beam_origin.x - depth * 0.43;
		float border_x = 24.0 - abs(across);
		float border_y = min(depth, beam_depth - depth);
		float aperture = smoothstep(0.0, 1.8, min(border_x, border_y));
		float mullion = min(abs(across), min(abs(across - 12.0), abs(across + 12.0)));
		float crossbar = abs(depth - beam_depth * 0.48);
		float pane = mix(0.13, 1.0, smoothstep(0.65, 1.65, min(mullion, crossbar)));
		// Lift the existing wood and fibre colour so the grain shows through the light.
		COLOR.rgb *= vec3(1.0) + vec3(0.38, 0.34, 0.25) * direct_light * aperture * pane;
	}
}
