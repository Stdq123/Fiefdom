extends Node2D

const BELL := preload("res://assets/audio/music/bronze-bell.wav")
const SHARING := "res://assets/world/autumn-sharing.svg"

@onready var samples: Node2D = $Samples
@onready var guests: Node2D = $Guests
@onready var hint: Label = $Hint

var record: Dictionary = {}
var display_time := -1.0

func _ready() -> void:
	var mat := AtlasTexture.new()
	mat.atlas = load(SHARING)
	mat.region = Rect2(0, 0, 96, 32)
	mat.filter_clip = true
	$ReedMat.texture = mat
	var lighting = $"../Landscape".day_lighting
	lighting.place_lamp($Lanterns, Vector2(29, 79), 0.85)
	lighting.place_lamp($Lanterns, Vector2(116, 79), 0.85)
	lighting.refresh()
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.campaign_ended.connect(_refresh.unbind(1))
	GameEvents.autumn_exhibit_completed.connect(_on_exhibited)
	_refresh()

func _refresh() -> void:
	visible = Global.is_autumn_exhibit_day() and Global.outcome == Global.Outcome.RUNNING
	$Bench/Shape.set_deferred("disabled", not visible)
	set_process(visible)
	if visible:
		_refresh_receipt()
		display_time = 0.0 if _waiting_for_guests() else -1.0
		_sync_display(true)

func _refresh_receipt() -> void:
	record = Global.autumn_exhibit_record(Global.current_day)
	for index in samples.get_child_count():
		var sample := samples.get_child(index) as Sprite2D
		if not record.is_empty():
			var picture := ItemManager.crop_picture(ItemManager.get_crop(record.crops[index]))
			sample.texture = picture.texture
			sample.self_modulate = picture.tint
	for guest in guests.get_children():
		guest.show_receipt(record)
	_refresh_hint()

func _waiting_for_guests() -> bool:
	return record.get("shared", false) and Global.day_progress < AutumnExhibit.LAST_ARRIVAL

func _process(delta: float) -> void:
	if display_time >= 0.0 and not _waiting_for_guests():
		display_time += delta
		var duration := AutumnExhibit.HANDOFF_SECONDS if record.shared else AutumnExhibit.DISPLAY_SECONDS
		if display_time >= duration:
			display_time = -1.0
	_sync_display()

func _sync_display(snap := false) -> void:
	var shared: bool = record.get("shared", false)
	for index in samples.get_child_count():
		samples.get_child(index).visible = display_time >= 0.0 and (not shared or AutumnExhibit.handoff(index, display_time) < 0.5)
	for guest in guests.get_children():
		guest.update_pose(Global.day_progress, display_time, shared, snap)

func can_interact_from(foot: Vector2) -> bool:
	var at := to_local(foot)
	return visible and absf(at.x) < 44.0 and at.y >= 6.0 and at.y < 35.0

func set_interaction_focused(active: bool) -> void:
	hint.visible = active
	if active:
		_refresh_hint()

func _refresh_hint() -> void:
	hint.text = GamepadInput.interact_hint("秋社" if record.is_empty() else "秋社簿")

func interact() -> void:
	GameEvents.autumn_exhibit_requested.emit()

func _on_exhibited() -> void:
	_refresh_receipt()
	display_time = 0.0
	_sync_display()
	AudioManager.play_world_sfx(BELL, self, -12.0, 120.0)
