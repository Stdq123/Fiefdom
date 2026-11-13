extends Sprite2D

const PROPS := preload("res://assets/world/ending-ceremonies.svg")
const TRIBUTE_POINT := Vector2(-86, 69)
const TAX_POINT := EstateLayout.SOUTH_PAVILION + Vector2(67, 22)

@onready var hint: Label = $Hint

var record_name := ""
var place_name := ""
var archived := false
var ready_to_present := false

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
	archived = not Global.ending_record.is_empty() and Global.outcome == Global.Outcome.RUNNING
	ready_to_present = Global.route_ready_to_present()
	if not (archived or ready_to_present):
		hide()
		hint.hide()
		remove_from_group("interactable")
		return
	if visible:
		return
	var traditional := Global.tax_reform_choice == Global.TaxReformChoice.TRADITIONAL
	if archived:
		traditional = Global.ending_record["outcome"] == Global.Outcome.TRADITIONAL
	record_name = "贡簿" if traditional else "新税册"
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

func can_interact_from(at: Vector2) -> bool:
	return global_position.distance_squared_to(at) <= 25.0 * 25.0

func set_interaction_focused(focused: bool) -> void:
	hint.visible = focused
	if focused:
		hint.text = GamepadInput.interact_hint(record_name if archived else "呈交" + record_name)

func interact() -> void:
	if archived:
		GameEvents.ending_record_requested.emit()
	elif ready_to_present:
		Global.present_route_ledger()
