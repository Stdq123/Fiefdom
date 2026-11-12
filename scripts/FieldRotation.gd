extends RefCounted
class_name FieldRotation

const VISIT_INTERVAL := 3

var promise_day := 0
var beans_day := 0
var harvest_day := 0
var field_number := 0
var crop_id := ""
var signed_day := 0

func waiting_for_harvest() -> bool:
	return promise_day > 0 and harvest_day == 0

func ready_to_sign() -> bool:
	return harvest_day > 0 and signed_day == 0
