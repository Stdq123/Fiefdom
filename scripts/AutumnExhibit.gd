extends RefCounted
class_name AutumnExhibit

const TERM := "秋分"
const NAME := "秋社"
const SAMPLE_COUNT := 3
const CROPS := ["millet", "sorghum", "rice", "wheat", "beans", "hemp"]
const GUESTS := ["阿绥", "林蓼", "禾伯"]
const LAST_ARRIVAL := 0.225
const DISPLAY_SECONDS := 2.25
const HANDOFF_SECONDS := 3.65

static func handoff(index: int, elapsed: float) -> float:
	return 1.0 if elapsed < 0.0 else clampf((elapsed - 0.55 - float(index) * 0.48) / 2.05, 0.0, 1.0)

static func portions(crops: Array) -> Dictionary:
	if crops.size() != SAMPLE_COUNT:
		return {}
	var chosen := {}
	for id in crops:
		if id in CROPS:
			chosen[id] = 1
	return chosen if chosen.size() == SAMPLE_COUNT else {}

static func names(crops: Array) -> String:
	var labels := PackedStringArray()
	for id: String in crops:
		labels.append(ItemManager.crop_label(id))
	return "、".join(labels)
