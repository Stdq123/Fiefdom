shader_type canvas_item;

#include "res://resources/foliage-breeze.gdshaderinc"

instance uniform float flexibility = 1.0;

void vertex() {
	// Bend the canopy around the plant's foot at local y = 0.
	VERTEX.x -= VERTEX.y * wind_at(MODEL_MATRIX[3].xy) * flexibility;
}
