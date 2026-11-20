extends Node2D

const CROSS_LIGHT := Vector2(0.76, -0.18)
const MORNING_REACH := Vector2(0.92, 0.37)
const NOON_REACH := Vector2(0.29, 0.23)
const AFTERNOON_REACH := Vector2(0.64, 0.65)

var trees: Array[Sprite2D] = []
var _time := -1.0

func _ready() -> void:
	name = "TreeShadows"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Let the map update the daylight clock before sampling the sun.
	process_priority = 1
	GameEvents.daylight_changed.connect(refresh)
	GameEvents.day_advanced.connect(refresh.unbind(1))
	GameEvents.estate_room_changed.connect(refresh.unbind(1))
	refresh()

func track(tree: Sprite2D) -> void:
	trees.append(tree)
	tree.visibility_changed.connect(queue_redraw)
	tree.texture_changed.connect(queue_redraw)
	queue_redraw()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	var time := snappedf(Global.day_progress, 0.002)
	visible = time < 0.83 and not Global.is_indoors() and Global.weather_on() == Global.Weather.CLEAR
	if visible and not is_equal_approx(time, _time):
		_time = time
		queue_redraw()

static func reach_at(time: float) -> Vector2:
	var reach := MORNING_REACH.lerp(NOON_REACH, smoothstep(0.03, 0.41, time))
	return reach.lerp(AFTERNOON_REACH, smoothstep(0.41, 0.75, time))

func _draw() -> void:
	var reach := reach_at(_time)
	var sun := lerpf(0.62, 1.0, smoothstep(0.0, 0.16, _time))
	sun *= 1.0 - smoothstep(0.60, 0.83, _time)
	var ink := Color(0.0, 0.0, 0.0, 0.26 * sun)
	var map_to_shadows := global_transform.affine_inverse()
	for tree in trees:
		if not is_instance_valid(tree) or not tree.is_visible_in_tree() or not tree.texture:
			continue
		var pose := map_to_shadows * tree.global_transform
		# The sprite's origin marks its roots. Negative local y is height above them.
		var ground := Transform2D(CROSS_LIGHT, -reach, pose.origin)
		pose.origin = Vector2.ZERO
		draw_set_transform_matrix(ground * pose)
		draw_texture_rect(tree.texture, tree.get_rect(), false, ink)
	draw_set_transform_matrix(Transform2D.IDENTITY)
