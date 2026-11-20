extends RefCounted

const ARROWS := [&"ui_left", &"ui_up", &"ui_right", &"ui_down"]

static func reading_scrollbar(scroll: ScrollContainer) -> VScrollBar:
	var bar := scroll.get_v_scroll_bar()
	bar.focus_mode = Control.FOCUS_ALL
	# ScrollContainer uses a zero range step, so give its focus keys a reading increment.
	bar.custom_step = 48.0
	return bar

static func has_popup(viewport: Viewport) -> bool:
	return viewport.get_embedded_subwindows().any(func(window: Window): return not window.unfocusable)

static func input_owner(panel: Control) -> Control:
	if not panel.is_visible_in_tree():
		return null
	var viewport := panel.get_viewport()
	var current := viewport.gui_get_focus_owner()
	if current and panel.is_ancestor_of(current) and not has_popup(viewport):
		return current
	return null

static func edge(panel: Control, backward := false) -> Control:
	var controls := panel.find_children("*", "Control", true, false)
	if backward:
		controls.reverse()
	for control: Control in controls:
		if (control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL
				and (not control is BaseButton or not control.disabled)):
			return control
	return null

static func restore_opening_focus(viewport: Viewport, opening: WeakRef, fallback: Control = null) -> bool:
	if viewport.gui_get_focus_owner() or has_popup(viewport):
		return false
	var target := opening.get_ref() as Control if opening else null
	if not _available(target):
		target = fallback
	if not _available(target):
		return false
	target.grab_focus()
	return target.has_focus()

static func _available(control: Control) -> bool:
	return (is_instance_valid(control) and control.is_visible_in_tree()
		and control.focus_mode != Control.FOCUS_NONE and (not control is BaseButton or not control.disabled))

static func keep_navigation_inside(panel: Control, current: Control, event: InputEvent) -> void:
	var viewport := panel.get_viewport()
	var backward := event.is_action_pressed(&"ui_focus_prev", true)
	if backward or event.is_action_pressed(&"ui_focus_next", true):
		var next := current.find_prev_valid_focus() if backward else current.find_next_valid_focus()
		if not next or not panel.is_ancestor_of(next):
			var target := edge(panel, backward)
			if target:
				target.grab_focus()
			viewport.set_input_as_handled()
	elif not current is LineEdit:
		for side in ARROWS.size():
			if not event.is_action_pressed(ARROWS[side], true):
				continue
			var vertical := side == SIDE_TOP or side == SIDE_BOTTOM
			if current is ScrollBar and vertical == (current is VScrollBar):
				if current.custom_step > 0.0:
					var direction := -1.0 if side == SIDE_TOP or side == SIDE_LEFT else 1.0
					current.value += current.custom_step * direction
					viewport.set_input_as_handled()
				return
			var next := current.find_valid_focus_neighbor(side as Side)
			if next and not panel.is_ancestor_of(next):
				viewport.set_input_as_handled()
			return
