extends Node2D

@onready var hint: Label = $Hint

var focused := false
var delivered := false
var ready_to_deliver := false

func _ready() -> void:
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.inventory_changed.connect(_refresh.unbind(1))
	GameEvents.crop_harvested.connect(_refresh.unbind(1))
	_refresh()

func _refresh() -> void:
	var schedule := Global.season_order()
	delivered = Global.season_order_delivered_at(schedule) > 0
	ready_to_deliver = Global.can_deliver_season_order(schedule)
	set_interaction_focused(focused)

func set_interaction_focused(active: bool) -> void:
	focused = active
	hint.text = GamepadInput.interact_hint("交货簿") if focused else "交货簿"
	hint.modulate = Color("#ffe8a7") if focused or ready_to_deliver else Color("#d4c298")
	queue_redraw()

func interact() -> void:
	GameEvents.season_board_interacted.emit()

func _draw() -> void:
	draw_rect(Rect2(-13, 0, 28, 3), Color("#23382b80"))
	draw_rect(Rect2(-11, -18, 4, 20), Color("#574532"))
	draw_rect(Rect2(7, -18, 4, 20), Color("#574532"))
	draw_rect(Rect2(-13, -20, 26, 15), Color("#6b5036"))
	draw_rect(Rect2(-11, -18, 22, 11), Color("#97744b"))
	draw_rect(Rect2(-9, -17, 13, 9), Color("#e5cc90") if focused else Color("#c8ad76"))
	draw_rect(Rect2(-7, -15, 8, 1), Color("#87623d"))
	draw_rect(Rect2(-7, -12, 7, 1), Color("#87623d"))
	draw_rect(Rect2(6, -15, 4, 6), Color("#a3be86") if delivered else Color("#dfc283") if ready_to_deliver else Color("#b26950"))
