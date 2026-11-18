extends RefCounted

const SHEET_PATH := "res://assets/ui/council-implements.png"
const PLATE_SIZE := Vector2(144, 68)
const COLUMNS := {
	Global.TaxReformChoice.REFORMED: 0,
	Global.TaxReformChoice.TRADITIONAL: 1,
	Global.TaxReformChoice.DELAYED: 2,
}

static var _sheet: Texture2D

static func plate(choice: Global.TaxReformChoice) -> AtlasTexture:
	if not _sheet:
		_sheet = load(SHEET_PATH)
	var illustration := AtlasTexture.new()
	illustration.atlas = _sheet
	illustration.region = Rect2(Vector2(COLUMNS[choice] * PLATE_SIZE.x, 0), PLATE_SIZE)
	illustration.filter_clip = true
	return illustration
