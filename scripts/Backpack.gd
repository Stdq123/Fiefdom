extends Control

signal close_requested

enum Page { CROPS, FISH, CRAFT }

enum Goods { MIXED_GRAIN, LEAVES, COCOONS, RAW_SILK, SILK_BOLT, WOOL, HERBS }

const GOODS_PATH := "res://assets/inventory/estate-goods.png"
const HARVEST_ART := preload("res://assets/inventory/crop-harvests.png")
const CROP_POCKETS := CropData.IDS + [CropStock.MIXED]
const PANEL_FOCUS := preload("res://scripts/PanelFocus.gd")
const POCKET_MINIMUM := Vector2(216, 82)
const ITEM_NAME_INK := Color("#ffe9bd")
const QUANTITY_INK := Color("#f1cf9d")
const EMPTY_SHELVES := ["私仓暂无作物", "鱼篓里还没有鱼", "暂无工艺材料"]
const ITEM_USES := {
	"millet": "可转作口粮，也可与菽在路灶做成菽黍饭。",
	"sorghum": "可转作口粮，也可在西市卖出。秋季时令单常用。",
	"rice": "可转作口粮，也可与溪鱼在路灶做成稻鱼羹。",
	"wheat": "可在路灶做成麦饼。冬至围炉时也可拿来煮粥。",
	"beans": "可与黍做成菽黍饭，或与麦同煮冬至围炉的粥。",
	"mulberry": "私仓里的作物可卖出或转粮。采下的桑叶另存于工艺材料。",
	"hemp": "可在西市卖出。冬季时令单有时会收麻。",
	CropStock.MIXED: "旧档中未分品种的作物，可卖出或转作口粮。",
	"mulberry_leaves": "在蚕棚投叶喂蚕。查看蚕桑页可核对下一批需要多少片。",
	"cocoons": "带到蚕棚缫丝轮，抽成生丝。",
	"raw_silk": "在蚕棚的织机上织成丝绸。",
	"silk": "可在西市绸摊出售，也可拿一匹样绸给陶辛。",
	"wool": "可出售，也可带到西市请蔡娘织一件羊毛短衣。",
}

class Pocket:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	var icon := TextureRect.new()
	var name_label := Label.new()
	var quantity := Label.new()
	var button := Button.new()
	var id := ""
	var unit := ""

@export var item_style: StyleBox
@export var empty_pocket_style: StyleBox
@export var selected_pocket_style: StyleBox

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
@onready var detail_name: Label = %DetailName
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_use: Label = %DetailUse
@onready var detail_order: Label = %DetailOrder
@onready var browse_hint: Label = %BrowseHint

var page := Page.CROPS
var pockets: Array[Pocket] = []
var _selected_by_page: Array[int] = [-1, -1, -1]

func _ready() -> void:
	add_to_group(&"backpack_panel")
	%BagIcon.texture = HUDIcons.icon(HUDIcons.Symbol.BACKPACK)
	%CoinIcon.texture = HUDIcons.icon(HUDIcons.Symbol.COIN)
	%HerbIcon.texture = _item_icon(goods_art, Goods.HERBS)
	for index in CROP_POCKETS.size():
		pockets.append(_new_pocket(index))
	for label: Label in find_children("*", "Label", true, false):
		InterfaceFont.scale_reading_text(label)
	for button in [close_button, crop_tab, fish_tab, craft_tab, eat_button, use_herbs_button]:
		InterfaceFont.scale_reading_text(button)
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
	GamepadInput.changed.connect(_refresh_browse_hint)
	_refresh_browse_hint()
	select_page(page)
	_refresh_wallet(Global.money)
	_refresh_meal()
	_refresh_herbs()
	close_button.grab_focus()

func select_page(selected: Page) -> void:
	var changed := selected != page
	if changed and is_visible_in_tree():
		AudioManager.play_menu_cue(AudioManager.MenuCue.PAGE)
	page = selected
	crop_tab.set_pressed_no_signal(page == Page.CROPS)
	fish_tab.set_pressed_no_signal(page == Page.FISH)
	craft_tab.set_pressed_no_signal(page == Page.CRAFT)
	if changed:
		# The same pocket buttons are reused for every shelf.
		_page_tab().grab_focus()
	_refresh_items()

func cycle_page(step: int) -> void:
	select_page(posmod(page + step, EMPTY_SHELVES.size()) as Page)

func _page_tab() -> Button:
	return [crop_tab, fish_tab, craft_tab][page]

func _refresh_browse_hint() -> void:
	browse_hint.text = "十字键选格 · LB/RB 翻页" if GamepadInput.active else "点击物品或用方向键选格 · Tab 切换焦点"

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventAction:
		var focus := PANEL_FOCUS.input_owner(self)
		if focus:
			PANEL_FOCUS.keep_navigation_inside(self, focus, event)

func _refresh_items() -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	for index in pockets.size():
		var pocket := pockets[index]
		pocket.id = ""
		pocket.row.hide()
		pocket.icon.texture = null
		pocket.panel.name = "Empty%d" % index
		pocket.panel.add_theme_stylebox_override("panel", empty_pocket_style)
	match page:
		Page.CROPS:
			for index in CROP_POCKETS.size():
				var id: String = CROP_POCKETS[index]
				var count := Global.crop_stock.count(id)
				if count > 0:
					_show_item(index, id, ItemManager.crop_label(id), count, "份", _stored_crop_icon(index))
		Page.FISH:
			for index in CreekFish.IDS.size():
				var id: String = CreekFish.IDS[index]
				var count := Global.fish_count(id)
				if count > 0:
					_show_item(index, id, CreekFish.SPECIES[id].name, count, "尾", CreekFish.portrait(id))
		Page.CRAFT:
			_show_craft_items()
	var first_filled := -1
	for index in pockets.size():
		var pocket := pockets[index]
		pocket.button.visible = not pocket.id.is_empty()
		if first_filled == -1 and pocket.button.visible:
			first_filled = index
	var selected := _selected_by_page[page]
	if selected < 0 or pockets[selected].id.is_empty():
		_selected_by_page[page] = first_filled
	_refresh_detail()
	_refresh_focus()
	if previous_focus and items.is_ancestor_of(previous_focus) and not previous_focus.is_visible_in_tree():
		_page_tab().grab_focus()
		GamepadInput.snap_pointer_to_focus()

func _show_craft_items() -> void:
	var workshop := Global.silk_workshop
	_show_material(Goods.LEAVES, "mulberry_leaves", "桑叶", workshop.leaves, "片")
	_show_material(Goods.COCOONS, "cocoons", "蚕茧", workshop.cocoons, "只")
	_show_material(Goods.RAW_SILK, "raw_silk", "生丝", workshop.raw_silk, "份")
	_show_material(Goods.SILK_BOLT, "silk", "丝绸", workshop.bolts, "匹")
	_show_material(Goods.WOOL, "wool", "羊毛", Global.sheepfold.wool, "份")

func _show_material(kind: Goods, id: String, display_name: String, count: int, unit: String) -> void:
	if count > 0:
		_show_item(kind - Goods.LEAVES, id, display_name, count, unit, _item_icon(goods_art, kind))

func _stored_crop_icon(index: int) -> AtlasTexture:
	if CROP_POCKETS[index] == CropStock.MIXED:
		return _item_icon(goods_art, Goods.MIXED_GRAIN)
	return _item_icon(HARVEST_ART, index)

func _new_pocket(index: int) -> Pocket:
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
	var inspect := pocket.button
	inspect.name = "Inspect"
	inspect.flat = true
	inspect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	inspect.focus_entered.connect(_select_pocket.bind(index))
	inspect.pressed.connect(_select_pocket.bind(index))
	slot.add_child(inspect)
	return pocket

func _show_item(index: int, id: String, label: String, count: int, unit: String, texture: Texture2D) -> void:
	var pocket := pockets[index]
	pocket.id = id
	pocket.unit = unit
	pocket.panel.name = id
	pocket.name_label.text = label
	pocket.quantity.text = "%d %s" % [count, unit]
	pocket.icon.texture = texture
	pocket.button.accessibility_name = "%s · %s" % [label, pocket.quantity.text]
	pocket.button.accessibility_description = ""
	pocket.row.show()

func _select_pocket(index: int) -> void:
	if index == _selected_by_page[page] or pockets[index].id.is_empty():
		return
	_selected_by_page[page] = index
	_refresh_detail()
	_refresh_focus()

func _refresh_detail() -> void:
	var selected := _selected_by_page[page]
	for index in pockets.size():
		var pocket := pockets[index]
		if not pocket.id.is_empty():
			pocket.panel.add_theme_stylebox_override("panel", selected_pocket_style if index == selected else item_style)
	var stocked := selected >= 0
	detail_icon.visible = stocked
	detail_use.visible = stocked
	if not stocked:
		detail_icon.texture = null
		detail_name.text = EMPTY_SHELVES[page]
		detail_order.hide()
		return
	var pocket := pockets[selected]
	detail_icon.texture = pocket.icon.texture
	detail_name.text = pocket.button.accessibility_name
	if CreekFish.SPECIES.has(pocket.id):
		var fish: Dictionary = CreekFish.SPECIES[pocket.id]
		detail_use.text = "西市鱼摊每尾可换 %d 铜钱或 %d 份口粮。%s" % [fish.copper, fish.food, fish.habitat]
	else:
		detail_use.text = ITEM_USES.get(pocket.id, "")
	detail_order.text = _order_caption(pocket.id, pocket.unit)
	detail_order.visible = not detail_order.text.is_empty()
	pocket.button.accessibility_description = detail_use.text
	if detail_order.visible:
		pocket.button.accessibility_description += "\n" + detail_order.text

func _order_caption(id: String, unit: String) -> String:
	var schedule := Global.season_order()
	if Global.season_order_delivered_at(schedule) > 0:
		return ""
	var cargo_id := SeasonOrders.SILK_ITEM if id == "silk" else id
	var need: int = SeasonOrders.cargo(schedule.order).get(cargo_id, 0)
	if need == 0:
		return ""
	var gap := need - Global.season_order_stock(cargo_id)
	var status := "还差 %d" % gap if gap > 0 else "本项已备足"
	return "本季「%s」需 %d %s · %s" % [schedule.order.title, need, unit, status]

func _item_icon(atlas: Texture2D, column: int) -> AtlasTexture:
	var icon := AtlasTexture.new()
	icon.atlas = atlas
	icon.region = Rect2(column * 32, 0, 32, 32)
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
	for pocket in pockets:
		if pocket.button.visible:
			buttons.append(pocket.button)
	var selected := _selected_by_page[page]
	var selected_item: Button = pockets[selected].button if selected >= 0 else null
	for tab in [crop_tab, fish_tab, craft_tab]:
		tab.focus_neighbor_top = tab.get_path_to(close_button)
		tab.focus_neighbor_bottom = tab.get_path_to(selected_item) if selected_item else NodePath()
	close_button.focus_neighbor_bottom = close_button.get_path_to(_page_tab())
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
