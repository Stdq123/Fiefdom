extends Node2D

const LACQUER := [Color("#6e7163"), Color("#9e5039"), Color("#47736b"), Color("#77596d"), Color("#9a7740")]
const OCCLUSION := Rect2(-14, -23, 28, 23)

@onready var hint: Label = $Hint
@onready var player: Player = $"../../Player"

func _ready() -> void:
	GameEvents.rank_changed.connect(_refresh.unbind(1))
	GameEvents.campaign_ended.connect(_refresh.unbind(1))
	_refresh()

func _refresh() -> void:
	visible = Global.has_rank_book()
	set_process(visible)
	if visible:
		add_to_group("interactable")
		queue_redraw()
	else:
		remove_from_group("interactable")
		hint.hide()

func _process(delta: float) -> void:
	var behind := OCCLUSION.has_point(to_local(player.global_position))
	self_modulate.a = move_toward(self_modulate.a, 0.56 if behind else 1.0, delta * 6.0)

func _draw() -> void:
	var lacquer: Color = LACQUER[Global.current_rank]
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(13, -2),
		Vector2(22, 3), Vector2(14, 6), Vector2(-10, 5)]), Color("#29352882"))
	# The timber feet sit on a stone sill, with the front and top lit separately.
	draw_rect(Rect2(-13, -2, 25, 4), Color("#686552"))
	draw_colored_polygon(PackedVector2Array([Vector2(-13, -2), Vector2(12, -2),
		Vector2(16, -6), Vector2(-9, -6)]), Color("#9e9276"))
	draw_colored_polygon(PackedVector2Array([Vector2(12, -2), Vector2(16, -6),
		Vector2(16, -2), Vector2(12, 2)]), Color("#504e44"))
	for x: float in [-10.0, 7.0]:
		draw_rect(Rect2(x, -24, 4, 22), Color("#664b35"))
		draw_rect(Rect2(x, -22, 1, 19), Color("#b28a5d"))
		draw_line(Vector2(x + 4, -3), Vector2(x + 7, -6), Color("#433a2d"), 2.0)
	# The frame has a forward eave and a visible right-hand end grain.
	draw_colored_polygon(PackedVector2Array([Vector2(-15, -24), Vector2(13, -24),
		Vector2(16, -29), Vector2(-11, -29)]), Color("#b68a57"))
	draw_line(Vector2(-11, -27), Vector2(13, -27), Color("#cd9e67"), 1.0)
	draw_rect(Rect2(-15, -24, 28, 4), Color("#745137"))
	draw_colored_polygon(PackedVector2Array([Vector2(13, -24), Vector2(16, -29),
		Vector2(16, -25), Vector2(13, -20)]), Color("#52402f"))
	draw_rect(Rect2(-9, -21, 19, 15), lacquer.darkened(0.28))
	draw_rect(Rect2(-8, -20, 17, 13), lacquer)
	for slip: int in 4:
		var x := -6.0 + 3.0 * slip
		draw_rect(Rect2(x, -18, 2, 9), Color("#d7b67a") if slip % 2 == 0 else Color("#c49a60"))
		draw_rect(Rect2(x, -16 + slip % 2, 1, 4), Color("#795439"))
	draw_line(Vector2(-7, -17), Vector2(5, -17), Color("#856044"), 1.0)
	draw_rect(Rect2(5, -13, 3, 3), Color("#e3b564"))

func can_interact_from(foot: Vector2) -> bool:
	return visible and not Global.is_indoors() and foot.distance_squared_to(global_position) <= 18.0 * 18.0

func set_interaction_focused(active: bool) -> void:
	hint.visible = active
	if active:
		hint.text = GamepadInput.interact_hint("翻看爵册")

func interact() -> void:
	GameEvents.rank_book_requested.emit()
