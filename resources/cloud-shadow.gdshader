shader_type canvas_item;
render_mode unshaded;

uniform sampler2D cloud_cover : filter_linear, repeat_enable, hint_default_black;
uniform vec2 cloud_offset;
uniform float shadow_strength = 0.0;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 sky = world_position / vec2(720.0, 470.0) - cloud_offset;
	float cover = smoothstep(0.43, 0.71, texture(cloud_cover, sky).r);
	COLOR = vec4(vec3(0.094, 0.141, 0.180), cover * shadow_strength);
}
