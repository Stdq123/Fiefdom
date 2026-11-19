extends Node2D

const LANDSCAPE := preload("res://scripts/Landscape.gd")
const WIND := preload("res://scripts/FoliageWind.gd")
const GRASS := preload("res://assets/world/pasture-details.png")
const GRASS_CELL := Vector2(28, 28)
const TOOL_STONE_ART := LANDSCAPE.ESTATE_SITE_REGIONS[LANDSCAPE.Prop.MOSS_STONE]
const TUFTS := [
	Vector2(-34, -15), Vector2(-21, -23), Vector2(-6, -17), Vector2(10, -24),
	Vector2(29, -18), Vector2(38, -4), Vector2(25, 14), Vector2(41, 13),
	Vector2(9, 20), Vector2(-9, 17), Vector2(-26, 13), Vector2(-39, 9),
]
var focused := false
var tufts: Array[Sprite2D] = []
@onready var hint: Label = $Hint

func _ready() -> void:
	y_sort_enabled = true
	var wind := WIND.new()
	add_child(wind)
	for index in TUFTS.size():
		var tuft := Sprite2D.new()
		tuft.position = TUFTS[index]
		tuft.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tuft.texture = GRASS
		tuft.region_enabled = true
		tuft.region_filter_clip_enabled = true
		tuft.centered = false
		tuft.offset = Vector2(-14, -25.5)
		add_child(tuft)
		wind.attach(tuft, WIND.STEM)
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
	GameEvents.day_advanced.connect(_refresh.unbind(1))
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
	var season := Global.season_index()
	var row := season + 3 if season in [Global.Season.SUMMER, Global.Season.AUTUMN] and not Global.meadow_has_grass() else season
	var tint := Color("#bec9ba") if Global.has_rain() else Color.WHITE
	for index in tufts.size():
		var tuft := tufts[index]
		var variant := (index + floori(index / 4.0)) % 3
		tuft.region_rect = Rect2(Vector2(variant, row) * GRASS_CELL, GRASS_CELL)
		tuft.self_modulate = tint

func interact() -> void:
	var road := get_parent()
	if Global.cut_meadow_grass():
		road.player.show_action(ToolGesture.Action.HARVEST, global_position)
	else:
		GameEvents.world_notice.emit(Global.meadow_status())
	road.finish_meadow_route()

func _draw_tool_stone(stone: Node2D) -> void:
	stone.draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(-5, -5), Vector2(12, -3),
		Vector2(16, 1), Vector2(11, 5), Vector2(-6, 4)]), Color("#273b2f80"))
	var tint := Color("#c1cfcc") if Global.has_rain() else Color.WHITE
	if Global.season_index() == Global.Season.WINTER:
		tint *= LANDSCAPE.WINTER_ROCK_TINT
	stone.draw_texture_rect_region(LANDSCAPE.ESTATE_ART, Rect2(Vector2(-16, -28), TOOL_STONE_ART.size),
		TOOL_STONE_ART, tint)
	stone.draw_line(Vector2(5, -4), Vector2(-4, -11), Color("#6f4c31"), 3.0)
	stone.draw_line(Vector2(4, -5), Vector2(-4, -11), Color("#bf915b"), 1.0)
	stone.draw_colored_polygon(PackedVector2Array([Vector2(-5, -10), Vector2(-8, -13), Vector2(-3, -17),
		Vector2(4, -17), Vector2(0, -15), Vector2(-3, -11)]), Color("#cebd8e"))
	stone.draw_line(Vector2(-7, -13), Vector2(-3, -16), Color("#eee0b2"), 1.0)
