extends Control

signal close_requested

enum Page { CROPS, FISH, CRAFT }

enum Goods { MIXED_GRAIN, LEAVES, COCOONS, RAW_SILK, SILK_BOLT, WOOL, HERBS }

const GOODS_PATH := "res://assets/inventory/estate-goods.png"
const CROP_POCKETS := CropData.IDS + [CropStock.MIXED]
const POCKET_MINIMUM := Vector2(216, 64)
const ITEM_NAME_INK := Color("#ffe9bd")
const QUANTITY_INK := Color("#f1cf9d")

class Pocket:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	var icon := TextureRect.new()
	var name_label := Label.new()
	var quantity := Label.new()

@export var item_style: StyleBox
@export var empty_pocket_style: StyleBox

@onready var goods_art: Texture2D = load(GOODS_PATH)
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
@onready var herb_pouch: PanelContainer = %HerbPouch
@onready var herb_effect: Label = %HerbEffect
@onready var use_herbs_button: Button = %UseHerbs
@onready var herb_notice: Label = %HerbNotice
@onready var items: GridContainer = %Items
@onready var empty: Label = %Empty

var page := Page.CROPS
var pockets: Array[Pocket] = []

func _ready() -> void:
	%BagIcon.texture = HUDIcons.icon(HUDIcons.Symbol.BACKPACK)
	%CoinIcon.texture = HUDIcons.icon(HUDIcons.Symbol.COIN)
	%HerbIcon.texture = _goods_icon(Goods.HERBS)
	for index in CROP_POCKETS.size():
		pockets.append(_new_pocket())
	close_button.pressed.connect(close_requested.emit)
	crop_tab.pressed.connect(select_page.bind(Page.CROPS))
	fish_tab.pressed.connect(select_page.bind(Page.FISH))
	craft_tab.pressed.connect(select_page.bind(Page.CRAFT))
	eat_button.pressed.connect(_eat)
	use_herbs_button.pressed.connect(_use_herbs)
	GameEvents.inventory_changed.connect(_refresh_items.unbind(1))
	GameEvents.fish_changed.connect(_refresh_items)
	GameEvents.silk_changed.connect(_refresh_items)
	GameEvents.sheepfold_changed.connect(_refresh_items)
	GameEvents.money_changed.connect(_refresh_wallet)
	GameEvents.travel_meal_changed.connect(_refresh_meal)
	GameEvents.wild_herbs_changed.connect(_refresh_herbs)
	select_page(page)
	_refresh_wallet(Global.money)
	_refresh_meal()
	_refresh_herbs()
	close_button.grab_focus()

func select_page(selected: Page) -> void:
	page = selected
	crop_tab.set_pressed_no_signal(page == Page.CROPS)
	fish_tab.set_pressed_no_signal(page == Page.FISH)
	craft_tab.set_pressed_no_signal(page == Page.CRAFT)
	_refresh_items()

func _refresh_items() -> void:
	for index in pockets.size():
		var pocket := pockets[index]
		pocket.row.hide()
		pocket.icon.texture = null
		pocket.panel.name = "Empty%d" % index
		pocket.panel.add_theme_stylebox_override("panel", empty_pocket_style)
	var filled := 0
	var empty_caption := ""
	match page:
		Page.CROPS:
			for index in CROP_POCKETS.size():
				var id: String = CROP_POCKETS[index]
				var count := Global.crop_stock.count(id)
				if count > 0:
					_show_item(index, id, ItemManager.crop_label(id), "%d 份" % count, _stored_crop_icon(id))
					filled += 1
			empty_caption = "私仓暂无作物"
		Page.FISH:
			for index in CreekFish.IDS.size():
				var id: String = CreekFish.IDS[index]
				var count := Global.fish_count(id)
				if count > 0:
					_show_item(index, id, CreekFish.SPECIES[id].name, "%d 尾" % count, CreekFish.portrait(id))
					filled += 1
			empty_caption = "鱼篓里还没有鱼"
		Page.CRAFT:
			filled = _show_craft_items()
			empty_caption = "暂无工艺材料"
	empty.text = empty_caption if filled == 0 else ""

func _show_craft_items() -> int:
	var workshop := Global.silk_workshop
	var filled := 0
	filled += _show_material(Goods.LEAVES, "mulberry_leaves", "桑叶", workshop.leaves, "片")
	filled += _show_material(Goods.COCOONS, "cocoons", "蚕茧", workshop.cocoons, "只")
	filled += _show_material(Goods.RAW_SILK, "raw_silk", "生丝", workshop.raw_silk, "份")
	filled += _show_material(Goods.SILK_BOLT, "silk", "丝绸", workshop.bolts, "匹")
	filled += _show_material(Goods.WOOL, "wool", "羊毛", Global.sheepfold.wool, "份")
	return filled

func _show_material(kind: Goods, id: String, display_name: String, count: int, unit: String) -> int:
	if count <= 0:
		return 0
	_show_item(kind - Goods.LEAVES, id, display_name, "%d %s" % [count, unit], _goods_icon(kind))
	return 1

func _stored_crop_icon(id: String) -> Texture2D:
	if id == CropStock.MIXED:
		return _goods_icon(Goods.MIXED_GRAIN)
	if HUDIcons.CROPS.has(id):
		return HUDIcons.icon(HUDIcons.CROPS[id])
	return ItemManager.crop_picture(ItemManager.get_crop(id)).texture

func _new_pocket() -> Pocket:
	var pocket := Pocket.new()
	var slot := pocket.panel
	slot.custom_minimum_size = POCKET_MINIMUM
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items.add_child(slot)
	var row := pocket.row
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	slot.add_child(row)
	var icon := pocket.icon
	icon.custom_minimum_size = Vector2(34, 34)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name_label := pocket.name_label
	name_label.name = "Name"
	name_label.add_theme_color_override("font_color", ITEM_NAME_INK)
	text.add_child(name_label)
	var count_label := pocket.quantity
	count_label.name = "Quantity"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_color_override("font_color", QUANTITY_INK)
	text.add_child(count_label)
	return pocket

func _show_item(index: int, id: String, label: String, quantity: String, texture: Texture2D) -> void:
	var pocket := pockets[index]
	pocket.panel.name = id
	pocket.panel.add_theme_stylebox_override("panel", item_style)
	pocket.name_label.text = label
	pocket.quantity.text = quantity
	pocket.icon.texture = texture
	pocket.row.show()

func _goods_icon(kind: Goods) -> AtlasTexture:
	var icon := AtlasTexture.new()
	icon.atlas = goods_art
	icon.region = Rect2(kind * 32, 0, 32, 32)
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
	_refresh_focus()

func _refresh_herbs() -> void:
	herb_pouch.visible = Global.wild_herbs_packed
	herb_effect.text = "最多恢复 %d 气血" % Global.balance.wild_herb_healing
	_refresh_focus()

func _refresh_focus() -> void:
	var buttons: Array[Button] = [close_button, crop_tab, fish_tab, craft_tab]
	if eat_button.visible:
		buttons.append(eat_button)
	if herb_pouch.visible:
		buttons.append(use_herbs_button)
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

func _use_herbs() -> void:
	var recovered := Global.use_packed_wild_herbs()
	if recovered > 0:
		AudioManager.play_ui_sfx(0.86)
		herb_notice.text = "敷了野药 · 气血 +%d" % recovered
		close_button.grab_focus()
		GamepadInput.snap_pointer_to_focus()
	else:
		herb_notice.text = "气血充足，先带着野药。"
	herb_notice.show()
