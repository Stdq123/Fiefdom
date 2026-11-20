extends PanelContainer

enum Phase { WAITING, BITE, REELING, DONE }

const HUD_THEME := preload("res://resources/estate_hud_theme.tres")
const FRAME := preload("res://resources/estate_archive_frame.tres")
const SPLASH := preload("res://assets/audio/fishing/float-splash.wav")
const BITE_SPLASH := preload("res://assets/audio/fishing/bite-splash.wav")
const SAFE_LOW := 0.27
const SAFE_HIGH := 0.79
const NIBBLE_SECONDS := 0.38

var spot: Node2D
var angler: Player
var rod: FishingRod
var route_to: Callable
var phase := Phase.WAITING
var phase_time := 0.0
var float_time := 0.0
var wait_time := 0.0
var tension := 0.51
var reeled := 0.0
var holding := false
var cast_day := 0
var fish: Dictionary
var owns_pause := false

var status: Label
var detail: Label
var line_meter: ProgressBar
var tension_band: ColorRect
var catch_icon: TextureRect
var pull_button: Button
var close_button: Button
var actions: HBoxContainer
var route_actions: HFlowContainer
var sound: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("timed_practice")
	cast_day = Global.current_day
	fish = CreekFish.SPECIES[Global.fish_at_today(spot.site)]
	wait_time = randf_range(1.2, 2.0)
	if Global.has_rain():
		wait_time *= 0.8
	owns_pause = not get_tree().paused
	if owns_pause:
		get_tree().paused = true
	_build_layout()
	GameEvents.modal_visibility_changed.emit(true)
	GamepadInput.changed.connect(_refresh_shortcut)
	Preferences.bindings_changed.connect(_refresh_shortcut)
	_refresh_shortcut()
	if DisplayServer.get_name() != "headless":
		sound = AudioStreamPlayer.new()
		sound.name = "FloatSplash"
		sound.bus = &"SFX"
		add_child(sound)
	rod = FishingRod.new()
	rod.name = "FishingRod"
	angler.add_child(rod)
	_present_cast()

func _present_cast() -> void:
	var pose := FishingRod.Pose.WAIT
	if phase == Phase.BITE:
		pose = FishingRod.Pose.BITE
	elif phase == Phase.REELING:
		pose = FishingRod.Pose.PULL if holding else FishingRod.Pose.EASE
	rod.present(spot.to_global(spot.water), pose, float_time, tension)
	var waiting := phase == Phase.WAITING
	var nibble := smoothstep(wait_time - NIBBLE_SECONDS, wait_time, phase_time) if waiting else 0.0
	spot.show_line(rod.to_global(rod.tip), float_time, not waiting, tension if phase == Phase.REELING else 0.0,
		nibble, -1.0 if waiting else phase_time)

func _put_away() -> void:
	if is_instance_valid(rod):
		rod.free()
	if is_instance_valid(spot):
		spot.clear_line()

func _build_layout() -> void:
	theme = HUD_THEME
	add_theme_stylebox_override("panel", FRAME)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -255.0
	offset_right = 255.0
	offset_top = -206.0
	offset_bottom = -22.0
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	add_child(layout)
	var title := Label.new()
	title.text = "%s · 垂钓" % CreekFish.PLACES[spot.site]
	title.add_theme_color_override("font_color", Color("#f3dfae"))
	title.add_theme_font_size_override("font_size", 22)
	layout.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	layout.add_child(row)
	catch_icon = TextureRect.new()
	catch_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	catch_icon.custom_minimum_size = Vector2(44, 44)
	catch_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	catch_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	catch_icon.hide()
	row.add_child(catch_icon)
	status = Label.new()
	status.text = "等浮标沉下再提竿。"
	status.add_theme_color_override("font_color", Color("#e8c983"))
	status.add_theme_font_size_override("font_size", 18)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(status)
	detail = Label.new()
	detail.text = "提得太早，鱼会散开。"
	detail.add_theme_color_override("font_color", Color("#d0d2bc"))
	detail.add_theme_font_size_override("font_size", 15)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(detail)
	line_meter = ProgressBar.new()
	line_meter.max_value = 1.0
	line_meter.show_percentage = false
	line_meter.custom_minimum_size.y = 17
	layout.add_child(line_meter)
	tension_band = ColorRect.new()
	tension_band.color = Color("#547c5dd4")
	tension_band.anchor_left = SAFE_LOW
	tension_band.anchor_right = SAFE_HIGH
	tension_band.anchor_bottom = 1.0
	tension_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tension_band.hide()
	line_meter.add_child(tension_band)
	tension_band.draw.connect(_draw_tension_marks)
	line_meter.value_changed.connect(func(_value: float): tension_band.queue_redraw())
	actions = HBoxContainer.new()
	route_actions = HFlowContainer.new()
	route_actions.hide()
	layout.add_child(route_actions)
	layout.add_child(actions)
	pull_button = Button.new()
	pull_button.theme_type_variation = &"HudPrimary"
	pull_button.focus_mode = Control.FOCUS_NONE
	pull_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pull_button.custom_minimum_size.y = 36
	pull_button.button_down.connect(_press_line)
	pull_button.button_up.connect(_release_line)
	actions.add_child(pull_button)
	close_button = Button.new()
	close_button.theme_type_variation = &"HudButton"
	close_button.custom_minimum_size = Vector2(116, 36)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(queue_free)
	actions.add_child(close_button)
	for control in [title, status, detail, pull_button, close_button]:
		InterfaceFont.scale_reading_text(control)

func _draw_tension_marks() -> void:
	var height := tension_band.size.y
	for edge: float in [0.0, tension_band.size.x - 1.0]:
		tension_band.draw_line(Vector2(edge, 1), Vector2(edge, height - 1), Color("#c3d1ac"), 1.0)
	var at := clampf(roundf(line_meter.value * line_meter.size.x), 3.0, line_meter.size.x - 3.0) - tension_band.position.x
	tension_band.draw_rect(Rect2(at - 2, 1, 5, height - 2), Color("#483f32"))
	tension_band.draw_rect(Rect2(at - 1, 2, 3, height - 4), Color("#ffdda0"))

func _process(delta: float) -> void:
	# Keep reaction and tension readable during long render frames.
	var step := minf(delta, 0.05)
	var airborne := float_time < FishingRod.CAST_SECONDS
	phase_time += step
	float_time += step
	if airborne and float_time >= FishingRod.CAST_SECONDS:
		_play_float_cue(SPLASH, -17.0, 1.10)
	match phase:
		Phase.WAITING:
			if phase_time >= wait_time:
				phase = Phase.BITE
				phase_time = 0.0
				status.text = "浮标沉下去了！现在提竿。"
				_refresh_shortcut()
				_play_float_cue(BITE_SPLASH, -9.0)
			elif phase_time > wait_time - NIBBLE_SECONDS:
				status.text = "浮标在轻颤，等它沉下。"
		Phase.BITE:
			line_meter.value = maxf(0.0, 1.0 - phase_time / fish.bite)
			if phase_time >= fish.bite:
				_finish("浮标又浮起来了，鱼溜走了。")
		Phase.REELING:
			_reel(step)
	if phase != Phase.DONE:
		_present_cast()

func _reel(step: float) -> void:
	var rate: float = fish.pull if holding else -0.43
	tension = clampf(tension + rate * step, 0.0, 1.0)
	if tension <= 0.02 or tension >= 0.98:
		_finish("线松了，鱼钻回水里。" if tension <= 0.02 else "线绷得太紧，鱼挣脱了。")
		return
	if tension >= SAFE_LOW and tension <= SAFE_HIGH:
		reeled += step
	_refresh_tension()
	if reeled >= fish.reel:
		var id := Global.land_creek_fish(spot.site, cast_day)
		if id.is_empty():
			_finish("这次垂钓已结束。")
		else:
			_play_float_cue(SPLASH, -10.0, 0.93)
			_finish("钓到%s · 已收入鱼篓" % fish.name, id)

func _refresh_tension() -> void:
	line_meter.value = tension
	status.text = "松开一点，让钓线缓下来。" if tension >= 0.67 else "按住收线，让游标留在刻线内。"
	detail.text = "张力 %d%%   ·   收线 %d%%" % [roundi(tension * 100), mini(100, roundi(reeled / fish.reel * 100))]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
	elif Preferences.matches(event, KeyBindings.RHYTHM):
		get_viewport().set_input_as_handled()
		if not event.is_pressed():
			_release_line()
		elif not event.is_echo():
			_press_line()

func _refresh_shortcut() -> void:
	var shortcut := GamepadInput.rhythm_key()
	pull_button.text = "%s · %s" % ["按住收线" if phase >= Phase.REELING else "提竿", shortcut]
	close_button.text = "收竿 · %s" % GamepadInput.back_key()
	if phase == Phase.BITE:
		detail.text = "按 %s，或按住「提竿」。" % shortcut

func _press_line() -> void:
	match phase:
		Phase.WAITING:
			_finish("提得太早，鱼散开了。")
		Phase.BITE:
			phase = Phase.REELING
			holding = true
			_refresh_tension()
			tension_band.show()
			_refresh_shortcut()
		Phase.REELING:
			holding = true

func _release_line() -> void:
	holding = false

func _finish(message: String, caught := "") -> void:
	phase = Phase.DONE
	set_process(false)
	_put_away()
	pull_button.disabled = true
	pull_button.hide()
	actions.alignment = BoxContainer.ALIGNMENT_END
	line_meter.hide()
	status.text = message
	if caught.is_empty():
		detail.text = "今日垂钓机会还在，可以收竿后再试。"
	else:
		catch_icon.texture = CreekFish.portrait(caught)
		catch_icon.show()
		_show_delivery_routes(caught)

func _show_delivery_routes(caught: String) -> void:
	var places := Global.fish_delivery_places(caught)
	var fish_stall: String = MarketStall.TITLES[MarketStall.Kind.FISH]
	var seasonal := Global.MARKET_ORDERS in places
	var supper_day := Global.winter_supper_preparation_day()
	if spot.site == CreekFish.Site.POND:
		_add_route_button("HearthRoute", "去" + TravelHearth.PLACE, TravelHearth.PLACE)
	for place in places:
		var order := place == Global.MARKET_ORDERS
		_add_route_button("SeasonDelivery" if order else "FishDelivery", "去西市交时令单" if order else "去西市交留鱼", place)
	if supper_day > 0:
		var when := "今日" if supper_day == Global.current_day else "第 %d 天" % supper_day
		detail.text = "%s冬至围炉。带这尾鱼和一份麦，可做鱼麦羹。" % when
		var button := _add_route_button("WinterSupperRoute", "去南池畔围炉", WinterSupper.PLACE)
		route_actions.move_child(button, 0)
		_focus_return_route.call_deferred(button)
	elif fish_stall in places:
		detail.text = "渔生正在收这种鱼。"
		if seasonal:
			detail.text += "这尾鱼也可交时令单。" if Global.fish_count(caught) == 1 else "时令单也已备齐。"
	elif seasonal:
		detail.text = "时令单已备齐，可以回西市交货。"
	elif spot.site == CreekFish.Site.POND:
		detail.text = "带一份稻到南路灶台，可做稻鱼羹。"
	else:
		detail.text = "打开溪鱼簿，可添口粮或换铜钱。"

func _focus_return_route(button: Button) -> void:
	await get_tree().process_frame
	if not is_queued_for_deletion():
		button.grab_focus()
		GamepadInput.snap_pointer_to_focus()

func _add_route_button(button_name: String, caption: String, place: String) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"HudButton"
	button.name = button_name
	button.text = caption
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_follow_route.bind(place))
	route_actions.add_child(button)
	InterfaceFont.scale_reading_text(button)
	route_actions.show()
	return button

func _follow_route(place: String) -> void:
	if route_to.call(place):
		queue_free()
	else:
		detail.text = "这里接不上山路。收竿走近道路后，再从舆图指路。"

func _play_float_cue(stream: AudioStream, volume_db: float, pitch := 1.0) -> void:
	if sound:
		sound.stream = stream
		sound.volume_db = volume_db
		sound.pitch_scale = pitch
		sound.play()

func _exit_tree() -> void:
	_put_away()
	if owns_pause:
		get_tree().paused = false
	GameEvents.modal_visibility_changed.emit(false)
