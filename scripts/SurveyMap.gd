extends Control

@export var toggle_action: StringName = KeyBindings.MAP

const REGION_SCENE := "res://scenes/RegionMap.tscn"
enum Region { MARKET, ROAD, ESTATE, RAVINE }

@onready var modal: Control = %MapModal
@onready var close_button: Button = %CloseMap
@onready var close_caption := close_button.text.trim_suffix("  Esc")

var owns_pause := false

func _ready() -> void:
	close_button.pressed.connect(close_map)
	GameEvents.campaign_ended.connect(_on_campaign_ended)
	GamepadInput.changed.connect(_refresh_shortcuts)
	Preferences.bindings_changed.connect(_refresh_shortcuts)
	_refresh_shortcuts()

func _refresh_shortcuts() -> void:
	close_button.text = close_caption + ("  B" if GamepadInput.active else "  Esc")

func open_map() -> void:
	if get_tree().paused or Global.outcome != Global.Outcome.RUNNING or not _map_available():
		return
	get_tree().paused = true
	_show_map()
	GameEvents.modal_visibility_changed.emit(true)

func switch_to(next: Control) -> void:
	owns_pause = false
	modal.hide()
	next._show_map()

func add_region_map(region: Region, blocked: Callable, active: Callable, choose: Callable, clear: Callable,
		south: Callable = Callable()) -> Control:
	var overview: Control = (load(REGION_SCENE) as PackedScene).instantiate()
	get_parent().add_child(overview)
	toggle_action = &""
	overview.setup(region, blocked, active, choose, clear, self, south)
	%RegionMap.pressed.connect(switch_to.bind(overview))
	return overview

func _show_map() -> void:
	owns_pause = true
	modal.show()
	_refresh_on_open()
	close_button.grab_focus()

func close_map() -> void:
	modal.hide()
	_release_pause()

func _exit_tree() -> void:
	_release_pause()

func _release_pause() -> void:
	if not owns_pause:
		return
	owns_pause = false
	if Global.outcome == Global.Outcome.RUNNING:
		get_tree().paused = false
	GameEvents.modal_visibility_changed.emit(false)

func _map_available() -> bool:
	return true

func _refresh_on_open() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if toggle_action != &"" and event.is_pressed() and not event.is_echo() and Preferences.matches(event, toggle_action):
		if modal.visible:
			close_map()
		else:
			_open_from_shortcut()
		get_viewport().set_input_as_handled()

func _open_from_shortcut() -> void:
	open_map()

func _unhandled_key_input(event: InputEvent) -> void:
	if modal.visible and event.is_action_pressed("ui_cancel"):
		close_map()
		get_viewport().set_input_as_handled()

func _on_campaign_ended(_outcome: Global.Outcome) -> void:
	close_map()
	hide()
