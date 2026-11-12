extends Node2D

const APPROACH := Vector2(-18, -23)

signal opened()

@onready var sign: Label = $Sign

var focused := false

func _ready() -> void:
	GameEvents.inventory_changed.connect(_refresh.unbind(1))
	GameEvents.fish_changed.connect(_refresh)
	_refresh()

func can_interact_from(foot: Vector2) -> bool:
	var at := to_local(foot)
	return absf(at.x) <= 43.0 and absf(at.y) <= 28.0

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh()

func _refresh() -> void:
	var schedule := Global.season_order()
	var delivered := Global.season_order_delivered_at(schedule) > 0
	var ready := Global.can_deliver_season_order(schedule)
	var status := "已交货" if delivered else "可交货" if ready else "时令收货"
	sign.text = "%s  %s" % [GamepadInput.interact_key(), status] if focused else status
	sign.modulate = Color("#c8dfa5") if delivered else Color("#ffe4a1") if focused or ready else Color("#e5d9af")

func interact() -> void:
	opened.emit()
