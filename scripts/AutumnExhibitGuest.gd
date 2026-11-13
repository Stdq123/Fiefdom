extends Node2D

const CAST := "res://assets/characters/autumn-guests.svg"
const SHARING := "res://assets/world/autumn-sharing.svg"
const HOST := 3
const LANTERN_WATCH := 0.69
const ROUTES := [
	{"start": 0.025, "end": 0.145, "path": [Vector2(-40, 44), Vector2(-45, 34), Vector2(-40, 27)],
		"rest": Vector2(47, 63), "table": Vector2(-26, 13)},
	{"start": 0.065, "end": 0.187, "path": [Vector2(16, 51), Vector2(35, 48), Vector2(53, 39)],
		"rest": Vector2(72, 71), "table": Vector2(22, 13)},
	{"start": 0.103, "end": AutumnExhibit.LAST_ARRIVAL, "path": [Vector2(24, 53), Vector2(68, 52), Vector2(101, 29)],
		"rest": Vector2(100, 63), "table": Vector2(43, 15)},
	{"start": 0.0, "end": 0.05, "path": [Vector2(79, 9), Vector2(67, 8)],
		"rest": Vector2(67, 8)},
]
const HELLOS := [
	"我把空箩搁在台边了。你在地里收了什么？摆出来让大家认一认。",
	"我从西路过来，闻见新谷晒过的香气。等灯亮了，我还想坐一会。",
	"我揣着去年的几粒稷种来。看一眼各家收的穗子，就知道这一年雨水怎么样。",
]
const THANKS := [
	"这份%s我留到亭里，给今晚赶路的人尝尝。",
	"谢谢你的%s。等灯点上，我再沿西路送回去，和家里人分。",
	"我收下这份%s了。冬至要煮粥，我也会带一份菽来。",
]

@export var role := 0
@onready var motion: NeighborMotion = $Motion
@onready var parcel: Sprite2D = $Parcel
@onready var crop_mark: Sprite2D = $Parcel/Crop
@onready var hint: Label = $Hint

var speaker := ""
var route := Curve2D.new()
var icon: Texture2D

func _ready() -> void:
	speaker = VisitorData.MUSIC_HOST if role == HOST else AutumnExhibit.GUESTS[role]
	if role != HOST:
		for point in EstateLayout.festival_entrance():
			route.add_point(point)
	for point: Vector2 in ROUTES[role].path:
		route.add_point(point)
	if role == HOST:
		motion.set_art(speaker, null)
		icon = CharacterArt.dialogue_portrait(speaker, null, false)
	else:
		motion.set_motion_sheet(_art(CAST, Rect2(0, role * 96, 128, 96)))
		icon = _art(CAST, Rect2(0, role * 96, 32, 32))
	parcel.texture = _art(SHARING, Rect2(0, 32, 22, 16))

func _art(path: String, area: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = area
	atlas.filter_clip = true
	return atlas

func show_receipt(record: Dictionary) -> void:
	parcel.hide()
	if role != HOST and not record.is_empty() and record.shared:
		var picture := ItemManager.crop_picture(ItemManager.get_crop(record.crops[role]))
		crop_mark.texture = picture.texture
		crop_mark.self_modulate = picture.tint

func update_pose(clock: float, elapsed: float, shared: bool, snap := false) -> void:
	var timing: Dictionary = ROUTES[role]
	visible = clock >= timing.start
	if not visible:
		return
	var progress := smoothstep(timing.start, timing.end, clock)
	var point := route.sample_baked(route.get_baked_length() * progress)
	point = point.lerp(timing.rest, smoothstep(LANTERN_WATCH, 0.84, clock))
	if shared and role != HOST:
		var handoff := AutumnExhibit.handoff(role, elapsed)
		if progress >= 1.0:
			point = point.lerp(timing.table, smoothstep(0.0, 1.0, 1.0 - absf(handoff * 2.0 - 1.0)))
		parcel.visible = handoff >= 0.5
	var movement := point - position
	position = point
	if snap or movement.length_squared() < 0.001:
		if motion.walking or snap:
			motion.stand()
			motion.face(Vector2.DOWN)
	else:
		motion.walk(movement)
	parcel.position.x = -7.0 if motion.flip_h else 7.0

func can_interact_from(foot: Vector2) -> bool:
	return is_visible_in_tree() and global_position.distance_squared_to(foot) <= 20.0 * 20.0

func set_interaction_focused(active: bool) -> void:
	hint.visible = active
	if active:
		hint.text = GamepadInput.interact_hint(speaker)

func interact() -> void:
	GameEvents.autumn_guest_interacted.emit(self)

func remark() -> String:
	var record := Global.autumn_exhibit_record(Global.current_day)
	if role == HOST:
		if record.is_empty():
			return "把想摆的三样拿到台前。我替你记在秋社簿里，等灯亮了大家再坐一会。"
		var names := AutumnExhibit.names(record.crops)
		return ("%s都记入簿了，三份各有去处。" if record.shared else
			"%s都记入簿了。你带回去，回家的路上把样品放稳。") % names
	if not record.is_empty():
		var crop := ItemManager.crop_label(record.crops[role])
		if record.shared:
			return (THANKS[role] if parcel.visible else "谢谢你留了份%s给我。我一会儿就去台上取。") % crop
		return "刚在台上看见了你带来的%s。我还想看看旁边几家的收成。" % crop
	var previous := Global.current_day - maxi(1, Global.balance.days_per_solar_term) * Global.SOLAR_TERMS.size()
	var last := Global.autumn_exhibit_record(previous) if previous > 0 else {}
	if not last.is_empty() and last.shared:
		return "去年分来的%s我还记得。今年也来认一认你的收成。" % ItemManager.crop_label(last.crops[role])
	return HELLOS[role]
