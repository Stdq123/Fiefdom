shader_type canvas_item;

uniform float wind_phase = 0.0;
uniform float wind_strength = 0.0;
instance uniform float flexibility = 1.0;

void vertex() {
	vec2 root = MODEL_MATRIX[3].xy;
	float distance_phase = dot(root, vec2(0.021, 0.013));
	float breeze = sin(2.0 * wind_phase - distance_phase);
	float gust = sin(3.0 * wind_phase - 0.6 * distance_phase + 0.8);
	// Bend the canopy around the plant's foot at local y = 0.
	VERTEX.x -= VERTEX.y * (0.74 * breeze + 0.26 * gust) * wind_strength * flexibility;
}
