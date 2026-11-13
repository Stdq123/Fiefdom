extends Control

signal close_requested

enum Page { CROPS, FISH, CRAFT }

const FLEECE := preload("res://assets/world/sheepfold/yard.svg")
const SACK := preload("res://assets/world/estate-storage.svg")
const SILK_MATERIALS := preload("res://assets/inventory/silk-materials.svg")
const QUANTITY_INK := Color("#5f422d")

@export var item_style: StyleBox

@onready var close_button: Button = %Close
@onready var crop_tab: Button = %CropTab
@onready var fish_tab: Button = %FishTab
@onready var craft_tab: Button = %CraftTab
@onready var wallet: Label = %Wallet
@onready var meal_name: Label = %MealName
@onready var meal_icon: TextureRect = %MealIcon
@onready var meal_effect: Label = %MealEffect
@onready var eat_button: Button = %Eat
@onready var meal_notice: Label = %MealNotice
@onready var items: GridContainer = %Items
@onready var empty: Label = %Empty

var page := Page.CROPS

func _ready() -> void:
	close_button.pressed.connect(close_requested.emit)
	crop_tab.pressed.connect(select_page.bind(Page.CROPS))
	fish_tab.pressed.connect(select_page.bind(Page.FISH))
	craft_tab.pressed.connect(select_page.bind(Page.CRAFT))
	eat_button.pressed.connect(_eat)
	GameEvents.inventory_changed.connect(_refresh_items.unbind(1))
	GameEvents.fish_changed.connect(_refresh_items)
	GameEvents.silk_changed.connect(_refresh_items)
	GameEvents.sheepfold_changed.connect(_refresh_items)
	GameEvents.money_changed.connect(_refresh_wallet)
	GameEvents.travel_meal_changed.connect(_refresh_meal)
	select_page(page)
	_refresh_wallet(Global.money)
	_refresh_meal()
	close_button.grab_focus()

func select_page(selected: Page) -> void:
	page = selected
	crop_tab.set_pressed_no_signal(page == Page.CROPS)
	fish_tab.set_pressed_no_signal(page == Page.FISH)
	craft_tab.set_pressed_no_signal(page == Page.CRAFT)
	_refresh_items()

func _refresh_items() -> void:
	for row in items.get_children():
		items.remove_child(row)
		row.queue_free()
	match page:
		Page.CROPS:
			for id: String in CropStock.IDS:
				var count := Global.crop_stock.count(id)
				if count == 0:
					continue
				var icon: Texture2D = (_atlas(SACK, Rect2(16, 0, 16, 16)) if id == CropStock.MIXED
					else ItemManager.crop_picture(ItemManager.get_crop(id)).texture)
				_add_item(id, ItemManager.crop_label(id), "%d 份" % count, icon)
			empty.text = "私仓暂无作物"
		Page.FISH:
			for id: String in CreekFish.IDS:
				var count := Global.fish_count(id)
				if count > 0:
					_add_item(id, CreekFish.SPECIES[id].name, "%d 尾" % count, CreekFish.portrait(id))
			empty.text = "鱼篓里还没有鱼"
		Page.CRAFT:
			_add_craft_items()
			empty.text = "暂无工艺材料"
	empty.visible = items.get_child_count() == 0

func _add_craft_items() -> void:
	var workshop := Global.silk_workshop
	if workshop.leaves > 0:
		_add_item("mulberry_leaves", "桑叶", "%d 片" % workshop.leaves, _atlas(SILK_MATERIALS, Rect2(0, 0, 16, 16)))
	if workshop.cocoons > 0:
		_add_item("cocoons", "蚕茧", "%d 只" % workshop.cocoons, _atlas(SILK_MATERIALS, Rect2(16, 0, 16, 16)))
	if workshop.raw_silk > 0:
		_add_item("raw_silk", "生丝", "%d 份" % workshop.raw_silk, _atlas(SILK_MATERIALS, Rect2(32, 0, 16, 16)))
	if workshop.bolts > 0:
		_add_item("silk", "丝绸", "%d 匹" % workshop.bolts, ItemManager.season_item_picture(SeasonOrders.SILK_ITEM).texture)
	if Global.sheepfold.wool > 0:
		_add_item("wool", "羊毛", "%d 份" % Global.sheepfold.wool, _atlas(FLEECE, Rect2(102, 18, 18, 16)))

func _add_item(id: String, label: String, quantity: String, texture: Texture2D) -> void:
	var slot := PanelContainer.new()
	slot.name = id
	slot.custom_minimum_size = Vector2(0, 64)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", item_style)
	items.add_child(slot)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	slot.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = label
	text.add_child(name_label)
	var count_label := Label.new()
	count_label.name = "Quantity"
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", QUANTITY_INK)
	count_label.text = quantity
	text.add_child(count_label)

func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var icon := AtlasTexture.new()
	icon.atlas = texture
	icon.region = region
	icon.filter_clip = true
	return icon

func _refresh_wallet(amount: int) -> void:
	wallet.text = "%d 枚" % amount

func _refresh_meal() -> void:
	var meal := Global.travel_meal
	var packed := not meal.is_empty()
	meal_icon.visible = packed
	meal_effect.visible = packed
	eat_button.visible = packed
	meal_name.text = TravelMeal.RECIPES[meal].name if packed else "未携带路餐"
	if packed:
		meal_icon.texture = TravelMeal.icon(meal)
		meal_effect.text = TravelMeal.describe_recovery(TravelMeal.benefits(meal, Global.balance))
	var buttons: Array[Button] = [close_button, crop_tab, fish_tab, craft_tab]
	if packed:
		buttons.append(eat_button)
	for index in buttons.size():
		var button := buttons[index]
		button.focus_next = button.get_path_to(buttons[(index + 1) % buttons.size()])
		button.focus_previous = button.get_path_to(buttons[(index + buttons.size() - 1) % buttons.size()])

func _eat() -> void:
	var meal: String = TravelMeal.RECIPES[Global.travel_meal].name
	if Global.eat_travel_meal():
		AudioManager.play_ui_sfx(0.86)
		meal_notice.text = "已吃下" + meal
		close_button.grab_focus()
		GamepadInput.snap_pointer_to_focus()
	else:
		meal_notice.text = "眼下用不着这份路餐，先带着。"
	meal_notice.show()
