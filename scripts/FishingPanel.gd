extends PanelContainer

enum Phase { WAITING, BITE, REELING, DONE }

const GAME_THEME := preload("res://resources/game_theme.tres")
const SPLASH := "res://assets/audio/fishing/float-splash.wav"
const SAFE_LOW := 0.27
const SAFE_HIGH := 0.79

var spot: Node2D
var angler: Node2D
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
var actions: HBoxContainer
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
		sound.stream = load(SPLASH)
		add_child(sound)
		_splash(-17.0, 1.10)
	spot.show_line(angler.global_position, float_time, false)

func _build_layout() -> void:
	theme = GAME_THEME
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -255.0
	offset_right = 255.0
	offset_top = -206.0
	offset_bottom = -22.0
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	add_child(layout)
	var title := Label.new()
	title.text = "%s · 垂钓" % CreekFish.PLACES[spot.site]
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
	status.text = "看着浮标，沉下去时再提竿。"
	status.add_theme_color_override("font_color", Color("#e8c983"))
	status.add_theme_font_size_override("font_size", 18)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(status)
	detail = Label.new()
	detail.text = "浮标轻晃时先等一等。"
	detail.add_theme_font_size_override("font_size", 15)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(detail)
	line_meter = ProgressBar.new()
	line_meter.max_value = 1.0
	line_meter.show_percentage = false
	line_meter.custom_minimum_size.y = 17
	layout.add_child(line_meter)
	tension_band = ColorRect.new()
	tension_band.color = Color("#57976b8c")
	tension_band.anchor_left = SAFE_LOW
	tension_band.anchor_right = SAFE_HIGH
	tension_band.anchor_bottom = 1.0
	tension_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tension_band.hide()
	line_meter.add_child(tension_band)
	actions = HBoxContainer.new()
	layout.add_child(actions)
	pull_button = Button.new()
	pull_button.focus_mode = Control.FOCUS_NONE
	pull_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pull_button.custom_minimum_size.y = 36
	pull_button.button_down.connect(_press_line)
	pull_button.button_up.connect(_release_line)
	actions.add_child(pull_button)
	var close := Button.new()
	close.text = "收竿 · B / Esc"
	close.custom_minimum_size = Vector2(116, 36)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(queue_free)
	actions.add_child(close)

func _process(delta: float) -> void:
	# Keep reaction and tension readable during long render frames.
	var step := minf(delta, 0.05)
	phase_time += step
	float_time += step
	match phase:
		Phase.WAITING:
			if phase_time >= wait_time:
				phase = Phase.BITE
				phase_time = 0.0
				status.text = "浮标沉下去了！现在提竿。"
				_refresh_shortcut()
				_splash(-6.0, 1.0)
			elif phase_time > wait_time - 0.38:
				status.text = "浮标轻晃，先等它沉下。"
		Phase.BITE:
			line_meter.value = maxf(0.0, 1.0 - phase_time / fish.bite)
			if phase_time >= fish.bite:
				_finish("浮标又浮起来了，鱼溜走了。")
		Phase.REELING:
			_reel(step)
	if phase != Phase.DONE:
		spot.show_line(angler.global_position, float_time, phase in [Phase.BITE, Phase.REELING])

func _reel(step: float) -> void:
	var rate: float = fish.pull if holding else -0.43
	tension = clampf(tension + rate * step, 0.0, 1.0)
	line_meter.value = tension
	if tension <= 0.02 or tension >= 0.98:
		_finish("线松了，鱼钻回水里。" if tension <= 0.02 else "线绷得太紧，鱼挣脱了。")
		return
	if tension >= SAFE_LOW and tension <= SAFE_HIGH:
		reeled += step
	status.text = "松开一点，让钓线缓下来。" if tension >= 0.67 else "按住收线，保持在绿段。"
	detail.text = "张力 %d%%   ·   收线 %d%%" % [roundi(tension * 100), mini(100, roundi(reeled / fish.reel * 100))]
	if reeled >= fish.reel:
		var id := Global.land_creek_fish(spot.site, cast_day)
		if id.is_empty():
			_finish("这次垂钓已结束。")
		else:
			_splash(-10.0, 0.93)
			_finish("钓到%s · 已收入鱼篓" % fish.name, id)

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
	if phase == Phase.BITE:
		detail.text = "按 %s，或按住「提竿」。" % shortcut

func _press_line() -> void:
	match phase:
		Phase.WAITING:
			_finish("提得太早，鱼散开了。")
		Phase.BITE:
			phase = Phase.REELING
			holding = true
			line_meter.value = tension
			tension_band.show()
			_refresh_shortcut()
		Phase.REELING:
			holding = true

func _release_line() -> void:
	holding = false

func _finish(message: String, caught := "") -> void:
	phase = Phase.DONE
	set_process(false)
	spot.clear_line()
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
	if fish_stall in places:
		detail.text = "渔生正在收这种鱼。"
		if seasonal:
			detail.text += "这尾鱼也可交时令单。" if Global.fish_count(caught) == 1 else "时令单也已备齐。"
	elif seasonal:
		detail.text = "时令单已备齐，可以回西市交货。"
	elif spot.site == CreekFish.Site.POND:
		detail.text = "带一份稻到南路灶台，可做稻鱼羹。"
	else:
		detail.text = "打开溪鱼簿，可添口粮或换铜钱。"
	if spot.site == CreekFish.Site.POND:
		_add_route_button("HearthRoute", "去" + TravelHearth.PLACE, TravelHearth.PLACE)
	for place in places:
		var order := place == Global.MARKET_ORDERS
		_add_route_button("SeasonDelivery" if order else "FishDelivery", "去西市交时令单" if order else "去西市交留鱼", place)

func _add_route_button(button_name: String, caption: String, place: String) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = caption
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_follow_route.bind(place))
	actions.add_child(button)
	actions.move_child(button, actions.get_child_count() - 2)

func _follow_route(place: String) -> void:
	if route_to.call(place):
		queue_free()
	else:
		detail.text = "先靠近山路，再从竹涧舆图指路去西市。"

func _splash(volume_db: float, pitch: float) -> void:
	if sound:
		sound.volume_db = volume_db
		sound.pitch_scale = pitch
		sound.play()

func _exit_tree() -> void:
	if is_instance_valid(spot):
		spot.clear_line()
	if owns_pause:
		get_tree().paused = false
	GameEvents.modal_visibility_changed.emit(false)
