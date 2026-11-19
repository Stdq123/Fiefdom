shader_type canvas_item;

#include "res://resources/foliage-breeze.gdshaderinc"

varying vec2 world_position;
varying vec4 tile_modulate;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tile_modulate = COLOR;
}

void fragment() {
	vec2 tile = (UV - REGION_RECT.xy) / REGION_RECT.zw;
	// Keep the roots and shadow in the bottom quarter of each atlas tile fixed.
	float height = max(0.0, 0.75 - tile.y);
	// Taper near the edges so the sampling stays inside this crop's atlas region.
	float edge = smoothstep(0.0, 0.20, min(tile.x, 1.0 - tile.x));
	float bend = 2.6 * height * height * edge * wind_at(world_position);
	vec2 bent_uv = UV - vec2(bend * REGION_RECT.z, 0.0);
	COLOR = tile_modulate * texture(TEXTURE, bent_uv);
}
