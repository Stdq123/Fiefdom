shader_type canvas_item;

instance uniform float shoulder_lift = 0.0;

varying float body_y;
varying vec4 body_tint;

void vertex() {
	body_y = VERTEX.y;
	body_tint = COLOR;
}

void fragment() {
	if (shoulder_lift > 0.0) {
		// Convert a local-pixel rise to the current frame's atlas coordinates.
		vec2 y_axis = vec2(dFdx(body_y), dFdy(body_y));
		vec2 uv_axis = vec2(dFdx(UV.y), dFdy(UV.y));
		float uv_per_pixel = dot(uv_axis, y_axis) / max(dot(y_axis, y_axis), 0.000001);
		float upper_body = 1.0 - smoothstep(-6.0, 6.0, body_y);
		if (upper_body > 0.0) {
			COLOR = body_tint * texture(TEXTURE, UV + vec2(0.0, shoulder_lift * upper_body * uv_per_pixel));
		}
	}
}
