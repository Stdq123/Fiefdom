extends RefCounted
class_name KeyBindings

const UP := &"walk_up"
const LEFT := &"walk_left"
const DOWN := &"walk_down"
const RIGHT := &"walk_right"
const INTERACT := &"interact"
const MAP := &"open_map"
const BACKPACK := &"open_backpack"
const ALMANAC := &"open_almanac"
const MEAL := &"eat_travel_meal"
const RHYTHM := &"rhythm"
const FILL := &"fill_channel"
const ROTATE := &"rotate_channel"
const SEEDS: Array[StringName] = [&"seed_1", &"seed_2", &"seed_3", &"seed_4", &"seed_5", &"seed_6", &"seed_7"]

const DEFAULTS: Dictionary[StringName, Key] = {
	UP: KEY_W, LEFT: KEY_A, DOWN: KEY_S, RIGHT: KEY_D,
	INTERACT: KEY_E, MAP: KEY_M, BACKPACK: KEY_I, ALMANAC: KEY_C, MEAL: KEY_F, RHYTHM: KEY_SPACE,
	FILL: KEY_SHIFT, ROTATE: KEY_R,
	&"seed_1": KEY_1, &"seed_2": KEY_2, &"seed_3": KEY_3, &"seed_4": KEY_4,
	&"seed_5": KEY_5, &"seed_6": KEY_6, &"seed_7": KEY_7,
}
const LABELS := {
	UP: "向上", LEFT: "向左", DOWN: "向下", RIGHT: "向右",
	INTERACT: "互动", MAP: "舆图", BACKPACK: "背包", ALMANAC: "历书", MEAL: "食用路餐", RHYTHM: "敲钟或收线",
	FILL: "填渠（按住）", ROTATE: "放样换弯",
}
const MENU_KEYS := [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_BACKTAB]

static func label(action: StringName) -> String:
	var seed := SEEDS.find(action)
	return ItemManager.crop_label(CropData.IDS[seed]) if seed >= 0 else LABELS[action]

static func accepts(action: StringName, code: Key) -> bool:
	if code == KEY_NONE or code in MENU_KEYS or code in [KEY_CTRL, KEY_ALT, KEY_META]:
		return false
	if (code == KEY_SPACE and action != RHYTHM) or (code == KEY_SHIFT and action != FILL):
		return false
	return not OS.get_keycode_string(code).is_empty()

static func key_text(code: Key) -> String:
	if code == KEY_SPACE:
		return "空格"
	var local := code if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_label_from_physical(code)
	return OS.get_keycode_string(local if local != KEY_NONE else code)
