extends Control

@export var toggle_action: StringName = KeyBindings.MAP
@export var keep_focus_in_map := true

const REGION_SCENE := "res://scenes/RegionMap.tscn"
const PANEL_FOCUS := preload("res://scripts/PanelFocus.gd")
enum Region { MARKET, ROAD, ESTATE, RAVINE }

@onready var modal: Control = %MapModal
@onready var close_button: Button = %CloseMap
@onready var close_caption := close_button.text.trim_suffix("  Esc")

var owns_pause := false
var _opening_focus: WeakRef

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
	var opener := get_viewport().gui_get_focus_owner()
	_opening_focus = weakref(opener) if opener else null
	get_tree().paused = true
	_show_map()
	AudioManager.play_menu_cue(AudioManager.MenuCue.OPEN)
	GameEvents.modal_visibility_changed.emit(true)

func switch_to(next: Control, preferred_focus: Control) -> void:
	next._opening_focus = _opening_focus
	_opening_focus = null
	owns_pause = false
	modal.hide()
	next._show_map()
	AudioManager.play_menu_cue(AudioManager.MenuCue.PAGE)
	preferred_focus.grab_focus()

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
	if GamepadInput.active:
		_snap_after_open()

func _snap_after_open() -> void:
	var tree := get_tree()
	# Let the chart containers finish laying out before pointing at the focus.
	await tree.process_frame
	await tree.process_frame
	if is_inside_tree() and owns_pause and PANEL_FOCUS.input_owner(modal):
		GamepadInput.snap_pointer_to_focus()

func close_map() -> void:
	var returning := owns_pause and Global.outcome == Global.Outcome.RUNNING
	if returning:
		AudioManager.play_menu_cue(AudioManager.MenuCue.CLOSE)
	modal.hide()
	_release_pause()
	if returning and _opening_focus:
		_restore_after_close(_opening_focus)
	_opening_focus = null

func _restore_after_close(opener: WeakRef) -> void:
	var tree := get_tree()
	# Travel headers reveal their opening button on the first unpaused frame.
	await tree.process_frame
	await tree.process_frame
	if (is_inside_tree() and not modal.visible and not tree.paused
			and PANEL_FOCUS.restore_opening_focus(get_viewport(), opener)):
		GamepadInput.snap_pointer_to_focus()

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
	if PANEL_FOCUS.has_popup(get_viewport()):
		return
	var current := get_viewport().gui_get_focus_owner()
	var backward := event.is_action_pressed(&"ui_focus_prev", true)
	if backward or event.is_action_pressed(&"ui_focus_next", true):
		if current and modal.is_ancestor_of(current):
			var next := current.find_prev_valid_focus() if backward else current.find_next_valid_focus()
			if next and modal.is_ancestor_of(next):
				return
		var edge := PANEL_FOCUS.edge(modal, backward)
		if edge:
			edge.grab_focus()
		get_viewport().set_input_as_handled()
	elif current and modal.is_ancestor_of(current) and not current is Range:
		for side in PANEL_FOCUS.ARROWS.size():
			if event.is_action_pressed(PANEL_FOCUS.ARROWS[side], true):
				var next := current.find_valid_focus_neighbor(side as Side)
				if next and not modal.is_ancestor_of(next):
					get_viewport().set_input_as_handled()
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
