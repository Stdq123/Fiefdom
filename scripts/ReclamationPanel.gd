extends Control

signal market_requested(site: Variant)
signal visitor_requested(speaker: String)
signal worksite_requested(field_id: int)

const WORKSITE := preload("res://scripts/FieldWorksite.gd")
const PANEL_FOCUS := preload("res://scripts/PanelFocus.gd")
const READY_INK := Color("#c6dba5")
const SHORT_INK := Color("#efbf8b")
const HELP_INK := Color("#e5d6ac")
const PLOT_OPEN := Color("#c3d391")
const PLOT_BLOCKED := Color("#ec9a80")
const PLOT_EMPTY := Color("#847b62")
const WATER_MARK := Color("#c8f5e3")
const MARK_OUTLINE := Color("#242a24")
const SURVEY_HEIGHT := 516.0
const RECEIPT_HEIGHT := 468.0
const FULL_ESTATE_HEIGHT := 246.0

@onready var card: Panel = $Panel
@onready var subtitle: Label = %Subtitle
@onready var rank_label: Label = %Rank
@onready var workers_label: Label = %Workers
@onready var copper_label: Label = %Copper
@onready var grain_label: Label = %Grain
@onready var crew_label: Label = %Crew
@onready var reclaim_button: Button = $Panel/ReclaimButton
@onready var close_button: Button = $Panel/CloseButton
@onready var info_label: Label = %InfoLabel
@onready var validity_label: Label = %ValidityLabel
@onready var site_diagram: Control = %SiteDiagram
@onready var market_button: Button = %MarketButton
@onready var visitor_button: Button = %VisitorButton
@onready var worksite_button: Button = %WorksiteButton

var world: Node2D
var tile_map: TileMapLayer
var highlight: Node2D
var plan: Dictionary
var visitor_name := ""
var selected_cell := Vector2i.ZERO
var has_selection := false
var preview_center: Variant
var preview_site := Global.ReclamationSite.OPEN
var preview_watered: Array[Vector2i] = []
var commissioned_site := -1
var paid := Vector2i.ZERO
var returned_to_estate := false

func _ready() -> void:
	add_to_group("gamepad_directional_menu")
	%SurveyKit.texture = WORKSITE.tool_texture(0)
	site_diagram.draw.connect(_draw_site_diagram)
	var scroll := %Scroll as ScrollContainer
	scroll.follow_focus = true
	var scroll_bar := PANEL_FOCUS.reading_scrollbar(scroll)
	scroll_bar.theme_type_variation = &"HudJournalBar"
	GamepadInput.changed.connect(_refresh_shortcuts)
	_refresh_shortcuts()
	for control: Control in %Checks.get_children():
		InterfaceFont.scale_reading_text(control)
	for control: Control in [subtitle, info_label, validity_label, reclaim_button, close_button,
			market_button, visitor_button, worksite_button]:
		InterfaceFont.scale_reading_text(control)

func setup(estate_world: Node2D, previous_site: Variant = null) -> void:
	world = estate_world
	tile_map = world.tile_map
	highlight = Node2D.new()
	highlight.z_index = 100
	highlight.draw.connect(_draw_preview)
	tile_map.add_child(highlight)
	reclaim_button.pressed.connect(_reclaim_selected)
	close_button.pressed.connect(_return_to_estate)
	market_button.pressed.connect(_open_market)
	visitor_button.pressed.connect(_find_visitor)
	worksite_button.pressed.connect(_find_worksite)
	for changed in [GameEvents.rank_changed, GameEvents.retainer_recruited, GameEvents.retainer_departed,
			GameEvents.money_changed, GameEvents.food_changed, GameEvents.reputation_changed, GameEvents.well_field_added,
			GameEvents.retainer_duty_changed]:
		changed.connect(_refresh.unbind(1))
	GameEvents.channels_changed.connect(_refresh)
	GameEvents.campaign_ended.connect(queue_free.unbind(1))
	GameEvents.daylight_changed.connect(_refresh_ledger)
	world.visitor_changed.connect(_refresh.unbind(1))
	_refresh()
	if previous_site != null and plan.has_space:
		_select_site(previous_site)
	_focus_return()
	AudioManager.play_menu_cue(AudioManager.MenuCue.OPEN)

func _refresh_shortcuts() -> void:
	close_button.text = "返回  B" if GamepadInput.active else "返回  Esc"

func _focus_return() -> void:
	close_button.grab_focus()
	GamepadInput.snap_pointer_to_focus.call_deferred()

func _return_to_estate() -> void:
	returned_to_estate = true
	AudioManager.play_menu_cue(AudioManager.MenuCue.CLOSE)
	queue_free()

func _process(_delta: float) -> void:
	if preview_center != null and not has_selection and get_viewport().gui_get_hovered_control() != self:
		_clear_preview()

func _gui_input(event: InputEvent) -> void:
	if not tile_map or not plan.has_space:
		return
	if event is InputEventMouseMotion and not has_selection and commissioned_site < 0:
		var cell := _pointer_cell(event.position)
		if cell != preview_center:
			_show_preview(cell)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_site(_pointer_cell(event.position))
		accept_event()

func _pointer_cell(panel_position: Vector2) -> Vector2i:
	return world.field_at(get_global_transform_with_canvas() * panel_position)

func _select_site(cell: Vector2i) -> void:
	selected_cell = cell
	has_selection = true
	commissioned_site = -1
	_show_preview(cell)
	_refresh_ledger()

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventAction:
		var current := PANEL_FOCUS.input_owner(card)
		if current:
			PANEL_FOCUS.keep_navigation_inside(card, current, event)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		_return_to_estate()
		get_viewport().set_input_as_handled()
	elif Preferences.matches(event, KeyBindings.INTERACT) or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	plan = Global.reclamation_plan()
	_refresh_ledger()
	if not plan.has_space:
		_clear_preview()
	elif preview_center != null:
		_show_preview(preview_center)
	else:
		_update_validity()

func _refresh_ledger() -> void:
	var previous := PANEL_FOCUS.input_owner(card)
	var receipt := commissioned_site >= 0
	card.size.y = RECEIPT_HEIGHT if receipt else (SURVEY_HEIGHT if plan.possible else FULL_ESTATE_HEIGHT)
	var field_number := commissioned_site + 1 if receipt else Global.well_fields.size() + 1
	subtitle.text = "井田 %d · 立桩后 %d 夜完工" % [field_number, Global.RECLAMATION_NIGHTS]
	if receipt:
		subtitle.text = "井田 %d · 已立桩" % field_number
	elif not plan.has_space:
		subtitle.text = ("井田 %d · 按%s田额估算费用" % [field_number, Global.rank_names[plan.cost_rank]]
			if plan.possible else "封地井田已达最高田额")
	_show_check(rank_label, "%s · %d/%d 块" % [
		Global.rank_names[Global.current_rank], Global.well_fields.size(), Global.max_well_fields], receipt or plan.has_space)
	for control: Control in %Checks.get_children():
		control.visible = plan.possible or receipt or control == rank_label or control.name == &"RankKey"
	var crew_grain := Global.food_storage if receipt else maxi(0, Global.food_storage - int(plan.grain))
	_show_requirement(crew_label, crew_grain, plan.crew_food, "份", "" if receipt else "立桩后 ")
	crew_label.tooltip_text = "按现有门客的耗粮预估 %d 夜所需口粮。" % Global.RECLAMATION_NIGHTS
	if receipt:
		_show_check(workers_label, "%d 人" % Global.retainers.size(), true)
		_show_check(copper_label, "余 %d 枚 · 已扣 %d 枚" % [Global.money, paid.x], true)
		_show_check(grain_label, "余 %d 份 · 已扣 %d 份" % [Global.food_storage, paid.y], true)
	else:
		_show_requirement(workers_label, Global.retainers.size(), Global.RECLAMATION_RETAINERS, "人")
		_show_requirement(copper_label, Global.money, plan.copper, "枚")
		_show_requirement(grain_label, Global.food_storage, plan.grain, "份")
	var seeking_workers: bool = not receipt and plan.possible and plan.workers_needed > 0
	var candidate: Dictionary = world.recruitment_candidate() if seeking_workers and Global.last_recruit_day != Global.current_day else {}
	visitor_name = candidate.guest.name if not candidate.is_empty() else ""
	visitor_button.visible = not visitor_name.is_empty()
	visitor_button.text = "去找" + visitor_name
	market_button.visible = (not receipt and plan.possible
		and (Global.money < plan.copper or Global.food_storage < plan.grain + plan.crew_food))
	worksite_button.visible = receipt
	%Shortcuts.visible = visitor_button.visible or market_button.visible or worksite_button.visible
	info_label.text = _instructions(candidate)
	info_label.visible = not info_label.text.is_empty()
	if previous and not previous.is_visible_in_tree():
		_focus_return()

func _show_requirement(label: Label, available: int, needed: int, unit: String, prefix := "") -> void:
	var value := "%s%d/%d %s" % [prefix, available, needed, unit]
	if available < needed:
		value += " · 差 %d" % (needed - available)
	_show_check(label, value, available >= needed)

func _show_check(label: Label, value: String, ready: bool) -> void:
	label.text = value
	label.modulate = READY_INK if ready else SHORT_INK

func _instructions(candidate: Dictionary) -> String:
	if commissioned_site >= 0:
		return "%d 夜后可耕种。" % Global.RECLAMATION_NIGHTS
	if not plan.has_space:
		return Global.promotion_summary() + "\n过夜时核定爵位。" if plan.possible else ""
	return _recruitment_instructions(candidate) if plan.workers_needed > 0 else ""

func _recruitment_instructions(candidate: Dictionary) -> String:
	if candidate.is_empty():
		var today := "今日已留一位门客。" if Global.last_recruit_day == Global.current_day else "今日没有可拜访的来客。"
		return today + "\n" + _next_visit_note()
	var guest: VisitorData = candidate.guest
	var block := Global.recruitment_block(guest)
	var cost := "招募需 %d 声望" % Global.balance.recruit_reputation_requirement
	if block != Global.RecruitmentBlock.NONE:
		cost = Global.recruitment_block_note(guest, block)
		if block == Global.RecruitmentBlock.REPUTATION and guest.name != VisitorData.FIELD_KEEPER and not guest.talked_today():
			cost += "，今日交谈可得 %d" % Global.balance.interaction_reputation_gain
	return "%s%s。\n%s。" % [guest.name, candidate.location, cost]

func _next_visit_note() -> String:
	var keeper_retained := Global.retainers.any(func(resident: RetainerData): return resident.name == VisitorData.FIELD_KEEPER)
	var keeper_day := Global.next_field_keeper_visit()
	if keeper_day == Global.current_day:
		keeper_day += FieldRotation.VISIT_INTERVAL
	# The regular round includes two rest days in a seven-day cycle.
	for day in range(Global.current_day + 1, Global.current_day + 8):
		var guest := Global.visitor_for_day(day)
		if guest:
			return "预计第 %d 天 · %s · %s" % [
				day, guest.name, VisitorData.scheduled_stop(guest.name, guest.meeting_place, day)]
		if not keeper_retained and day == keeper_day:
			return "预计第 %d 天 · 渠伯 · 井田西南" % day
	return "可先照料田地，筹措开垦所需的粮钱。"

func _show_preview(center: Vector2i) -> void:
	preview_center = center
	preview_site = Global.reclamation_site(center)
	preview_watered.clear()
	if preview_site == Global.ReclamationSite.OPEN:
		preview_watered = Global.irrigation.watered_footprint(center)
	_update_validity()

func _clear_preview() -> void:
	preview_center = null
	has_selection = false
	preview_watered.clear()
	_update_validity()

func _update_validity() -> void:
	var staking_selected := reclaim_button.has_focus()
	reclaim_button.disabled = not plan.ready or not has_selection or preview_site != Global.ReclamationSite.OPEN
	if staking_selected and reclaim_button.disabled:
		_focus_return()
	var survey_available: bool = plan.has_space and commissioned_site < 0
	%SiteRule.visible = survey_available
	%SiteNotes.visible = survey_available
	site_diagram.queue_redraw()
	highlight.queue_redraw()
	validity_label.modulate = HELP_INK
	if not survey_available:
		validity_label.text = ""
		return
	if preview_center == null:
		validity_label.text = "移动光标勘察九格田界，点选田址。"
		return
	validity_label.modulate = READY_INK if preview_site == Global.ReclamationSite.OPEN else SHORT_INK
	match preview_site:
		Global.ReclamationSite.EDGE: validity_label.text = "超出可开垦范围。请把九格田放在封地内侧。"
		Global.ReclamationSite.NEAR_FIELD: validity_label.text = "离已有井田太近。请在田埂外多留几格。"
		Global.ReclamationSite.SOURCE: validity_label.text = "田界会盖住水源。请挪开一格再看。"
		Global.ReclamationSite.CANAL: validity_label.text = "田界会盖住水渠。可在渠边另选田址。"
		Global.ReclamationSite.ROAD: validity_label.text = "田界会占用道路或路肩。请在路旁另选田址。"
		Global.ReclamationSite.LANDMARK: validity_label.text = "田界会占用建筑或驾御场。请移到旁边空地。"
		Global.ReclamationSite.OPEN:
			var status := "已选田址" if has_selection else "此处可用"
			var mark := "＋ " if not preview_watered.is_empty() else ""
			validity_label.text = "%s\n%s可接现有渠水 %d/9 格" % [status, mark, preview_watered.size()]

func _draw_preview() -> void:
	if preview_center == null:
		return
	var cell_size := Vector2(tile_map.tile_set.tile_size)
	var area := Rect2(tile_map.map_to_local(preview_center) - cell_size * 1.5, cell_size * 3.0)
	_draw_plot(highlight, area, cell_size)
	if has_selection and preview_site == Global.ReclamationSite.OPEN:
		for corner in EstateLayout.corners(area):
			var stake := Rect2(corner - Vector2(4.5, 8), Vector2(9, 9))
			highlight.draw_texture_rect(WORKSITE.tool_texture(WORKSITE.PEG), stake, false)

func _draw_site_diagram() -> void:
	site_diagram.draw_rect(Rect2(Vector2.ZERO, site_diagram.size), Color("#1b2524"))
	var area := Rect2(Vector2(3, 3), site_diagram.size - Vector2(6, 6))
	_draw_plot(site_diagram, area, area.size / 3.0)

func _draw_plot(canvas: CanvasItem, area: Rect2, cell_size: Vector2) -> void:
	var blocked := preview_center != null and preview_site != Global.ReclamationSite.OPEN
	var edge := PLOT_EMPTY if preview_center == null else (PLOT_BLOCKED if blocked else PLOT_OPEN)
	canvas.draw_rect(area, Color(edge, 0.19))
	if preview_center != null:
		var first: Vector2i = preview_center - Vector2i.ONE
		for cell in preview_watered:
			var wet := Rect2(area.position + Vector2(cell - first) * cell_size, cell_size).grow(-1.0)
			canvas.draw_rect(wet, Color("#85d9c280"))
			canvas.draw_rect(wet, Color("#a7e6d4"), false, 1.0)
			var radius := cell_size.x * 0.25
			_draw_mark(canvas, wet.get_center(), Vector2(radius, 0), Vector2(0, radius), WATER_MARK)
	for i: float in [1.0, 2.0]:
		var x := area.position.x + cell_size.x * i
		var y := area.position.y + cell_size.y * i
		canvas.draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(edge, 0.75))
		canvas.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(edge, 0.75))
	canvas.draw_rect(area, edge, false, 1.8 if has_selection else 1.2)
	if blocked:
		var radius := cell_size.x * 0.58
		_draw_mark(canvas, area.get_center(), Vector2(radius, radius), Vector2(radius, -radius), PLOT_BLOCKED)

func _draw_mark(canvas: CanvasItem, at: Vector2, a: Vector2, b: Vector2, ink: Color) -> void:
	for arm: Vector2 in [a, b]:
		canvas.draw_line(at - arm, at + arm, MARK_OUTLINE, 4.6, true)
	for arm: Vector2 in [a, b]:
		canvas.draw_line(at - arm, at + arm, ink, 2.2, true)

func _reclaim_selected() -> void:
	if not has_selection:
		return
	var order := Global.reclaim_well_field(selected_cell)
	if not order.is_empty():
		commissioned_site = order.field_id
		paid = Vector2i(order.copper, order.grain)
		_clear_preview()
	_refresh()

func _open_market() -> void:
	market_requested.emit(selected_cell if has_selection else null)
	queue_free()

func _find_visitor() -> void:
	if not visitor_name.is_empty():
		visitor_requested.emit(visitor_name)
		queue_free()

func _find_worksite() -> void:
	if commissioned_site >= 0:
		worksite_requested.emit(commissioned_site)
		queue_free()

func _exit_tree() -> void:
	if is_instance_valid(highlight) and highlight.is_inside_tree():
		highlight.queue_free()
