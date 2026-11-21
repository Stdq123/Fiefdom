extends SceneTree

var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		push_error("Run the weather display check with an isolated profile.")
		quit(1)
		return
	paused = true
	AudioServer.set_bus_mute(0, true)
	var state := root.get_node("Global")
	var events := root.get_node("GameEvents")
	var icons = load("res://scripts/HUDIcons.gd")
	var light := _day(state, "小雪")
	var heavy := _day(state, "大雪")
	var rain := _day(state, state.balance.rain_solar_term)
	var clear := _day(state, "冬至")
	var snow: AtlasTexture = icons.icon(icons.Symbol.SNOW)
	_expect(snow.atlas != null and snow.atlas.get_size() == Vector2(16, 16)
		and snow.atlas.get("pixels").get_size() == Vector2(32, 32)
		and snow.atlas.get_image().get_used_rect().has_area(), "The new glyph has visible 2× art at the shared logical size.")
	_expect(state.weather_on(light) == state.Weather.LIGHT_SNOW and state.weather_on(heavy) == state.Weather.HEAVY_SNOW
		and not state.has_rain(light) and not state.has_rain(heavy), "Both dates snow without changing the rain rule.")

	state.current_day = light
	state.day_progress = 0.0
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var ui := current_scene.get_node("UI")
	var hud: Control = ui.hud
	var dusk := 0.84
	for day: int in [light, heavy]:
		state.current_day = day
		state.day_progress = 0.0
		ui.update_ui()
		hud._refresh_watch()
		hud.dawn_notice.present("公田新熟 2 格", false)
		_expect(hud.calendar_label.text.ends_with(" · 落雪") and hud.weather_icon.texture == snow
			and hud.dawn_notice.sky.texture == snow and hud.dawn_notice.date_label.text.ends_with(" · 卯时"),
			"The estate date, watch and dawn notice agree with today's snowfall.")
		state.day_progress = dusk
		hud._refresh_watch()
		_expect(hud.weather_icon.texture == snow, "Snow still shows after dusk.")
	hud.dawn_notice.dismiss()

	var calendar: Control = ui.calendar
	calendar._refresh_on_open()
	for row: Array in [
		[heavy, light, "已过", "落雪", icons.Symbol.SNOW],
		[light, light, "今日", "落雪", icons.Symbol.SNOW],
		[heavy - 1, heavy, "明日", "落雪", icons.Symbol.SNOW],
		[heavy, rain, "已过", "雨 · 旱作可得水", icons.Symbol.RAIN],
		[clear - 1, clear, "明日", "晴", icons.Symbol.SUN],
	]:
		state.current_day = row[0]
		calendar._show_day(row[1])
		_expect(calendar.date_context.text == row[2] and calendar.forecast.text.begins_with(row[3])
			and calendar.weather_icon.texture == icons.icon(row[4]), "Calendar weather follows the selected day %d." % row[1])

	state.current_day = light - 1
	hud.refresh_seed_calendar()
	ui._show_night_rations()
	var night := ui.get_node("Control/NightRationsPanel")
	_expect(hud.forecast_label.text == "明日 小雪 · 落雪" and night.tomorrow_calendar.text == "明日 · 小雪 · 落雪  ›",
		"Both forecasts announce the first snowy day in advance.")
	night.queue_free()
	await process_frame
	state.current_day = rain - 1
	hud.refresh_seed_calendar()
	_expect(hud.forecast_label.text.ends_with(" · 雨润旱田"), "The farming forecast explains the benefit of rain.")

	state.current_day = heavy
	var visitors = load("res://scripts/VisitorData.gd")
	state.visitor_encounters[visitors.RAVINE_GUIDE] = light
	state.ravine_journal.recorded_days[0] = light
	state.ravine_journal.recorded_days[1] = rain
	ui.panel_manager.show_management_panel()
	var management: Control = ui.panel_manager.management_panel_instance
	var journal: Control = management.ravine_panel
	management.tabs.current_tab = management.tabs.get_tab_idx_from_control(journal)
	_expect(journal.today.text.ends_with(" · 大雪 · 落雪") and journal.headings[0].text.ends_with(" · 小雪 · 落雪")
		and journal.headings[1].text.ends_with(" · 谷雨 · 雨天")
		and journal.notes[0].text == RavineJournal.SITES[0].dry, "The water-trace journal retains each date's weather and trace.")
	management.show_fish_ledger()
	_expect(" · 大雪 · 落雪 · " in management.fish_ledger.readiness.text, "The fish ledger reads the live date.")

	for path: String in [state.WILDERNESS_SCENE, state.WEST_ROAD_SCENE, state.WEST_MARKET_SCENE]:
		state.current_day = light
		if change_scene_to_file(path) != OK:
			_expect(false, "Mount " + path)
			break
		await scene_changed
		current_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
		var trail: bool = path == state.WILDERNESS_SCENE
		var date: Label = current_scene.get_node("CampaignHUD").trail_date if trail else current_scene.get_node("%Date")
		var heading: Node = date.get_parent().get_node("TravelHeading" if trail else "Header")
		for view: Array in [
			[light, " · 落雪", icons.Symbol.SNOW],
			[heavy, " · 落雪", icons.Symbol.SNOW],
			[rain, " · 雨", icons.Symbol.RAIN],
			[clear, " · 冬至", icons.Symbol.MOON],
		]:
			state.current_day = view[0]
			events.daylight_changed.emit()
			var weather := heading.get_node("%WeatherIcon") as TextureRect
			_expect(date.text.ends_with(view[1]) and weather.texture == icons.icon(view[2])
				and weather.accessibility_name == state.weather_label(0, true),
				"The travel header follows the live weather and watch in %s." % path)
	_expect(paused and state.saved_games().is_empty(), "Fixed presentation cases write no campaign saves.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _day(state: Node, term: String) -> int:
	return state.SOLAR_TERMS.find(term) * state.balance.days_per_solar_term + 1

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
