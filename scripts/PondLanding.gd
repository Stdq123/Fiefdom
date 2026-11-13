extends "res://scripts/FishingSpot.gd"

const BOARD := Color("#ab875d")
const TIMBER := Color("#604c38")

func _ready() -> void:
	site = CreekFish.Site.POND
	water = Vector2(40, -1)
	super._ready()
	visible = Global.pond_landing_day() > 0
	set_process(not visible)

func _process(_delta: float) -> void:
	if Global.pond_landing_day() > 0:
		show()
		set_process(false)
		GameEvents.pond_landing_opened.emit()

func can_interact_from(foot: Vector2) -> bool:
	return not Global.is_indoors() and super.can_interact_from(foot)

func _draw() -> void:
	draw_rect(Rect2(9, -5, 26, 16), Color("#293e34a6"))
	draw_rect(Rect2(5, -9, 28, 16), TIMBER)
	for x in range(6, 33, 4):
		draw_rect(Rect2(x, -8, 3, 13), BOARD.darkened(0.06 * (x % 3)))
		draw_rect(Rect2(x, -7, 1, 5 + x % 5), Color("#c5a170"))
	for post: Vector2 in [Vector2(7, 5), Vector2(29, 4), Vector2(30, -8)]:
		draw_rect(Rect2(post - Vector2(1, 7), Vector2(3, 9)), TIMBER)
		draw_rect(Rect2(post - Vector2(1, 7), Vector2(3, 2)), Color("#d2b487"))
	super._draw()
