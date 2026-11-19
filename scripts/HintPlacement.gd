extends RefCounted
class_name HintPlacement

static func around(at: Vector2, subject: Rect2, size: Vector2, bounds: Rect2,
		occupied: Array[Rect2], below_first := false) -> Vector2:
	var minimum := bounds.position.ceil()
	var maximum := (bounds.end - size).floor()
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Vector2.INF
	var center := (at - size * 0.5).round().clamp(minimum, maximum)
	var above := Vector2(center.x, floorf(subject.position.y - size.y))
	var below := Vector2(center.x, ceilf(subject.end.y))
	var right := Vector2(ceilf(subject.end.x), center.y)
	var left := Vector2(floorf(subject.position.x - size.x), center.y)
	for anchor: Vector2 in [below if below_first else above, above if below_first else below, right, left]:
		var candidate := Rect2(anchor, size)
		if bounds.encloses(candidate) and is_clear(candidate, occupied):
			return anchor

	# Try the edges of the blockers when the four sides of the subject are occupied.
	var columns := PackedFloat32Array([center.x, minimum.x, maximum.x])
	var rows := PackedFloat32Array([center.y, minimum.y, maximum.y])
	for blocker in occupied:
		columns.append(clampf(floorf(blocker.position.x - size.x), minimum.x, maximum.x))
		columns.append(clampf(ceilf(blocker.end.x), minimum.x, maximum.x))
		rows.append(clampf(floorf(blocker.position.y - size.y), minimum.y, maximum.y))
		rows.append(clampf(ceilf(blocker.end.y), minimum.y, maximum.y))
	var best := Vector2.INF
	var distance := INF
	for y in rows:
		for x in columns:
			var point := Vector2(x, y)
			var gap := at.distance_squared_to(point + size * 0.5)
			if gap < distance and is_clear(Rect2(point, size), occupied):
				best = point
				distance = gap
	return best

static func is_clear(rect: Rect2, occupied: Array[Rect2]) -> bool:
	for blocker in occupied:
		if blocker.intersects(rect):
			return false
	return true
