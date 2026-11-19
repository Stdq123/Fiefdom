uniform float wind_phase = 0.0;
uniform float wind_strength = 0.0;

float wind_at(vec2 world_position) {
	float distance_phase = dot(world_position, vec2(0.021, 0.013));
	float breeze = sin(2.0 * wind_phase - distance_phase);
	float gust = sin(3.0 * wind_phase - 0.6 * distance_phase + 0.8);
	return (0.74 * breeze + 0.26 * gust) * wind_strength;
}
