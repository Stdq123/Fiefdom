extends Node2D

const LANDSCAPE := preload("res://scripts/Landscape.gd")
const RUSH_FRAME := LANDSCAPE.EXTERNAL_REGIONS[LANDSCAPE.Prop.RAVINE_RUSH]
const TUFTS := [
	Vector2(-33, -7), Vector2(-19, 12), Vector2(-7, -15), Vector2(9, -2),
	Vector2(24, 10), Vector2(37, -8), Vector2(31, -24), Vector2(14, -26),
]
const SUMMER_TINT := Color("#b9c68c")
const AUTUMN_TINT := Color("#d4b66b")

var focused := false
@onready var hint: Label = $Hint

func _ready() -> void:
	GameEvents.sheepfold_changed.connect(_refresh)
	GamepadInput.changed.connect(_refresh)
	_refresh()

func can_interact_from(foot: Vector2) -> bool:
	return foot.distance_squared_to(global_position) <= 28.0 * 28.0

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh()

func _refresh() -> void:
	hint.text = GamepadInput.interact_hint("割草") if focused and Global.can_cut_meadow_grass() else Sheepfold.MEADOW
	if focused:
		hint.text += "\n" + Global.meadow_status()
	hint.modulate = Color("#ffe3aa") if focused else Color("#e0d8b4")
	queue_redraw()

func interact() -> void:
	var road := get_parent()
	if Global.cut_meadow_grass():
		road.player.show_action(ToolGesture.Action.HARVEST, global_position)
	else:
		GameEvents.world_notice.emit(Global.meadow_status())
	road.finish_meadow_route()

func _draw() -> void:
	var uncut := Global.meadow_has_grass()
	var tint := AUTUMN_TINT if Global.season_index() == Global.Season.AUTUMN else SUMMER_TINT
	var dormant := Color("#a1a586") if Global.season_index() == Global.Season.WINTER else tint.darkened(0.17)
	for index in TUFTS.size():
		var foot: Vector2 = TUFTS[index]
		var tall := uncut and index != 1
		var size := RUSH_FRAME.size if tall else Vector2(16, 8)
		var at := (foot - Vector2(size.x * 0.5, size.y - 2)).round()
		draw_rect(Rect2(foot - Vector2(8, 1), Vector2(16, 4)), Color("#293b2e90"))
		if tall:
			draw_texture_rect_region(LANDSCAPE.RAVINE_ACCENTS, Rect2(at, size), RUSH_FRAME, tint)
			for stem in 3:
				var tip := at + Vector2(4 + stem * 6, 4 + posmod(stem * 5 + index, 7))
				draw_rect(Rect2(tip, Vector2(2, 3)), tint.lightened(0.33))
		else:
			for stem in 5:
				var stalk := foot + Vector2(-7 + stem * 3, -3 - posmod(stem + index, 3))
				draw_rect(Rect2(stalk, Vector2(2, 2 + posmod(stem + index, 3))), dormant)
