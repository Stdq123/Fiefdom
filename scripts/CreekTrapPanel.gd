extends "res://scripts/SurveyMap.gd"

signal route_requested(place: String)

const SPLASH := preload("res://assets/audio/fishing/float-splash.wav")

@onready var heading: Label = %SiteName
@onready var status: Label = %TrapStatus
@onready var options: HBoxContainer = %Baits
@onready var catch_card: HBoxContainer = %Catch
@onready var fish_icon: TextureRect = %FishIcon
@onready var catch_label: Label = %CatchLabel
@onready var take_button: Button = %Take
@onready var guide_button: Button = %Guide
@onready var receipt: Label = %Receipt

var site: int = CreekFish.Site.POOL
var baits: Dictionary[String, Dictionary] = {}

func _ready() -> void:
	super._ready()
	for bait: String in CreekTrap.BAITS:
		_add_bait(bait)
	GameEvents.creek_trap_requested.connect(_open_at)
	take_button.pressed.connect(_take_catch)
	guide_button.pressed.connect(_follow_trap)

func _open_at(location: int) -> void:
	site = location
	open_map()

func _refresh_on_open() -> void:
	heading.text = CreekTrap.PLACES[site]
	receipt.hide()
	_refresh_options()

func _add_bait(bait: String) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(36, 36)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var text := VBoxContainer.new()
	row.add_child(text)
	var title := Label.new()
	var recipe: Dictionary = CreekTrap.BAITS[bait]
	title.text = "%s · %d 夜" % [recipe.name, recipe.nights]
	title.add_theme_font_size_override("font_size", 19)
	text.add_child(title)
	var forecast := Label.new()
	forecast.add_theme_color_override("font_color", Color("#c1d2ac"))
	text.add_child(forecast)
	var button := Button.new()
	button.custom_minimum_size.y = 37
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_place_bait.bind(bait))
	column.add_child(button)
	baits[bait] = {"portrait": portrait, "forecast": forecast, "button": button}

func _refresh_options() -> void:
	var deployed := Global.creek_trap_site()
	options.visible = deployed < 0
	catch_card.visible = deployed >= 0
	status.visible = deployed != site
	if deployed < 0:
		status.text = "两岸轮用一只竹笼。下笼取一份私田作物作饵。"
		for bait in baits:
			var row: Dictionary = baits[bait]
			var forecast := Global.creek_trap_forecast(site, bait, Global.current_day)
			row.portrait.texture = CreekFish.portrait(forecast.fish)
			row.forecast.text = "第 %d 天 · %s" % [forecast.day, _fish_count(forecast)]
			var stock := Global.crop_stock.count(bait)
			row.button.text = "下笼 · 私仓 %s %d/1" % [ItemManager.crop_label(bait), stock]
			row.button.disabled = stock < 1
		return
	status.text = "竹笼已下在%s。" % CreekFish.PLACES[deployed]
	var forecast := Global.creek_trap_catch()
	fish_icon.texture = CreekFish.portrait(forecast.fish)
	catch_label.text = Global.creek_trap_detail(deployed)
	take_button.visible = deployed == site
	take_button.disabled = Global.current_day < forecast.day
	guide_button.visible = deployed != site
	guide_button.text = "指路去%s" % CreekTrap.PLACES[deployed]

func _place_bait(bait: String) -> void:
	if Global.set_creek_trap(site, bait):
		AudioManager.play_sfx(SPLASH)
		receipt.hide()
		_refresh_options()

func _take_catch() -> void:
	var caught := Global.take_creek_trap(site)
	if caught.is_empty():
		return
	AudioManager.play_sfx(SPLASH)
	receipt.text = "%s已入鱼篓" % _fish_count(caught)
	receipt.show()
	_refresh_options()

func _follow_trap() -> void:
	var place: String = CreekTrap.PLACES[Global.creek_trap_site()]
	close_map()
	route_requested.emit(place)

func _fish_count(forecast: Dictionary) -> String:
	return "%s %d 尾" % [CreekFish.SPECIES[forecast.fish].name, forecast.amount]
