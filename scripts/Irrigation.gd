extends RefCounted
class_name Irrigation

const SOURCE_CANDIDATES := [Vector2i(1, 5), Vector2i(5, 1), Vector2i(9, 5), Vector2i(5, 9)]
const NEIGHBORS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const UNLOCK_LITERACY_LEVEL := 3

var source_cell: Vector2i = SOURCE_CANDIDATES[0]
var channels: Dictionary[Vector2i, bool] = {}
var _wet_channels: Dictionary[Vector2i, int] = {}

func restore(source: Vector2i, saved_channels: Dictionary[Vector2i, bool]) -> void:
	source_cell = source
	channels = saved_channels
	_update_flow()

func add_channel(cell: Vector2i) -> void:
	add_channels([cell])

func add_channels(cells: Array[Vector2i]) -> void:
	for cell in cells:
		channels[cell] = true
	_update_flow()

func remove_channel(cell: Vector2i) -> bool:
	if not channels.erase(cell):
		return false
	_update_flow()
	return true

func is_channel_wet(cell: Vector2i) -> bool:
	return _wet_channels.has(cell)

func flow_distance(cell: Vector2i) -> int:
	return 0 if cell == source_cell else _wet_channels.get(cell, -1)

func supplies(cell: Vector2i) -> bool:
	return supplied_by(cell, _wet_channels)

static func supplied_by(cell: Vector2i, wet: Dictionary) -> bool:
	for direction: Vector2i in NEIGHBORS:
		if wet.has(cell + direction):
			return true
	return false

func watered_footprint(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			var cell := center + Vector2i(x, y)
			if supplies(cell):
				cells.append(cell)
	return cells

func projected_flow(additions: Array[Vector2i], removal: Variant = null) -> Dictionary[Vector2i, int]:
	var proposed := channels.duplicate()
	for cell in additions:
		proposed[cell] = true
	if removal != null:
		proposed.erase(removal)
	return _reachable(proposed, source_cell)

func repair_gaps(dry_cell: Vector2i) -> Array[Vector2i]:
	var gaps: Array[Vector2i] = []
	if not channels.has(dry_cell) or is_channel_wet(dry_cell):
		return gaps
	for cell in _reachable(channels, dry_cell):
		for direction: Vector2i in NEIGHBORS:
			var gap: Vector2i = cell + direction
			if not channels.has(gap) and gap not in gaps:
				var source_distance := (gap - source_cell).abs()
				if source_distance.x + source_distance.y == 1 or supplies(gap):
					gaps.append(gap)
	return gaps

func _update_flow() -> void:
	_wet_channels = _reachable(channels, source_cell)

static func _reachable(graph: Dictionary[Vector2i, bool], origin: Vector2i) -> Dictionary[Vector2i, int]:
	var reached: Dictionary[Vector2i, int] = {origin: 0}
	var frontier: Array[Vector2i] = [origin]
	var next_index := 0
	while next_index < frontier.size():
		var from := frontier[next_index]
		next_index += 1
		for direction: Vector2i in NEIGHBORS:
			var cell := from + direction
			if graph.has(cell) and not reached.has(cell):
				reached[cell] = reached[from] + 1
				frontier.append(cell)
	if not graph.has(origin):
		reached.erase(origin)
	return reached
