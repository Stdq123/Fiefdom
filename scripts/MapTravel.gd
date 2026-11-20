extends CanvasLayer

signal finished

const COVER_COLOR := Color("#151e1a")
const CLOSE_SECONDS := 0.16
const OPEN_SECONDS := 0.22
const ARRIVAL_PLATE := preload("res://scenes/TravelArrival.tscn")
const ARRIVAL_TOP := 30.0
const ARRIVAL_GAP := 8.0
const ARRIVAL_HOLD := 0.95
const ARRIVAL_NOTE_HOLD := 2.15
const SESSION_PLATE := preload("res://scenes/SessionLoading.tscn")
const RESOURCE_BATCH_USEC := 5000
const RESOURCE_BATCH_LIMIT_USEC := 120000

var active := false
var cover: ColorRect
var arrival_plate: CenterContainer
var arrival_name: Label
var arrival_note: Label
var _arrival_plaque: PanelContainer
var _arrival_tween: Tween
var _preloads: Dictionary[String, PackedScene] = {}
var _session_plate: CenterContainer
var _session_caption: Label
var _session_stage: Label
var _session_count: Label
var _session_activity: ProgressBar
var _session_batch_usec := RESOURCE_BATCH_USEC

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	cover = ColorRect.new()
	cover.name = "Cover"
	cover.color = Color(COVER_COLOR, 0.0)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.hide()
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arrival_plate = ARRIVAL_PLATE.instantiate()
	add_child(arrival_plate)
	_arrival_plaque = arrival_plate.get_node("Plaque")
	arrival_plate.visibility_changed.connect(func(): set_process(arrival_plate.visible))
	arrival_name = arrival_plate.get_node("%Place")
	arrival_note = arrival_plate.get_node("%EntryNote")
	InterfaceFont.scale_reading_text(arrival_name)
	InterfaceFont.scale_reading_text(arrival_note)
	arrival_plate.get_node("%MapIcon").texture = HUDIcons.icon(HUDIcons.Symbol.MAP)
	for visibility in [GameEvents.modal_visibility_changed, GameEvents.settings_visibility_changed, GameEvents.management_visibility_changed]:
		visibility.connect(_dismiss_arrival_for_panel)
	GameEvents.campaign_ended.connect(_clear_arrival.unbind(1))
	get_tree().scene_changed.connect(_clear_arrival)
	_session_plate = SESSION_PLATE.instantiate()
	add_child(_session_plate)
	_session_caption = _session_plate.get_node("%Caption")
	_session_stage = _session_plate.get_node("%ReadStage")
	_session_count = _session_plate.get_node("%ReadCount")
	_session_activity = _session_plate.get_node("%Activity")
	for label: Label in [_session_caption, _session_stage, _session_count]:
		InterfaceFont.scale_reading_text(label)
	set_process(false)
	set_process_input(false)

func prepare_session(path: String, caption: String) -> Error:
	var tree := get_tree()
	var origin := tree.current_scene
	if active or origin == null:
		return ERR_BUSY
	var packed: PackedScene = _preloads.get(path)
	if packed and _unprepared_neighbors(packed).is_empty():
		return OK
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return ERR_FILE_NOT_FOUND
	active = true
	set_process_input(true)
	_clear_arrival()
	cover.color.a = 1.0
	cover.show()
	var stage := _map_read_stage(path, caption)
	await _show_loading_card(caption, stage)
	packed = await _prepare_in_batches(path, stage)
	if packed:
		for neighbor in _unprepared_neighbors(packed):
			if not is_instance_valid(origin) or tree.current_scene != origin:
				break
			await _prepare_in_batches(neighbor, "预备关口 · " + place_name(neighbor))
	_finish()
	if not is_instance_valid(origin) or tree.current_scene != origin:
		return ERR_SKIP
	return OK if packed else ERR_CANT_OPEN

func _map_read_stage(path: String, caption: String) -> String:
	var place := place_name(path)
	return "地图资源" if place.is_empty() or caption.contains(place) else place + " · 地图资源"

func _show_loading_card(caption: String, stage: String) -> void:
	_session_caption.text = caption
	_session_stage.text = stage
	_session_count.text = ""
	_session_activity.value = 0.0
	_session_activity.indeterminate = true
	_session_plate.show()
	_session_batch_usec = RESOURCE_BATCH_USEC
	# Draw the loading card before the first synchronous read.
	var tree := get_tree()
	await tree.process_frame
	await tree.process_frame

func _set_read_count(read: int, total: int) -> void:
	_session_count.text = "%d/%d 项" % [read, total]
	_session_activity.value = read

func _prepare_in_batches(path: String, stage: String) -> PackedScene:
	if _preloads.has(path):
		return _preloads[path]
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return null
	var dependencies := ResourceLoader.get_dependencies(path)
	var total := dependencies.size() + 1
	var read := 0
	_session_activity.set_value_no_signal(0.0)
	_session_stage.text = stage
	_session_activity.max_value = total
	_set_read_count(read, total)
	_session_activity.indeterminate = false
	# Retain each dependency until the packed map owns it.
	var held: Array[Resource] = []
	var started := Time.get_ticks_usec()
	for dependency in dependencies:
		var target := dependency.get_slice("::", 0)
		if dependency.contains("::") and not ResourceLoader.exists(target):
			target = dependency.get_slice("::", 2)
		if not ResourceLoader.has_cached(target):
			var resource := ResourceLoader.load(target)
			if resource:
				held.append(resource)
		read += 1
		if Time.get_ticks_usec() - started >= _session_batch_usec:
			_set_read_count(read, total)
			var waiting := Time.get_ticks_usec()
			await get_tree().process_frame
			started = Time.get_ticks_usec()
			# Slow frame delivery can cost more than a small batch. Amortize that wait for this entry.
			_session_batch_usec = clampi(maxi(_session_batch_usec, (started - waiting) * 3),
				RESOURCE_BATCH_USEC, RESOURCE_BATCH_LIMIT_USEC)
	var packed := ResourceLoader.load(path, "PackedScene") as PackedScene
	if packed:
		_preloads[path] = packed
	_set_read_count(total if packed else read, total)
	await get_tree().process_frame
	return packed

func _unprepared_neighbors(packed: PackedScene) -> PackedStringArray:
	var neighbors := PackedStringArray()
	var scene_state := packed.get_state()
	var maps := Global.SAVE_SCENES.values()
	for node in scene_state.get_node_count():
		for property in scene_state.get_node_property_count(node):
			if scene_state.get_node_property_name(node, property) != &"destination":
				continue
			var destination: Variant = scene_state.get_node_property_value(node, property)
			if destination is String and destination in maps \
					and not _preloads.has(destination) and not neighbors.has(destination):
				neighbors.append(destination)
	return neighbors

func cross(path: String, arrival_path: NodePath, player_path: NodePath, entry_note := "") -> void:
	relocate(_open_destination.bind(path, arrival_path, player_path), path, entry_note)

func relocate(change_location: Callable, arrival_scene := "", entry_note := "") -> void:
	var tree := get_tree()
	if active or tree.paused or tree.current_scene == null or Global.outcome != Global.Outcome.RUNNING:
		return
	active = true
	set_process_input(true)
	_cross.call_deferred(tree.current_scene, change_location, arrival_scene, entry_note)

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _cross(origin: Node, change_location: Callable, arrival_scene: String, entry_note: String) -> void:
	_clear_arrival()
	if not _can_depart(origin):
		_finish()
		return
	var original_mode := origin.process_mode
	# Suspend the departing map locally so the destination can manage its own modals.
	origin.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	cover.show()
	await _fade(1.0, CLOSE_SECONDS)
	var crossed := false
	if _can_depart(origin) and change_location.is_valid():
		crossed = await change_location.call()
	if is_instance_valid(origin) and get_tree().current_scene == origin:
		origin.process_mode = original_mode
		if not crossed and not get_tree().paused and Global.outcome == Global.Outcome.RUNNING:
			GameEvents.world_notice.emit("前方暂时无法通行")
	if crossed and not get_tree().paused and Global.outcome == Global.Outcome.RUNNING:
		_show_arrival(arrival_scene, entry_note)
	await _fade(0.0, OPEN_SECONDS)
	_finish()

func _can_depart(origin: Node) -> bool:
	return is_instance_valid(origin) and get_tree().current_scene == origin and not get_tree().paused \
		and Global.outcome == Global.Outcome.RUNNING

func _open_destination(path: String, arrival_path: NodePath, player_path: NodePath) -> bool:
	var tree := get_tree()
	var origin := tree.current_scene
	var packed: PackedScene = _preloads.get(path)
	if packed == null:
		if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
			return false
		var place := place_name(path)
		var caption := "正在前往" + place if not place.is_empty() else "正在读入地图"
		await _show_loading_card(caption, "地图资源")
		if _can_depart(origin):
			packed = await _prepare_in_batches(path, "地图资源")
		_session_plate.hide()
		if packed == null or not _can_depart(origin):
			return false
	var destination := packed.instantiate()
	if destination == null:
		return false
	var marker := destination.get_node_or_null(arrival_path) as Marker2D
	var player := destination.get_node_or_null(player_path) as Player
	if marker == null or player == null:
		destination.free()
		return false
	GameEvents.map_departing.emit()
	if tree.change_scene_to_node(destination) != OK:
		destination.free()
		return false
	await tree.scene_changed
	if tree.current_scene != destination:
		return false
	player.arrive_at(marker)
	await tree.process_frame
	return true

func _fade(opacity: float, seconds: float) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(cover, "color:a", opacity, seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished

func place_name(path: String) -> String:
	var location: Variant = Global.SAVE_SCENES.find_key(path)
	return "封地" if location == "estate" else Global.SAVE_LOCATION_NAMES.get(location, "")

func _show_arrival(path: String, entry_note := "") -> void:
	var place := place_name(path)
	if place.is_empty():
		return
	arrival_name.text = place
	arrival_note.text = entry_note
	arrival_note.visible = not entry_note.is_empty()
	arrival_plate.modulate.a = 0.0
	arrival_plate.show()
	_arrival_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_arrival_tween.tween_property(arrival_plate, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE)
	_arrival_tween.tween_interval(ARRIVAL_NOTE_HOLD if arrival_note.visible else ARRIVAL_HOLD)
	_arrival_tween.tween_property(arrival_plate, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE)
	_arrival_tween.tween_callback(arrival_plate.hide)

func _process(_delta: float) -> void:
	var area := get_viewport().get_visible_rect().grow(-ARRIVAL_GAP)
	var size := _arrival_plaque.get_combined_minimum_size()
	var candidate := Rect2(Vector2(area.get_center().x - size.x * 0.5, ARRIVAL_TOP), size)
	var occupied: Array[Rect2] = []
	var rows := PackedFloat32Array([ARRIVAL_TOP])
	for overlay: Control in get_tree().get_nodes_in_group(&"interaction_prompt_obstacle"):
		if overlay == _arrival_plaque or not overlay.is_visible_in_tree():
			continue
		var obstacle := (overlay.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, overlay.size)).grow(ARRIVAL_GAP)
		if obstacle.end.x > candidate.position.x and obstacle.position.x < candidate.end.x:
			occupied.append(obstacle)
			rows.append(ceilf(obstacle.end.y))
	rows.sort()
	for top in rows:
		candidate.position.y = top
		if top >= ARRIVAL_TOP and area.encloses(candidate) and HintPlacement.is_clear(candidate, occupied):
			arrival_plate.offset_top = top
			arrival_plate.offset_bottom = top + size.y
			return
	_clear_arrival()

func _dismiss_arrival_for_panel(opened: bool) -> void:
	if opened:
		_clear_arrival()

func _clear_arrival() -> void:
	if _arrival_tween:
		_arrival_tween.kill()
		_arrival_tween = null
	arrival_plate.hide()

func _finish() -> void:
	_session_plate.hide()
	cover.hide()
	cover.color.a = 0.0
	set_process_input(false)
	active = false
	finished.emit()
