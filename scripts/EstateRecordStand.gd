extends Sprite2D

const PROPS := preload("res://assets/world/ending-ceremonies.svg")

@onready var hint: Label = $Hint

var record_name := ""
var place_name := ""

func _ready() -> void:
	if Global.ending_record.is_empty() or Global.outcome != Global.Outcome.RUNNING:
		return
	var traditional: bool = Global.ending_record["outcome"] == Global.Outcome.TRADITIONAL
	record_name = "贡簿" if traditional else "新税册"
	place_name = "堂前" if traditional else "南路亭"
	position = Vector2(-86, 69) if traditional else Vector2(144, 269)
	var artwork := AtlasTexture.new()
	artwork.atlas = PROPS
	artwork.region = Rect2(3, 18, 35, 23) if traditional else Rect2(75, 21, 45, 18)
	artwork.filter_clip = true
	texture = artwork
	offset.y = -artwork.region.size.y * 0.5
	show()
	add_to_group("interactable")

func can_interact_from(at: Vector2) -> bool:
	return global_position.distance_squared_to(at) <= 25.0 * 25.0

func set_interaction_focused(focused: bool) -> void:
	hint.visible = focused
	if focused:
		hint.text = GamepadInput.interact_hint(record_name)

func interact() -> void:
	GameEvents.ending_record_requested.emit()
