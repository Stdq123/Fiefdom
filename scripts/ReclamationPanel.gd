extends Control

signal market_requested(site: Variant)
signal visitor_requested(speaker: String)
signal worksite_requested(field_id: int)

const READY_INK := Color("#c6dba5")
const SHORT_INK := Color("#efbf8b")
const HELP_INK := Color("#e5d6ac")

@onready var subtitle: Label = %Subtitle
@onready var rank_label: Label = %Rank
@onready var workers_label: Label = %Workers
@onready var copper_label: Label = %Copper
@onready var grain_label: Label = %Grain
@onready var reclaim_button: Button = $Panel/ReclaimButton
@onready var info_label: Label = $Panel/InfoLabel
@onready var validity_label: Label = $Panel/ValidityLabel
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

func setup(estate_world: Node2D, previous_site: Variant = null) -> void:
	world = estate_world
	tile_map = world.tile_map
	highlight = Node2D.new()
	highlight.z_index = 100
	highlight.draw.connect(_draw_preview)
	tile_map.add_child(highlight)
	reclaim_button.pressed.connect(_reclaim_selected)
	$Panel/CloseButton.pressed.connect(queue_free)
	market_button.pressed.connect(_open_market)
	visitor_button.pressed.connect(_find_visitor)
	worksite_button.pressed.connect(_find_worksite)
	for changed in [GameEvents.rank_changed, GameEvents.retainer_recruited, GameEvents.retainer_departed,
			GameEvents.money_changed, GameEvents.food_changed, GameEvents.reputation_changed, GameEvents.well_field_added,
			GameEvents.retainer_duty_changed]:
		changed.connect(_refresh.unbind(1))
	GameEvents.channels_changed.connect(_refresh)
	GameEvents.campaign_ended.connect(queue_free.unbind(1))
	world.visitor_changed.connect(_refresh.unbind(1))
	_refresh()
	if previous_site != null and plan.has_space:
		_select_site(previous_site)

func _process(_delta: float) -> void:
	if not tile_map or not plan.has_space or has_selection or commissioned_site >= 0:
		return
	if get_viewport().gui_get_hovered_control() != self:
		if preview_center != null:
			_clear_preview()
		return
	var cell := tile_map.local_to_map(tile_map.get_local_mouse_position())
	if preview_center == null or cell != preview_center:
		_show_preview(cell)

func _gui_input(event: InputEvent) -> void:
	if not tile_map or not plan.has_space:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var viewport_pos: Vector2 = get_global_transform_with_canvas() * event.position
		var tile_pos: Vector2 = tile_map.get_global_transform_with_canvas().affine_inverse() * viewport_pos
		_select_site(tile_map.local_to_map(tile_pos))
		accept_event()

func _select_site(cell: Vector2i) -> void:
	selected_cell = cell
	has_selection = true
	commissioned_site = -1
	_show_preview(cell)
	_refresh_ledger()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		queue_free()
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
	var receipt := commissioned_site >= 0
	var field_number := commissioned_site + 1 if receipt else Global.well_fields.size() + 1
	subtitle.text = "井田 %d · 立桩后 %d 夜完工" % [field_number, Global.RECLAMATION_NIGHTS]
	if receipt:
		subtitle.text = "井田 %d · 已立桩" % field_number
	elif not plan.has_space:
		subtitle.text = ("井田 %d · 按%s田额估算费用" % [field_number, Global.rank_names[plan.cost_rank]]
			if plan.possible else "封地井田已达最高田额")
	_show_check(rank_label, "%s · %d/%d 块" % [
		Global.rank_names[Global.current_rank], Global.well_fields.size(), Global.max_well_fields], receipt or plan.has_space)
	if receipt:
		_show_check(workers_label, "%d 人" % Global.retainers.size(), true)
		_show_check(copper_label, "余 %d 枚 · 已扣 %d 枚" % [Global.money, paid.x], true)
		_show_check(grain_label, "余 %d 份 · 已扣 %d 份" % [Global.food_storage, paid.y], true)
	else:
		_show_check(workers_label, "%d/%d 人" % [Global.retainers.size(), Global.RECLAMATION_RETAINERS], plan.workers_needed == 0)
		_show_check(copper_label, "%d/%d 枚" % [Global.money, plan.copper], Global.money >= plan.copper)
		_show_check(grain_label, "%d/%d 份" % [Global.food_storage, plan.grain], Global.food_storage >= plan.grain)
	var visitor: VisitorData = world.current_visitor()
	visitor_name = visitor.name if visitor and not receipt and plan.possible and plan.workers_needed > 0 else ""
	visitor_button.visible = not visitor_name.is_empty()
	visitor_button.text = "去找" + visitor_name
	market_button.visible = (not receipt and plan.possible
		and (Global.money < plan.copper or Global.food_storage < plan.grain + plan.crew_food))
	worksite_button.visible = receipt
	info_label.text = _instructions(visitor)

func _show_check(label: Label, value: String, ready: bool) -> void:
	label.text = value
	label.modulate = READY_INK if ready else SHORT_INK

func _instructions(visitor: VisitorData) -> String:
	if commissioned_site >= 0:
		return "%d 夜后可耕种。余粮 %d 份，施工期间门客共需 %d 份。" % [
			Global.RECLAMATION_NIGHTS, Global.food_storage, plan.crew_food]
	if not plan.has_space:
		if not plan.possible:
			return "现有井田已用尽爵位可管的田额。"
		return Global.promotion_summary() + "\n过夜时核定爵位。"
	if plan.ready:
		var instruction := "" if has_selection else "左键点选田址。"
		return instruction + "立桩后余粮 %d 份，%d 夜口粮需 %d 份。" % [
			Global.food_storage - plan.grain, Global.RECLAMATION_NIGHTS, plan.crew_food]
	if plan.workers_needed > 0:
		if visitor:
			var actor: Visitor = world.current_visitor_actor()
			var whereabouts := actor.visit_note() if actor.walking_to_stop else "在" + actor.visit_location()
			return "%s%s。交谈可增声望，招募花 %d 声望。" % [
				visitor.name, whereabouts, Global.balance.recruit_reputation_requirement]
		return "还需 %d 名门客。今日暂无可招募来客，可先收私田备粮钱。" % plan.workers_needed
	return "立桩用粮 %d 份，施工期间口粮另需 %d 份。可从市集按计划备粮。" % [plan.grain, plan.crew_food]

func _show_preview(center: Vector2i) -> void:
	preview_center = center
	preview_site = Global.reclamation_site(center)
	preview_watered.clear()
	if preview_site == Global.ReclamationSite.OPEN:
		preview_watered = Global.irrigation.watered_footprint(center)
	_update_validity()
	highlight.queue_redraw()

func _clear_preview() -> void:
	preview_center = null
	has_selection = false
	preview_watered.clear()
	_update_validity()
	highlight.queue_redraw()

func _update_validity() -> void:
	reclaim_button.disabled = not plan.ready or not has_selection or preview_site != Global.ReclamationSite.OPEN
	validity_label.modulate = HELP_INK
	if not plan.has_space or commissioned_site >= 0:
		validity_label.text = ""
		return
	if preview_center == null:
		validity_label.text = "移动鼠标查看九格田界与渠水。"
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
			validity_label.text = "%s · 可接现有渠水 %d/9 格" % [status, preview_watered.size()]

func _draw_preview() -> void:
	if preview_center == null:
		return
	var cell_size := Vector2(tile_map.tile_set.tile_size)
	var area := Rect2(tile_map.map_to_local(preview_center) - cell_size * 1.5, cell_size * 3.0)
	var edge := Color("#c3d391") if preview_site == Global.ReclamationSite.OPEN else Color("#ec9a80")
	highlight.draw_rect(area, Color(edge, 0.19))
	for cell in preview_watered:
		var wet := Rect2(tile_map.map_to_local(cell) - cell_size / 2.0, cell_size).grow(-1.0)
		highlight.draw_rect(wet, Color("#85d9c280"))
		highlight.draw_rect(wet, Color("#a7e6d4"), false, 1.0)
	for i: float in [1.0, 2.0]:
		var x := area.position.x + cell_size.x * i
		var y := area.position.y + cell_size.y * i
		highlight.draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(edge, 0.75))
		highlight.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(edge, 0.75))
	highlight.draw_rect(area, edge, false, 1.8 if has_selection else 1.2)
	if has_selection:
		for corner in [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]:
			highlight.draw_rect(Rect2(corner - Vector2(1.5, 1.5), Vector2(3, 3)), edge)

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
