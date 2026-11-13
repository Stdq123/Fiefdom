extends Node2D

const VISITOR := preload("res://scenes/Visitor.tscn")
const HOST := VisitorData.MUSIC_HOST
const BOOK := preload("res://assets/world/gathering-scorebook.svg")
const GUEST_SPOTS := [Vector2(55, 22), Vector2(89, 28), Vector2(123, 22)]

@onready var guests: Node2D = $Guests
@onready var stall: Sprite2D = $BellRack
@onready var event_sign: Label = $EventSign
@onready var book_hint: Label = $BookHint

var focused := false

func _ready() -> void:
	GameEvents.gathering_recital_recorded.connect(_refresh_book)

func refresh(regular_visitor: VisitorData, retainer_names: Array[String]) -> void:
	var open := Global.is_gathering_day() and Global.outcome == Global.Outcome.RUNNING
	stall.visible = open
	event_sign.visible = open
	for guest in guests.get_children():
		guests.remove_child(guest)
		guest.queue_free()
	if open:
		var occupied := retainer_names.duplicate()
		if regular_visitor:
			occupied.append(regular_visitor.name)
		var road_guest := "林蓼" if VisitorData.ROAD_KEEPER in occupied else VisitorData.ROAD_KEEPER
		var cloth_guest := "阿绥" if VisitorData.SILK_MERCHANT in occupied else VisitorData.SILK_MERCHANT
		_add_guest(road_guest, VisitorData.School.CONFUCIAN, GUEST_SPOTS[0])
		_add_guest(HOST, VisitorData.School.MOHIST, GUEST_SPOTS[1])
		_add_guest(cloth_guest, VisitorData.School.MERCHANT, GUEST_SPOTS[2])
	_refresh_book()

func _add_guest(guest_name: String, school: VisitorData.School, foot: Vector2) -> void:
	var visitor = VISITOR.instantiate()
	visitor.name = guest_name
	visitor.data = VisitorData.from_persona({"name": guest_name, "school": school, "place": "谷雨亭集"})
	visitor.gathering_guest = true
	visitor.position = foot
	visitor.collision_layer = 0
	visitor.collision_mask = 0
	guests.add_child(visitor)

func _refresh_book() -> void:
	visible = stall.visible or not Global.gathering_recitals.is_empty()
	if visible and not is_in_group("interactable"):
		add_to_group("interactable")
	elif not visible and is_in_group("interactable"):
		remove_from_group("interactable")
	var score := Global.gathering_score()
	event_sign.text = "谷雨亭集 · 迎客曲 %d/%d" % [score, Global.GATHERING_BEATS] if score else "谷雨亭集"
	set_interaction_focused(focused and visible)
	queue_redraw()

func set_interaction_focused(active: bool) -> void:
	focused = active
	book_hint.text = GamepadInput.interact_hint("曲簿") if focused else "曲簿"
	book_hint.modulate = Color("#ffe2a4") if focused else Color("#d5c49a")

func interact() -> void:
	if visible:
		GameEvents.gathering_book_requested.emit()

func _draw() -> void:
	draw_texture(BOOK, Vector2(-12, -18))
