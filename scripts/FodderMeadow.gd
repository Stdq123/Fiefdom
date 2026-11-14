extends Node2D

const TUFTS := [
	Vector2(-34, -15), Vector2(-21, -23), Vector2(-6, -17), Vector2(10, -24),
	Vector2(29, -18), Vector2(38, -4), Vector2(25, 14), Vector2(41, 13),
	Vector2(9, 20), Vector2(-9, 17), Vector2(-26, 13), Vector2(-39, 9),
]
const LEAF_COLORS := [Color("#79864c"), Color("#98aa61"), Color("#b29755"), Color("#8f9e8a")]
const SEED_COLORS := [Color("#bac27a"), Color("#d5cb89"), Color("#dac08a"), Color("#bac6b9")]

var focused := false
var tufts: Array[Node2D] = []
@onready var hint: Label = $Hint

func _ready() -> void:
	y_sort_enabled = true
	for index in TUFTS.size():
		var tuft := Node2D.new()
		tuft.position = TUFTS[index]
		tuft.draw.connect(_draw_tuft.bind(tuft, index))
		add_child(tuft)
		tufts.append(tuft)
	var tool_stone := StaticBody2D.new()
	tool_stone.name = "ToolStone"
	tool_stone.position = Vector2(22, -5)
	tool_stone.collision_mask = 0
	var base := RectangleShape2D.new()
	base.size = Vector2(19, 8)
	var collider := CollisionShape2D.new()
	collider.shape = base
	tool_stone.add_child(collider)
	tool_stone.draw.connect(_draw_tool_stone.bind(tool_stone))
	add_child(tool_stone)
	GameEvents.sheepfold_changed.connect(_refresh)
	GamepadInput.changed.connect(_refresh)
	_refresh()

func can_interact_from(foot: Vector2) -> bool:
	return foot.distance_squared_to(global_position) <= 28.0 * 28.0

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh()

func _refresh() -> void:
	hint.visible = focused
	if focused:
		var action := GamepadInput.interact_hint("割草") if Global.can_cut_meadow_grass() else Sheepfold.MEADOW
		hint.text = action + "\n" + Global.meadow_status()
	for tuft in tufts:
		tuft.queue_redraw()

func interact() -> void:
	var road := get_parent()
	if Global.cut_meadow_grass():
		road.player.show_action(ToolGesture.Action.HARVEST, global_position)
	else:
		GameEvents.world_notice.emit(Global.meadow_status())
	road.finish_meadow_route()

func _draw_tuft(tuft: Node2D, index: int) -> void:
	var season := Global.season_index()
	var uncut := Global.meadow_has_grass()
	var cut := not uncut and season in [Global.Season.SUMMER, Global.Season.AUTUMN]
	var leaf: Color = LEAF_COLORS[season]
	var seed_color: Color = SEED_COLORS[season]
	if Global.has_rain():
		leaf = leaf.darkened(0.12)
		seed_color = seed_color.darkened(0.10)
	tuft.draw_colored_polygon(PackedVector2Array([
		Vector2(-11, 0), Vector2(-7, -3), Vector2(5, -4), Vector2(13, -1), Vector2(11, 3), Vector2(-1, 5),
	]), Color("#2c402e66"))
	for stem in range(7):
		var seed := posmod(index * 17 + stem * 11, 19)
		var base := Vector2(-9 + stem * 3, seed % 5 - 2)
		if uncut:
			var tip := base + Vector2(stem - 3, -(11 + seed % 12))
			var side := base.lerp(tip, 0.58).round()
			tuft.draw_colored_polygon(PackedVector2Array([base + Vector2(-1, 0), side + Vector2(-2, -1), tip,
				side + Vector2(1, 1), base + Vector2(1, 1)]), leaf.darkened(0.13 + (seed % 3) * 0.09))
			tuft.draw_line(base, side + Vector2(0, -1), leaf, 1.0)
			if seed % 3 != 1:
				tuft.draw_rect(Rect2(tip - Vector2(1, 2), Vector2(2, 5)), seed_color.darkened((seed % 4) * 0.07))
				tuft.draw_rect(Rect2(tip - Vector2(1, 2), Vector2(1, 2)), seed_color)
		else:
			var top := base - Vector2(0, 2 + seed % 4)
			tuft.draw_line(base, top, leaf.darkened(0.19), 1.0)
			if cut or season == Global.Season.WINTER:
				tuft.draw_rect(Rect2(top, Vector2(2, 1)), seed_color)
			else:
				tuft.draw_line(top, top + Vector2(-2, -1), leaf, 1.0)

func _draw_tool_stone(stone: Node2D) -> void:
	stone.draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(-5, -5), Vector2(12, -3),
		Vector2(16, 1), Vector2(11, 5), Vector2(-6, 4)]), Color("#273b2f80"))
	stone.draw_colored_polygon(PackedVector2Array([Vector2(-12, -7), Vector2(11, -7), Vector2(10, 0),
		Vector2(4, 3), Vector2(-8, 2), Vector2(-13, -1)]), Color("#6e6651"))
	stone.draw_colored_polygon(PackedVector2Array([Vector2(-13, -7), Vector2(-8, -12), Vector2(6, -13),
		Vector2(12, -8), Vector2(6, -4), Vector2(-7, -4)]), Color("#a89d79"))
	stone.draw_line(Vector2(-8, -11), Vector2(5, -12), Color("#c5b991"), 1.0)
	stone.draw_line(Vector2(5, -4), Vector2(-4, -11), Color("#6f4c31"), 3.0)
	stone.draw_line(Vector2(4, -5), Vector2(-4, -11), Color("#bf915b"), 1.0)
	stone.draw_colored_polygon(PackedVector2Array([Vector2(-5, -10), Vector2(-8, -13), Vector2(-3, -17),
		Vector2(4, -17), Vector2(0, -15), Vector2(-3, -11)]), Color("#cebd8e"))
	stone.draw_line(Vector2(-7, -13), Vector2(-3, -16), Color("#eee0b2"), 1.0)
