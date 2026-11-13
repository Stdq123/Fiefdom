extends Node2D

const TUFTS := [
	Vector2(-33, -11), Vector2(-23, 11), Vector2(-7, -15), Vector2(18, -10),
	Vector2(25, 14), Vector2(37, -8), Vector2(33, -24), Vector2(12, -26),
	Vector2(-38, 4), Vector2(-21, -23), Vector2(11, 18),
]
const SUMMER_TINT := Color("#8d9e62")
const AUTUMN_TINT := Color("#ba9b52")

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
	var dormant := Color("#a1a586") if Global.season_index() == Global.Season.WINTER else tint.darkened(0.20)
	for index in TUFTS.size():
		var foot: Vector2 = TUFTS[index]
		draw_rect(Rect2(foot - Vector2(8, 1), Vector2(16, 3)), Color("#293b2e58"))
		for stem in 5:
			var base := foot + Vector2(-7 + stem * 3, posmod(index + stem * 3, 3) - 1)
			var seed := posmod(index * 17 + stem * 11, 19)
			if uncut:
				var height := 8 + seed % 11
				var tip := base + Vector2(stem - 2, -height)
				var color := tint.lerp(Color("#66643d"), 0.23 if seed % 3 == 0 else 0.04)
				draw_polyline(PackedVector2Array([base, base.lerp(tip, 0.55).round(), tip]), color, 1.0)
				if seed % 4 != 1:
					draw_rect(Rect2(tip - Vector2(1, 2), Vector2(2, 4 + seed % 3)), color.lightened(0.28))
			else:
				draw_rect(Rect2(base - Vector2(0, 2 + seed % 3), Vector2(1, 3 + seed % 3)), dormant)
