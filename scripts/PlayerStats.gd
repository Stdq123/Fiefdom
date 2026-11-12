extends Resource
class_name PlayerStats

signal xp_changed(art_name: String, new_xp: int, max_xp: int)
signal level_up(art_name: String, new_level: int)

# The Six Arts (君子六艺)
enum Art {
	RITES,    # 礼 - Worship/Etiquette
	MUSIC,    # 乐 - Music/Art
	ARCHERY,  # 射 - Combat/Hunting
	DRIVING,  # 御 - Driving/Travel
	LITERACY, # 书 - Reading/Politics
	MATH      # 数 - Calculation/Economy
}

# Data storage for each art: { "level": 1, "xp": 0, "max_xp": 100 }
var stats: Dictionary = {}

func _init() -> void:
	# Initialize all arts
	for art_key in Art.keys():
		stats[art_key] = {
			"level": 1,
			"xp": 0,
			"max_xp": 100
		}

func get_art_name(art_enum: int) -> String:
	match art_enum:
		Art.RITES: return "礼"
		Art.MUSIC: return "乐"
		Art.ARCHERY: return "射"
		Art.DRIVING: return "御"
		Art.LITERACY: return "书"
		Art.MATH: return "数"
	return "未识"

func get_stat(art_enum: int) -> Dictionary:
	var key = Art.keys()[art_enum]
	return stats.get(key, {})

func get_level(art_enum: int) -> int:
	var key = Art.keys()[art_enum]
	if not stats.has(key):
		return 1
	return stats[key]["level"]

func add_xp(art_enum: int, amount: int) -> void:
	var key = Art.keys()[art_enum]
	if not stats.has(key):
		return
		
	var data = stats[key]
	data["xp"] += amount
	
	# Check for level up
	while data["xp"] >= data["max_xp"]:
		data["xp"] -= data["max_xp"]
		data["level"] += 1
		data["max_xp"] = floor(data["max_xp"] * 1.5) # Simple curve
		emit_signal("level_up", get_art_name(art_enum), data["level"])
		print("Level Up! ", get_art_name(art_enum), " -> Level ", data["level"])
		
	emit_signal("xp_changed", get_art_name(art_enum), data["xp"], data["max_xp"])
