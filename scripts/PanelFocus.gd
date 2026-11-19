extends RefCounted

const ARROWS := [&"ui_left", &"ui_up", &"ui_right", &"ui_down"]

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

static func keep_navigation_inside(panel: Control, current: Control, event: InputEventKey) -> void:
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
				return
			var next := current.find_valid_focus_neighbor(side as Side)
			if next and not panel.is_ancestor_of(next):
				viewport.set_input_as_handled()
			return
