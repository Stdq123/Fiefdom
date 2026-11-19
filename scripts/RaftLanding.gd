extends Node2D
class_name RaftLanding

signal trial_requested

const LANDSCAPE := preload("res://scripts/Landscape.gd")
const DECK_ART := preload("res://assets/world/raft-landing.svg")

@onready var hint: Label = $Hint
@onready var host: Texture2D = CharacterArt.visitor(VisitorData.School.MOHIST)
@onready var raft_idle: Texture2D = load("res://assets/world/sevarihk/floss-idle-no-sail-transp.png")
@onready var raft_move: Texture2D = load("res://assets/world/sevarihk/floss-move-no-sail-transp.png")

var open_today := false
var focused := false
var boat_away := false
var animation_time := 0.0
var idle_frame := 0

func _ready() -> void:
	position = SummerRaft.LANDING
	open_today = Global.is_summer_raft_day()
	set_process(open_today)
	set_interaction_focused(false)

func can_interact_from(point: Vector2) -> bool:
	return global_position.distance_squared_to(point) <= 22.0 * 22.0

func set_interaction_focused(active: bool) -> void:
	focused = active
	hint.text = GamepadInput.interact_hint(SummerRaft.PLACE) if focused else (SummerRaft.TITLE if open_today else SummerRaft.PLACE)
	hint.modulate = Color("#ffdfa0") if focused else Color("#d9d9a8")

func interact() -> void:
	trial_requested.emit()

func set_boat_away(away: bool) -> void:
	boat_away = away
	queue_redraw()

func draw_boat(surface: CanvasItem, point: Vector2, frame: int, moving: bool) -> void:
	# The first row faces downstream. Preserve the same hull origin in both sheets.
	var source := Rect2(27 + 163 * (frame % 4), 62, 115, 139)
	surface.draw_texture_rect_region(raft_move if moving else raft_idle,
		Rect2(point.round() - Vector2(10, 14), Vector2(20, 27)), source)

func _process(delta: float) -> void:
	animation_time = fposmod(animation_time + delta, 1.2)
	var next := int(animation_time / 0.3)
	if idle_frame != next:
		idle_frame = next
		queue_redraw()

func _draw() -> void:
	var tint := Color(0.88, 0.94, 0.99) if Global.has_rain() else Color.WHITE
	draw_texture(DECK_ART, Vector2(-10, -12), tint)
	var pennant := Color("#b35841") if open_today else Color("#88866c")
	draw_rect(Rect2(7, -29, 2, 25), Color("#6f5236"))
	draw_colored_polygon(PackedVector2Array([Vector2(9, -28), Vector2(23, -26), Vector2(19, -21),
		Vector2(22, -16), Vector2(9, -18)]), pennant)
	draw_rect(Rect2(10, -27, 9, 1), pennant.lightened(0.3))
	if open_today:
		draw_texture(host, Vector2(-26, -47))
		if not boat_away:
			var boat := Vector2(LANDSCAPE.creek_x(SummerRaft.START_Y) - 4, SummerRaft.START_Y) - position
			draw_line(Vector2(28, 6), boat + Vector2(-4, 5), Color("#ceaf76"), 1.0)
			draw_boat(self, boat, idle_frame, false)
