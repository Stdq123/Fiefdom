extends Control

@export var toggle_action: StringName = KeyBindings.MAP
@export var keep_focus_in_map := false

const REGION_SCENE := "res://scenes/RegionMap.tscn"
const FOCUS_ARROWS := [&"ui_left", &"ui_up", &"ui_right", &"ui_down"]
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
	AudioManager.play_menu_cue(AudioManager.MenuCue.OPEN)
	GameEvents.modal_visibility_changed.emit(true)

func switch_to(next: Control, preferred_focus: Control) -> void:
	owns_pause = false
	modal.hide()
	next._show_map()
	AudioManager.play_menu_cue(AudioManager.MenuCue.PAGE)
	preferred_focus.grab_focus()
	GamepadInput.snap_pointer_to_focus.call_deferred()

func add_region_map(region: Region, blocked: Callable, active: Callable, choose: Callable, clear: Callable,
		south: Callable = Callable()) -> Control:
	var overview: Control = (load(REGION_SCENE) as PackedScene).instantiate()
	get_parent().add_child(overview)
	toggle_action = &""
	overview.setup(region, blocked, active, choose, clear, self, south)
	%RegionMap.pressed.connect(switch_to.bind(overview, overview.local_button))
	return overview

func _show_map() -> void:
	owns_pause = true
	modal.show()
	_refresh_on_open()
	close_button.grab_focus()

func close_map() -> void:
	if owns_pause and Global.outcome == Global.Outcome.RUNNING:
		AudioManager.play_menu_cue(AudioManager.MenuCue.CLOSE)
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

func _input(event: InputEvent) -> void:
	if not keep_focus_in_map or not owns_pause or not modal.visible or not event is InputEventKey:
		return
	var current := get_viewport().gui_get_focus_owner()
	var backward := event.is_action_pressed(&"ui_focus_prev")
	if backward or event.is_action_pressed(&"ui_focus_next"):
		if current and modal.is_ancestor_of(current):
			var next := current.find_prev_valid_focus() if backward else current.find_next_valid_focus()
			if next and modal.is_ancestor_of(next):
				return
		_wrap_map_focus(backward)
		get_viewport().set_input_as_handled()
	elif current and modal.is_ancestor_of(current) and not current is Range:
		for side in FOCUS_ARROWS.size():
			if event.is_action_pressed(FOCUS_ARROWS[side]):
				var next := current.find_valid_focus_neighbor(side as Side)
				if next and not modal.is_ancestor_of(next):
					get_viewport().set_input_as_handled()
				return

func _wrap_map_focus(backward: bool) -> void:
	var controls := modal.find_children("*", "Control", true, false)
	if backward:
		controls.reverse()
	for control: Control in controls:
		if (control.is_visible_in_tree() and control.focus_mode == FOCUS_ALL
			and (not control is Button or not control.disabled)):
			control.grab_focus()
			return

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
