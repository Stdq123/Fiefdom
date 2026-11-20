extends Control

signal market_requested
signal silk_requested
signal duties_requested
signal dry_plot_requested
signal harvest_requested
signal tribute_field_requested
signal field_management_requested(field_id: int)
signal sleep_requested
signal east_watch_requested
signal pavilion_story_requested
signal tomorrow_calendar_requested

const GOOD := Color("#c7dcaf")
const SHORT := Color("#efbf8a")
const WINDOW_MARGIN := 16.0
const PANEL_FOCUS := preload("res://scripts/PanelFocus.gd")

@onready var window: PanelContainer = $Center/Window
@onready var content: VBoxContainer = $Center/Window/Content
@onready var header: HBoxContainer = $Center/Window/Content/Header
@onready var plan_index: HBoxContainer = %PlanIndex
@onready var tribute_section: Button = %TributeSection
@onready var field_section: Button = %FieldSection
@onready var rations_section: Button = %RationsSection
@onready var field_plan: PanelContainer = %FieldPlan
@onready var stock: PanelContainer = %Stock
@onready var grain: Label = %Grain
@onready var need: Label = %Need
@onready var money: Label = %Money
@onready var raid_plan: PanelContainer = %RaidPlan
@onready var raid_heading: Label = %RaidHeading
@onready var raid_instructions: Label = %RaidInstructions
@onready var find_watch: Button = %FindWatch
@onready var tribute_plan: PanelContainer = %TributePlan
@onready var tribute_plot: TributePlotPicture = %TributePlot
@onready var tribute_deadline: Label = %TributeDeadline
@onready var tribute_details: Label = %TributeDetails
@onready var tribute_goal: Label = %TributeGoal
@onready var find_tribute: Button = %FindTribute
@onready var pavilion_story: PanelContainer = %PavilionStory
@onready var pavilion_title: Label = %PavilionTitle
@onready var pavilion_people: Label = %PavilionPeople
@onready var find_pavilion: Button = %FindPavilion
@onready var field_forecast: Label = %FieldForecast
@onready var field_warning: Label = %FieldWarning
@onready var field_wait_note: Label = %FieldWaitNote
@onready var wait_button: Button = %WaitForFieldWork
@onready var wait_before_sleep: CheckButton = %WaitBeforeSleep
@onready var release_private_harvest: Button = %ReleasePrivateHarvest
@onready var sheep_note: Label = %SheepNote
@onready var silk_note: Label = %SilkNote
@onready var find_plot: Button = %FindPlot
@onready var find_ready_plot: Button = %FindReadyPlot
@onready var delegate: CheckButton = %Delegate
@onready var budget: SpinBox = %Budget
@onready var partial_meals: CheckButton = %PartialMeals
@onready var research_fee: Label = %ResearchFee
@onready var forecast: Label = %Forecast
@onready var keep: Label = %Keep
@onready var festival_pantry: HBoxContainer = %FestivalPantry
@onready var festival_reserve: Label = %FestivalReserve
@onready var release_festival_reserve: Button = %ReleaseFestivalReserve
@onready var night_offer: Label = %NightOffer
@onready var accept_offer: Button = %AcceptOffer
@onready var silk_offer: Label = %SilkOffer
@onready var sell_silk: Button = %SellSilk
@onready var view_silk: Button = %ViewSilk
@onready var silk_sale_receipt: Label = %SilkSaleReceipt
@onready var find_fruit: Button = %FindFruit
@onready var priority_row: HBoxContainer = %PriorityRow
@onready var priority_picker: OptionButton = %Priority
@onready var meal_forecast: Label = %MealForecast
@onready var duties_button: Button = %Duties
@onready var last_card: PanelContainer = %LastCard
@onready var receipt: Label = %Receipt
@onready var field_receipt: Label = %FieldReceipt
@onready var away_field_receipt: Label = %AwayFieldReceipt
@onready var field_wait_receipt: Label = %FieldWaitReceipt
@onready var silk_receipt: Label = %SilkReceipt
@onready var milestones: Label = %Milestones
@onready var plan_field: Button = %PlanField
@onready var find_harvest: Button = %FindHarvest
@onready var title: Label = %Title
@onready var page_date: Label = %PageDate
@onready var page_art := %PagePicture.texture as AtlasTexture
@onready var record_heading: Label = %RecordHeading
@onready var tomorrow_calendar: Button = %TomorrowCalendar
@onready var page_button: Button = %PageButton
@onready var plan_body: VBoxContainer = %Plan
@onready var footer: HBoxContainer = %Footer
@onready var close_button: Button = %Close
@onready var scroll: ScrollContainer = %Scroll
@onready var body: VBoxContainer = %Body

var show_previous := false
var focus_shortage := false
var completed_field_id := -1
var wait_for_retainers: Callable
var settling_field_work := false
var field_forecast_deadline := 1.0

func _ready() -> void:
	add_to_group("gamepad_directional_menu")
	%GrainIcon.texture = HUDIcons.icon(HUDIcons.Symbol.GRAIN)
	%NeedIcon.texture = HUDIcons.icon(HUDIcons.Symbol.RATIONS)
	%MoneyIcon.texture = HUDIcons.icon(HUDIcons.Symbol.COIN)
	%FieldMark.texture = HUDIcons.icon(HUDIcons.Symbol.HOE)
	%MealMark.texture = HUDIcons.icon(HUDIcons.Symbol.RATIONS)
	%Sleep.icon = HUDIcons.icon(HUDIcons.Symbol.MOON)
	tribute_section.icon = HUDIcons.icon(HUDIcons.Symbol.TREASURY)
	field_section.icon = HUDIcons.icon(HUDIcons.Symbol.HOE)
	rations_section.icon = HUDIcons.icon(HUDIcons.Symbol.RATIONS)
	tribute_section.pressed.connect(func(): _show_section(tribute_plan, _available_action([find_tribute])))
	field_section.pressed.connect(func():
		_show_section(field_plan, _available_action([find_plot, find_ready_plot, wait_button, wait_before_sleep]))
	)
	rations_section.pressed.connect(_show_meals)
	var bar := PANEL_FOCUS.reading_scrollbar(scroll)
	bar.theme_type_variation = &"HudJournalBar"
	bar.visibility_changed.connect(_link_navigation)
	page_button.visibility_changed.connect(_link_navigation)
	budget.max_value = NightRations.MAX_COPPER_LIMIT
	budget.get_line_edit().max_length = 10
	delegate.toggled.connect(_change_policy.unbind(1))
	budget.value_changed.connect(_change_policy.unbind(1))
	partial_meals.toggled.connect(_change_policy.unbind(1))
	release_festival_reserve.pressed.connect(_release_festival_reserve)
	accept_offer.pressed.connect(_accept_night_offer)
	sell_silk.pressed.connect(_sell_silk_for_rations)
	view_silk.pressed.connect(func():
		queue_free()
		silk_requested.emit()
	)
	find_fruit.pressed.connect(_guide_fruit)
	priority_picker.item_selected.connect(_select_priority)
	body.minimum_size_changed.connect(_fit_body)
	get_viewport().size_changed.connect(_fit_body)
	close_button.pressed.connect(_close)
	tomorrow_calendar.pressed.connect(tomorrow_calendar_requested.emit)
	find_plot.pressed.connect(dry_plot_requested.emit)
	find_ready_plot.pressed.connect(harvest_requested.emit)
	wait_button.pressed.connect(_wait_for_field_work)
	wait_before_sleep.toggled.connect(Global.set_wait_for_fields_before_sleep)
	release_private_harvest.pressed.connect(Global.set_private_harvest_hold.bind(false))
	find_harvest.pressed.connect(harvest_requested.emit)
	find_tribute.pressed.connect(tribute_field_requested.emit)
	find_pavilion.pressed.connect(pavilion_story_requested.emit)
	plan_field.pressed.connect(_open_field_management)
	find_watch.pressed.connect(func():
		queue_free()
		east_watch_requested.emit()
	)
	page_button.pressed.connect(func():
		_show_page(not show_previous)
		AudioManager.play_menu_cue(AudioManager.MenuCue.PAGE)
	)
	%Market.pressed.connect(func():
		queue_free()
		market_requested.emit()
	)
	duties_button.pressed.connect(func():
		queue_free()
		duties_requested.emit()
	)
	%Sleep.pressed.connect(func():
		queue_free()
		sleep_requested.emit()
	)
	GameEvents.night_rations_changed.connect(_refresh)
	GameEvents.field_wait_policy_changed.connect(_refresh_fields)
	GameEvents.season_order_pin_changed.connect(_refresh)
	GameEvents.sheepfold_changed.connect(_refresh)
	GameEvents.silk_changed.connect(_refresh)
	GameEvents.food_changed.connect(_refresh.unbind(1))
	GameEvents.forage_taken.connect(_refresh)
	GameEvents.money_changed.connect(_refresh.unbind(1))
	GameEvents.inventory_changed.connect(_refresh.unbind(1))
	GameEvents.retainer_recruited.connect(_refresh.unbind(1))
	GameEvents.retainer_departed.connect(_refresh.unbind(1))
	GameEvents.retainer_duty_changed.connect(_refresh.unbind(1))
	GameEvents.retainer_assigned.connect(_refresh_fields.unbind(2))
	GameEvents.farm_state_changed.connect(_refresh_fields)
	GameEvents.crop_harvested.connect(_refresh_fields.unbind(1))
	GameEvents.channels_changed.connect(_refresh_fields)
	GameEvents.daylight_changed.connect(_refresh_fields)
	GameEvents.day_advanced.connect(_refresh.unbind(1))
	GameEvents.raid_started.connect(_refresh_raid_plan)
	GameEvents.raid_defeated.connect(_refresh_raid_plan)
	GamepadInput.changed.connect(_refresh_raid_plan)
	GamepadInput.changed.connect(_refresh_close_hint)
	GameEvents.raid_started.connect(_refresh_fields)
	GameEvents.raid_defeated.connect(_refresh_fields)
	GameEvents.watch_snare_changed.connect(_refresh_raid_plan)
	_refresh_close_hint()
	_refresh()
	_show_page(show_previous)
	close_button.grab_focus()
	AudioManager.play_menu_cue(AudioManager.MenuCue.OPEN)
	_finish_opening_focus()

func _refresh_close_hint() -> void:
	close_button.tooltip_text = GamepadInput.back_key()

func _link_navigation() -> void:
	var buttons: Array[Button] = []
	if tomorrow_calendar.visible:
		buttons.append(tomorrow_calendar)
	if page_button.visible:
		buttons.append(page_button)
	buttons.append(close_button)
	for index in buttons.size():
		var button := buttons[index]
		button.focus_neighbor_left = button.get_path_to(buttons[maxi(0, index - 1)])
		button.focus_neighbor_right = button.get_path_to(buttons[mini(index + 1, buttons.size() - 1)])
	var bar := scroll.get_v_scroll_bar()
	rations_section.focus_neighbor_right = rations_section.get_path_to(bar) if bar.visible else ^"."
	close_button.focus_neighbor_bottom = close_button.get_path_to(bar) if show_previous and bar.visible else ^""
	var back := close_button if show_previous else rations_section
	bar.focus_neighbor_left = bar.get_path_to(back)

func show_pavilion_story(story_id: String, appointment_id: String, place: String) -> void:
	var ready_to_hear := not story_id.is_empty()
	var id := story_id if ready_to_hear else appointment_id
	pavilion_story.visible = not id.is_empty()
	if pavilion_story.visible:
		var story: Dictionary = PavilionStories.STORIES[id]
		pavilion_title.text = "%s · %s" % [PavilionRest.STORY_LABEL if ready_to_hear else "今晚小谈", story.title]
		var people := "、".join(story.speakers)
		pavilion_people.text = "%s已入席 · %s" % [people, place] if ready_to_hear else "%s起 · %s · %s" % [PavilionRest.rest_watch(), people, place]
		find_pavilion.text = "指路去席案" if ready_to_hear else "指路去候席"

func _finish_opening_focus() -> void:
	await get_tree().process_frame
	if is_queued_for_deletion() or not close_button.has_focus():
		return
	if focus_shortage and not show_previous:
		_show_meals()
	if close_button.has_focus():
		GamepadInput.snap_pointer_to_focus()

func _show_meals() -> void:
	var action: BaseButton = delegate
	if meal_forecast.visible:
		action = _available_action([accept_offer, find_fruit, sell_silk, priority_picker, %Market])
	_show_section(stock, action)

func _available_action(buttons: Array[BaseButton]) -> BaseButton:
	for button in buttons:
		if button.is_visible_in_tree() and not button.disabled:
			return button
	return null

func _show_section(section: Control, action: BaseButton) -> void:
	if action:
		action.grab_focus()
	var body_top := body.get_global_rect().position.y
	var top := section.get_global_rect().position.y - body_top
	if action and scroll.is_ancestor_of(action):
		var action_bottom := action.get_global_rect().end.y - body_top
		top = maxf(top, action_bottom - scroll.size.y)
	scroll.scroll_vertical = ceili(top)
	if action:
		GamepadInput.snap_pointer_to_focus.call_deferred()

func _set_section_summary(button: Button, message: String, urgent: bool) -> void:
	button.text = message
	button.theme_type_variation = &"HudNight" if urgent else &"HudButton"

func _show_page(previous: bool) -> void:
	show_previous = previous and last_card.visible
	title.text = "昨夜结算" if show_previous else "今夜安排"
	page_button.text = "今夜安排" if show_previous else "昨夜结算"
	page_art.region.position.x = page_art.region.size.x if show_previous else 0.0
	tomorrow_calendar.visible = not show_previous
	plan_index.visible = not show_previous
	plan_body.visible = not show_previous
	footer.visible = not show_previous
	_link_navigation()
	record_heading.visible = not show_previous
	_refresh_date()
	_refresh_fields()
	_refresh_field_management()
	scroll.set_deferred("scroll_vertical", 0)
	_fit_body.call_deferred()

func _refresh_date() -> void:
	var recorded_day: int = Global.last_dawn.get("day", Global.last_field_night.get("day",
		Global.night_rations.last.get("day", maxi(1, Global.current_day - 1))))
	var day := recorded_day if show_previous else Global.current_day
	page_date.text = "第 %d 夜 · %s" % [day, Global.get_current_solar_term(day)]
	record_heading.text = "昨夜结算 · 第 %d 夜" % recorded_day

func _fit_body() -> void:
	var separation := content.get_theme_constant("separation")
	var frame_height := window.get_theme_stylebox("panel").get_minimum_size().y
	for piece: Control in [header, plan_index, footer]:
		if piece.visible:
			frame_height += piece.get_combined_minimum_size().y + separation
	var height := maxf(0.0, get_viewport_rect().size.y - WINDOW_MARGIN * 2.0 - frame_height)
	scroll.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, height)

func _change_policy() -> void:
	Global.set_night_rations(delegate.button_pressed, int(budget.value), partial_meals.button_pressed)

func _accept_night_offer() -> void:
	var had_focus := accept_offer.has_focus()
	var offer := Global.night_rations_offer()
	Global.set_night_rations(true, offer.copper, Global.night_rations.partial_meals)
	AudioManager.play_ui_sfx()
	if had_focus:
		delegate.grab_focus()

func _select_priority(index: int) -> void:
	Global.set_ration_priority(priority_picker.get_item_metadata(index) as RetainerData)

func _release_festival_reserve() -> void:
	var had_focus := release_festival_reserve.has_focus()
	Global.set_festival_pantry(0)
	AudioManager.play_ui_sfx()
	if had_focus:
		delegate.grab_focus()

func _refresh() -> void:
	if settling_field_work:
		return
	var tomorrow := Global.current_day + 1
	tomorrow_calendar.text = "明日 · %s · %s  ›" % [Global.get_current_solar_term(tomorrow),
		Global.weather_label(tomorrow)]
	_refresh_raid_plan()
	_refresh_fields()
	sheep_note.visible = Global.sheepfold.owned()
	if sheep_note.visible:
		var feed := Global.sheep_feed(Global.sheepfold.fodder)
		sheep_note.text = "羊棚 · " + Sheepfold.FEED_LABELS[feed]
		sheep_note.modulate = SHORT if feed == Sheepfold.Feed.SHORTAGE else GOOD
	var plan := Global.night_rations_plan()
	var silk_forecast := Global.silk_night_summary(plan.fed)
	silk_note.visible = not silk_forecast.is_empty()
	silk_note.text = "蚕棚 · " + silk_forecast
	var policy := Global.night_rations
	grain.text = "粮仓\n%d 份" % Global.food_storage
	need.text = "今夜所需\n%d 份" % plan.need
	need.add_theme_color_override("font_color", SHORT if plan.uncovered > 0 else Color("#fce8b8"))
	if plan.uncovered > 0:
		need.text += " · 缺 %d" % plan.uncovered
	var meal_status := "口粮 · 预计够用" if plan.need > 0 else "口粮 · 无需准备"
	if plan.uncovered > 0:
		meal_status = "口粮 · 缺 %d 份" % plan.uncovered
	_set_section_summary(rations_section, meal_status, plan.uncovered > 0)
	money.text = "铜钱\n%d 枚" % Global.money
	delegate.set_pressed_no_signal(policy.enabled)
	budget.set_value_no_signal(policy.copper_limit)
	budget.editable = policy.enabled
	partial_meals.visible = policy.enabled
	partial_meals.set_pressed_no_signal(policy.partial_meals)
	research_fee.visible = plan.research_fee > 0
	if research_fee.visible:
		var due: int = plan.research_fee
		research_fee.modulate = GOOD if plan.research_reserve > 0 else SHORT
		research_fee.text = ("明早预留 %d 铜钱缴研究费。" % due if plan.research_reserve > 0
			else "明早研究费 %d 铜钱 · 备粮后还差 %d" % [due, due - Global.money + int(plan.copper)])
	forecast.add_theme_color_override("font_color", SHORT if plan.uncovered > 0 else GOOD)
	var supplement: int = plan.converted + plan.bought
	if plan.need == 0:
		forecast.text = "今夜暂无门客用粮。"
	elif plan.supper == plan.need:
		forecast.text = "今夜口粮由围炉供齐，共 %d 份。" % plan.supper
	elif plan.missing == 0:
		forecast.text = "粮仓够用，今夜从粮仓取 %d 份。" % (plan.need - plan.supper)
	elif not policy.enabled:
		forecast.text = "今夜缺 %d 份。可到市集备粮，或开启夜间备粮。" % plan.missing
	elif supplement > 0:
		var action := "先补" if plan.uncovered > 0 else "补足"
		forecast.text = "今夜%s %d 份 · %s" % [action, supplement, _describe_exchange(plan)]
	else:
		var rule := "按门客整份口粮补粮。" if policy.partial_meals else "凑齐前，今夜暂不补粮。"
		forecast.text = "今夜还差 %d 份。%s" % [plan.uncovered, rule]
	if plan.supper > 0 and plan.supper < plan.need:
		forecast.text = "围炉供 %d 份。%s" % [plan.supper, forecast.text]
	_refresh_night_offer(plan)
	var reservations := PackedStringArray()
	if not plan.current_reserved.is_empty():
		reservations.append("%s「%s」留货 · %s" % ["明日" if plan.new_order else "", plan.order_name,
			ItemManager.describe_crops(plan.current_reserved)])
	elif plan.new_order:
		reservations.append("明日换季，按「%s」留货。" % plan.order_name)
	if not plan.upcoming_reserved.is_empty():
		reservations.append("下季「%s」留货 · %s" % [plan.upcoming_order_name,
			ItemManager.describe_crops(plan.upcoming_reserved)])
	keep.text = "\n".join(reservations)
	keep.visible = policy.enabled and not reservations.is_empty()
	festival_pantry.visible = not plan.festival_pantry.is_empty()
	if festival_pantry.visible:
		festival_reserve.text = NightRations.describe_festival_pantry(plan.festival_pantry)
	_refresh_meal(plan)
	var meal := policy.last
	receipt.visible = not meal.is_empty()
	if receipt.visible:
		receipt.text = "第 %d 夜 · 用粮 %d/%d 份" % [meal.day, meal.served, meal.need]
		if meal.has("supper"):
			receipt.text += " · 围炉 %d 份" % meal.supper
		var exchange := _describe_exchange(meal)
		if not exchange.is_empty():
			receipt.text += "\n" + exchange
		elif meal.served < meal.need:
			receipt.text += " · 缺 %d 份" % (meal.need - meal.served)
		var missed: PackedStringArray = meal.get("missed", PackedStringArray())
		var departed: PackedStringArray = meal.get("departed", PackedStringArray())
		if not missed.is_empty():
			receipt.text += "\n缺餐 · " + "、".join(missed)
		if not departed.is_empty():
			receipt.text += "\n已离任 · " + "、".join(departed)
	_refresh_field_receipt()
	_refresh_field_management()
	var last_silk := Global.silk_workshop.last_work_summary()
	silk_receipt.visible = not last_silk.is_empty()
	silk_receipt.text = "昨夜蚕棚 · " + last_silk
	milestones.text = "\n".join(Global.dawn_milestones())
	milestones.visible = not milestones.text.is_empty()
	var has_field_notes := field_receipt.visible or away_field_receipt.visible or field_wait_receipt.visible
	%RecordedFields.visible = has_field_notes
	%RecordedMeal.visible = receipt.visible
	%ReceiptDivider.visible = has_field_notes and receipt.visible
	%Entries.visible = has_field_notes or receipt.visible
	var has_entries: bool = %Entries.visible or silk_receipt.visible or milestones.visible
	last_card.visible = has_entries or Global.has_morning_record()
	%EmptyRecord.visible = not has_entries
	page_button.visible = last_card.visible
	_refresh_date()

func _refresh_night_offer(plan: Dictionary) -> void:
	night_offer.hide()
	accept_offer.hide()
	silk_offer.hide()
	sell_silk.hide()
	view_silk.hide()
	find_fruit.hide()
	if plan.uncovered == 0:
		return
	var policy := Global.night_rations
	var offer := Global.night_rations_offer()
	var portions: int = offer.converted + offer.bought
	if portions > 0 and offer.uncovered < plan.uncovered:
		var action := "可补 %d 份" % portions if offer.uncovered > 0 else "可补足 %d 份" % portions
		night_offer.text = action + " · " + _describe_exchange(offer)
		accept_offer.text = "启用夜间备粮" if not policy.enabled else "购粮上限调至 %d 铜钱" % offer.copper
		night_offer.show()
		accept_offer.show()
	var silk_reserve := Global.silk_reserve_for_rations() if offer.uncovered > 0 and Global.silk_workshop.built else 0
	var funded := _silk_ration_quote(offer, silk_reserve)
	if not funded.is_empty():
		var remaining := Global.silk_workshop.bolts - 1
		var covered: int = funded.converted + funded.bought
		var meal := "可补足 %d 份" % covered if funded.uncovered == 0 else "可补 %d 份" % covered
		silk_offer.text = "卖绸后余 %d 匹 · %s\n%s" % [remaining, meal, _describe_exchange(funded)]
		sell_silk.text = "售 1 匹丝绸 · +%d 铜钱" % Global.balance.silk_sell_price
		silk_offer.show()
		sell_silk.show()
	elif offer.uncovered > 0 and Global.silk_workshop.built and Global.balance.silk_sell_price > 0:
		var stock := Global.silk_workshop.bolts
		silk_offer.text = "可在蚕桑页织绸，卖绸换铜钱买粮。"
		if stock > 0 and stock <= silk_reserve:
			silk_offer.text = "现有 %d 匹丝绸，可先留给议税或交货，再织余绸买粮。" % stock
		silk_offer.show()
		view_silk.show()
	if offer.uncovered > 0 and (funded.is_empty() or funded.uncovered > 0) and Global.last_forage_day != Global.current_day:
		find_fruit.text = "去野果坳采果 · 粮食 +%d" % Global.balance.wild_food_yield
		find_fruit.show()

func _guide_fruit() -> void:
	if is_queued_for_deletion() or not find_fruit.is_visible_in_tree() or Global.last_forage_day == Global.current_day:
		return
	queue_free()
	GameEvents.ravine_trip_requested.emit("野果坳")

func _silk_ration_quote(offer: Dictionary, reserve: int) -> Dictionary:
	var price := Global.balance.silk_sell_price
	if offer.uncovered == 0 or price <= 0 or not Global.can_use_workshop(SilkWorkshop.Action.SELL):
		return {}
	if Global.silk_workshop.bolts <= reserve:
		return {}
	var funded := Global.night_rations_offer(price)
	if funded.converted + funded.bought <= offer.converted + offer.bought:
		return {}
	return funded

func _sell_silk_for_rations() -> void:
	if is_queued_for_deletion() or Global.outcome != Global.Outcome.RUNNING or not sell_silk.is_visible_in_tree():
		return
	if _silk_ration_quote(Global.night_rations_offer(), Global.silk_reserve_for_rations()).is_empty():
		return
	var had_focus := sell_silk.has_focus()
	if Global.use_workshop(SilkWorkshop.Action.SELL):
		silk_sale_receipt.text = "已售 1 匹丝绸 · 铜钱 +%d" % Global.balance.silk_sell_price
		silk_sale_receipt.show()
		AudioManager.play_ui_sfx()
		if had_focus:
			var focus: Control = accept_offer if accept_offer.visible else delegate
			focus.grab_focus()
			_reveal_sale.call_deferred(focus)

func _reveal_sale(focus: Control) -> void:
	scroll.ensure_control_visible(silk_sale_receipt)
	scroll.ensure_control_visible(focus)
	GamepadInput.snap_pointer_to_focus()

func _refresh_meal(plan: Dictionary) -> void:
	var short: bool = not plan.missed.is_empty()
	var preferred := Global.night_rations.priority
	priority_row.visible = preferred != null or (short and plan.served > 0 and Global.retainers.size() > 1)
	if priority_row.visible:
		priority_picker.clear()
		priority_picker.add_item("按留任顺序")
		priority_picker.select(0)
		for worker in Global.retainers:
			var index := priority_picker.item_count
			priority_picker.add_item("%s · %d 份" % [worker.name, Global.retainer_night_ration(worker)])
			priority_picker.set_item_metadata(index, worker)
			if worker == preferred:
				priority_picker.select(index)
	duties_button.visible = short and plan.need > Global.retainers.size()
	meal_forecast.visible = short
	if not short:
		return
	var lines := PackedStringArray(["预计用粮 %d/%d 份" % [plan.served, plan.need]])
	if not plan.fed.is_empty():
		lines[0] += " · 领足 " + _retainer_names(plan.fed)
	lines.append("缺餐 · %s · 忠诚 −%d" % [_retainer_names(plan.missed), int(NightRations.MISSED_MEAL_LOYALTY)])
	if not plan.departing.is_empty():
		lines.append("预计离任 · " + "、".join(plan.departing))
	var grain_left := Global.food_storage + int(plan.converted) + int(plan.bought) - maxi(0, int(plan.served) - int(plan.supper))
	if grain_left > 0:
		lines.append("粮仓将余 %d 份，留待下次分餐。" % grain_left)
	var work := PackedStringArray()
	for worker: RetainerData in plan.fed:
		if worker.duty == RetainerData.Duty.TEACH:
			work.append(worker.name + "可教习")
		elif worker.duty == RetainerData.Duty.REEL and Global.silk_workshop.night_reeling:
			work.append(worker.name + "可夜缫丝")
	if not work.is_empty():
		lines.append(" · ".join(work))
	meal_forecast.text = "\n".join(lines)

func _retainer_names(roster: Array) -> String:
	return "、".join(PackedStringArray(roster.map(func(worker: RetainerData) -> String: return worker.name)))

func _refresh_raid_plan() -> void:
	var tomorrow := Global.current_day + 1
	var active := Global.raid_day > 0
	raid_plan.visible = active or Global.is_raid_day(tomorrow)
	if not raid_plan.visible:
		return
	raid_heading.text = "东路来敌 · " + Global.raid_name(Global.raid_kind) if active else "明日有敌袭"
	if not active and Global.east_watch_day > 0:
		raid_heading.text += " · " + Global.raid_name(Global.raid_kind_on(tomorrow))
	var instructions := GamepadInput.bow_instruction() + "。见地面红边就往侧边走。"
	if not active:
		instructions = "过夜前可先收成熟作物。合上账册后，可在屋外朝空地试射。\n" + instructions
	if Global.retainers.any(func(worker: RetainerData) -> bool: return worker.can_take_duty(RetainerData.Duty.GUARD)):
		instructions += "\n可在「管理」中安排兵家门客守卫。"
	if Global.watch_snare_armed or Global.raid_snare_left >= 0.0 or (not active and Global.can_prepare_watch_snare()):
		instructions += "\n" + Global.watch_snare_status()
	find_watch.visible = not active and Global.can_prepare_watch_snare()
	raid_instructions.text = instructions

func _refresh_fields() -> void:
	if settling_field_work:
		return
	var current := Global.field_night_forecast()
	var preview := Global.bedtime_field_forecast() if not show_previous and wait_for_retainers.is_valid() else {}
	var after_work := not preview.is_empty()
	var report: Dictionary = preview.get("growth", current)
	if after_work:
		field_forecast_deadline = 1.0 - float(preview.seconds) / maxf(1.0, Global.balance.daylight_seconds)
	set_process(after_work)
	_refresh_tribute(preview)
	var estimate := "收工后预计" if after_work else "今夜预计"
	field_forecast.text = "已有 %d 格可收 · %s %d 格生长" % [
		current.ready, estimate, report.growing + report.public_ripe + report.private_ripe]
	var ripe := _describe_ripe(report)
	if not ripe.is_empty():
		field_forecast.text += "\n明早新熟 · " + ripe
	var away_jobs := Global.away_field_summary(Global.FIELD_WORK_JOBS)
	if not away_jobs.is_empty():
		field_forecast.text += "\n今日外出田务 · " + away_jobs
		var away_yields := Global.away_field_summary(Global.FIELD_WORK_YIELDS)
		if not away_yields.is_empty():
			field_forecast.text += "\n" + away_yields
	var warnings := PackedStringArray()
	var dry_or_blocked: int = report.dry + report.blocked
	var field_status := "田务 · %d 格将长" % report.growing
	if dry_or_blocked > 0:
		field_status = "田务 · %d 格缺水" % dry_or_blocked
	elif current.ready > 0:
		field_status = "田务 · %d 格可收" % current.ready
	elif report.public_ripe + report.private_ripe > 0:
		field_status = "田务 · 明早新熟 %d 格" % (report.public_ripe + report.private_ripe)
	elif report.growing == 0:
		field_status = "田务 · 无生长"
	_set_section_summary(field_section, field_status, dry_or_blocked > 0)
	if report.dry > 0:
		var dry := "收工后仍有 %d 格待浇，缺水会停长" if after_work else "%d 格待浇，缺水会停长"
		warnings.append(dry % report.dry)
	if report.blocked > 0:
		warnings.append("%d 格稻田断水，需接通水渠" % report.blocked)
	field_warning.text = " · ".join(warnings)
	field_warning.visible = not warnings.is_empty()
	find_plot.visible = current.dry > 0
	find_plot.text = "找当前待浇田" if after_work else "找待浇田"
	find_ready_plot.visible = current.ready > 0
	find_harvest.visible = show_previous and current.ready > 0
	_refresh_field_wait(preview)

func _process(_delta: float) -> void:
	if Global.day_progress > field_forecast_deadline:
		_refresh_fields()

func _refresh_field_wait(preview: Dictionary) -> void:
	if show_previous or not wait_for_retainers.is_valid():
		return
	wait_before_sleep.visible = Global.first_tribute_delivered() and (Global.wait_for_fields_before_sleep
		or Global.retainers.any(func(worker: RetainerData) -> bool: return worker.works_fields()))
	wait_before_sleep.set_pressed_no_signal(Global.wait_for_fields_before_sleep)
	var report := Global.field_wait_report
	var offer := Global.field_wait_offer()
	var notes := PackedStringArray()
	if Global.hold_private_harvest:
		notes.append("熟私田暂留，可亲手收。")
	if not report.is_empty():
		notes.append(_describe_field_work("等待结果", report))
	if offer.plots > 0:
		if Global.raid_day > 0:
			notes.append("击退来敌后再等收工。")
		elif Global.tax_council_waiting():
			notes.append("先到堂前议税。")
		elif not offer.available:
			notes.append("今日时辰已晚。剩下的田务可亲手做。")
		elif not preview.is_empty():
			notes.append("睡前预计 · " + Global.field_work_summary(preview.work, Global.FIELD_WORK_JOBS))
		else:
			notes.append("门客可接手 %d 格。做完即停，最晚到亥时。" % offer.plots)
	var focus_lost: bool = ((wait_button.has_focus() and not offer.available)
		or (release_private_harvest.has_focus() and not Global.hold_private_harvest))
	wait_button.visible = offer.available
	release_private_harvest.visible = Global.hold_private_harvest
	field_wait_note.text = "\n".join(notes)
	field_wait_note.visible = not notes.is_empty()
	if focus_lost:
		var next_button: Button = wait_button if offer.available else %Sleep
		next_button.grab_focus()
		GamepadInput.snap_pointer_to_focus.call_deferred()

func _work_duration(minutes: int) -> String:
	return "%d 刻钟" % roundi(minutes / 15.0) if minutes >= 15 else "一刻钟内"

func _describe_field_work(heading: String, report: Dictionary) -> String:
	var line := heading + " · " + Global.field_work_summary(report, Global.FIELD_WORK_JOBS)
	if report.get("minutes", 0) > 0:
		line += " · 约 %s" % _work_duration(report.minutes)
	var yields := Global.field_work_summary(report, Global.FIELD_WORK_YIELDS)
	return line + "\n" + yields if not yields.is_empty() else line

func _wait_for_field_work() -> void:
	if settling_field_work or show_previous or not wait_button.is_visible_in_tree():
		return
	settling_field_work = true
	var result: Dictionary = wait_for_retainers.call()
	settling_field_work = false
	_refresh()
	if result.get("seconds", 0.0) > 0.0:
		AudioManager.play_ui_sfx()

func _refresh_field_management() -> void:
	var completed: Array = Global.last_dawn.get("completed_fields", [])
	completed_field_id = int(completed.back()) - 1 if not completed.is_empty() else -1
	var field := Global.get_well_field(completed_field_id)
	plan_field.visible = show_previous and field.get("is_unlocked", false)
	if plan_field.visible:
		plan_field.text = "安排井田 %d" % (completed_field_id + 1)

func _open_field_management() -> void:
	if is_queued_for_deletion() or not plan_field.is_visible_in_tree():
		return
	queue_free()
	field_management_requested.emit(completed_field_id)

func _refresh_tribute(preview: Dictionary) -> void:
	var due := Global.tribute_deadline()
	tribute_plan.visible = due > 0
	tribute_section.visible = tribute_plan.visible
	if not tribute_plan.visible:
		return
	var field := Global.tribute_field_plan()
	tribute_plot.show_plot(field)
	var tonight := due == Global.current_day
	var overdue := Global.tribute_overdue()
	var late_crop: bool = not field.is_empty() and field.ready_day > due
	var deadline := "今夜到期" if tonight else "第 %d 天过夜前" % due
	if overdue:
		deadline = "已逾期"
	var first := not Global.first_tribute_delivered()
	var due_share := "首贡 1 份" if first else "本期纳贡 1 份"
	tribute_deadline.text = due_share + " · " + deadline
	var urgent := tonight or late_crop or overdue
	_set_section_summary(tribute_section, ("%s · " % ("首贡" if first else "纳贡")) + deadline, urgent)
	tribute_deadline.add_theme_color_override("font_color", Color("#7b3522") if urgent else Color("#33432d"))
	tribute_goal.visible = not Global.quest_completed
	tribute_goal.text = "长期奖励 · 累计纳贡 %d/%d 份，达标得 %d 声望" % [
		Global.quest_progress, Global.quest_target, Global.TRIBUTE_QUEST_REPUTATION]
	find_tribute.visible = not field.is_empty()
	tribute_details.text = "收割公田后，作物入国库，期限重新计算。"
	if not field.is_empty():
		_describe_tribute_field(field)
		if field.status == Global.NightGrowth.DRY and field.cell in preview.get("watered_cells", []):
			tribute_details.text += "\n这格预计由门客在过夜前浇好。"
	var penalty := Global.tribute_penalty_tonight()
	var expected_tribute: int = preview.get("work", {}).get("tribute", 0)
	if expected_tribute > 0:
		tribute_details.text += "\n收工预计纳贡 %d 份。" % expected_tribute
	elif penalty > 0:
		tribute_details.text += "\n若今夜仍无纳贡，声望 −%d。" % penalty
		if Global.reputation - penalty <= Global.balance.rank_strip_threshold:
			tribute_details.text += "将失去封地。" if Global.current_rank == Global.Rank.XIA_SHI else "将被削爵。"
	elif late_crop and Global.balance.no_contribution_penalty > 0:
		tribute_details.text += "\n这茬赶不上期限。欠贡将扣 %d 点声望。" % Global.balance.no_contribution_penalty

func _describe_tribute_field(field: Dictionary) -> void:
	var name := "井田 %d 的%s" % [field.field, field.crop]
	var growth := "每夜供水，最早第 %d 天可收。" % field.ready_day
	match field.status:
		Global.NightGrowth.READY:
			tribute_details.text = "%s已熟。收下即可纳贡。" % name
			find_tribute.text = "找熟公田"
		Global.NightGrowth.BLOCKED:
			tribute_details.text = "%s需接通水渠。%s" % [name, growth]
			find_tribute.text = "找断水公田"
		Global.NightGrowth.DRY:
			tribute_details.text = "%s今天待浇。%s" % [name, growth]
			find_tribute.text = "找待浇公田"
		-1:
			tribute_details.text = "若今天在井田 %d 播%s并逐夜供水，最早第 %d 天可收。" % [field.field, field.crop, field.ready_day]
			find_tribute.text = "选%s并指路" % field.crop
		_:
			tribute_details.text = "%s已有水。%s" % [name, growth]
			find_tribute.text = "标出公田"

func _refresh_field_receipt() -> void:
	var report := Global.last_field_night
	var details := PackedStringArray()
	if not report.is_empty():
		var ripe := _describe_ripe(report)
		if not ripe.is_empty():
			details.append("新熟 " + ripe)
		if report.growing > 0:
			details.append("%d 格长了一阶" % report.growing)
		if report.dry > 0:
			details.append("%d 格漏浇停长" % report.dry)
		if report.blocked > 0:
			details.append("%d 格稻田断水停长" % report.blocked)
	field_receipt.visible = not details.is_empty()
	if field_receipt.visible:
		field_receipt.text = "第 %d 夜田务 · %s" % [report.day, " · ".join(details)]
	var daytime: Dictionary = Global.last_dawn.get("away_field", {})
	away_field_receipt.visible = not daytime.is_empty()
	if away_field_receipt.visible:
		away_field_receipt.text = _describe_field_work("第 %d 天外出田务" % daytime.day, daytime)
	var field_work: Dictionary = Global.last_dawn.get("field_wait", {})
	field_wait_receipt.visible = not field_work.is_empty()
	if field_wait_receipt.visible:
		field_wait_receipt.text = _describe_field_work("睡前收工", field_work)

func _describe_ripe(report: Dictionary) -> String:
	if report.public_ripe + report.private_ripe == 0:
		return ""
	return "公田 %d 格、私田 %d 格" % [report.public_ripe, report.private_ripe]

func _describe_exchange(plan: Dictionary) -> String:
	var details := PackedStringArray()
	if not plan.used.is_empty():
		details.append("转用 %s" % ItemManager.describe_crops(plan.used))
	if plan.bought > 0:
		details.append("购粮 %d 份（%d 铜钱）" % [plan.bought, plan.copper])
	return " · ".join(details)

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventAction:
		var focus := PANEL_FOCUS.input_owner(self)
		if focus:
			PANEL_FOCUS.keep_navigation_inside(self, focus, event)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	AudioManager.play_menu_cue(AudioManager.MenuCue.CLOSE)
	queue_free()
