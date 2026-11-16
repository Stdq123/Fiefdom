extends Sprite2D

signal readiness_changed(ready: bool)

const PROPS := preload("res://assets/world/ending-ceremonies.svg")
const SACKS := preload("res://assets/world/estate-vessels.png")
const TRIBUTE_POINT := Vector2(-120, 76)
const TAX_POINT := EstateLayout.SOUTH_PAVILION + Vector2(67, 22)

@onready var hint: Label = $Hint

var record_name := ""
var place_name := ""
var archived := false
var ready_to_present := false
var harvest_mark := false
var focused := false

func _ready() -> void:
	GameEvents.tax_reform_choice_made.connect(_refresh.unbind(1))
	GameEvents.crop_harvested.connect(_refresh.unbind(1))
	GameEvents.money_changed.connect(_refresh.unbind(1))
	GameEvents.silk_changed.connect(_refresh)
	GameEvents.raid_defeated.connect(_refresh)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.campaign_ended.connect(_refresh.unbind(1))
	_refresh()

func _refresh() -> void:
	var was_ready := ready_to_present
	archived = not Global.ending_record.is_empty() and Global.outcome == Global.Outcome.RUNNING
	ready_to_present = Global.route_ready_to_present()
	var in_progress := Global.outcome == Global.Outcome.RUNNING \
		and Global.tax_reform_choice in [Global.TaxReformChoice.TRADITIONAL, Global.TaxReformChoice.REFORMED]
	if archived or in_progress:
		var traditional := Global.tax_reform_choice == Global.TaxReformChoice.TRADITIONAL
		if archived:
			traditional = Global.ending_record["outcome"] == Global.Outcome.TRADITIONAL
		var title := "贡簿" if traditional else "新税册"
		if not visible or record_name != title:
			_set_desk(traditional, title)
		var has_harvest := not Global.route_harvest.is_empty()
		if harvest_mark != has_harvest:
			harvest_mark = has_harvest
			queue_redraw()
		_refresh_hint()
	else:
		hide()
		hint.hide()
		focused = false
		remove_from_group("interactable")
	if ready_to_present != was_ready:
		readiness_changed.emit(ready_to_present)

func _set_desk(traditional: bool, title: String) -> void:
	record_name = title
	place_name = "堂前" if traditional else "南路亭"
	position = TRIBUTE_POINT if traditional else TAX_POINT
	var artwork := AtlasTexture.new()
	artwork.atlas = PROPS
	artwork.region = Rect2(3, 18, 35, 23) if traditional else Rect2(75, 21, 45, 18)
	artwork.filter_clip = true
	texture = artwork
	offset.y = -artwork.region.size.y * 0.5
	add_to_group("interactable")
	show()

func _draw() -> void:
	if harvest_mark:
		var x := 15.0 if record_name == "贡簿" else 18.0
		var bag := Rect2(x, -12, 15, 15)
		draw_rect(Rect2(x + 2, 0, 13, 3), Color("#28332880"))
		draw_texture_rect_region(SACKS, bag, Rect2(16, 0, 16, 16))

func can_interact_from(at: Vector2) -> bool:
	return global_position.distance_squared_to(at) <= 25.0 * 25.0

func set_interaction_focused(active: bool) -> void:
	focused = active
	_refresh_hint()

func _refresh_hint() -> void:
	hint.visible = focused
	if focused:
		hint.text = GamepadInput.interact_hint(("呈交" if ready_to_present else "翻看") + record_name)

func interact() -> void:
	if archived:
		GameEvents.ending_record_requested.emit()
	elif ready_to_present:
		Global.present_route_ledger()
	else:
		GameEvents.route_ledger_read_requested.emit()
