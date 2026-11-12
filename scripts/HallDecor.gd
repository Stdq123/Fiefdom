class_name HallDecor
extends RefCounted

enum Slot { MAT, SHELF }

const DEFAULT_MAT := "reed_mat"
const DEFAULT_SHELF := "empty_shelf"

const CATALOG := {
	"reed_mat": {"slot": Slot.MAT, "name": "素苇席", "requirement": "", "region": Rect2i(0, 0, 60, 40)},
	"bare_floor": {"slot": Slot.MAT, "name": "空地板", "requirement": "", "region": Rect2i(), "icon": Rect2i(196, 40, 32, 22)},
	"blue_mat": {"slot": Slot.MAT, "name": "青纹苇席", "requirement": "建好亭西歇脚处", "region": Rect2i(60, 0, 60, 40)},
	"silk_mat": {"slot": Slot.MAT, "name": "西廊纹席", "requirement": "向陶辛交付样绸", "region": Rect2i(120, 0, 60, 40)},
	"wool_mat": {"slot": Slot.MAT, "name": "羊毛毡", "requirement": "请蔡娘织成短衣", "region": Rect2i(180, 0, 60, 40)},
	"empty_shelf": {"slot": Slot.SHELF, "name": "空案", "requirement": "", "region": Rect2i(), "icon": Rect2i(232, 40, 24, 26)},
	"tribute_sheaf": {"slot": Slot.SHELF, "name": "首贡谷穗", "requirement": "收获第一份公田作物", "region": Rect2i(0, 40, 24, 26)},
	"stream_jar": {"slot": Slot.SHELF, "name": "溪纹陶瓶", "requirement": "钓到第一尾鱼", "region": Rect2i(24, 40, 24, 26)},
	"water_slips": {"slot": Slot.SHELF, "name": "量水竹简", "requirement": "与石墨完成通水查验", "region": Rect2i(48, 40, 24, 26)},
	"gathering_bell": {"slot": Slot.SHELF, "name": "雅集铜铃", "requirement": "完成一次亭集合奏", "region": Rect2i(72, 40, 24, 26)},
	"raft_flag": {"slot": Slot.SHELF, "name": "夏筏竹标", "requirement": "一趟试筏穿过三道竹标", "region": Rect2i(96, 40, 24, 26)},
	"supper_bowl": {"slot": Slot.SHELF, "name": "围炉陶碗", "requirement": "为冬至围炉备饭", "region": Rect2i(120, 40, 24, 26)},
}
