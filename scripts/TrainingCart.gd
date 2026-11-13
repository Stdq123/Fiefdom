extends Sprite2D
class_name TrainingCart

enum Heading { NORTH, WEST, SOUTH, EAST }
const HORSE_POSITIONS := [Vector2(0, -17), Vector2(-23, 4), Vector2(0, 37), Vector2(23, 4)]
const CART_FRAMES := [1, 0, 2, 0]
const STRIDE := 34.0

@onready var horse: Sprite2D = $Horse
@onready var hoof: AudioStreamPlayer2D = $Hoof

var stride := 0.0

func face(direction: Vector2) -> void:
	var heading: Heading
	if absf(direction.x) > absf(direction.y):
		heading = Heading.WEST if direction.x < 0.0 else Heading.EAST
	else:
		heading = Heading.NORTH if direction.y < 0.0 else Heading.SOUTH
	frame = CART_FRAMES[heading]
	flip_h = heading == Heading.EAST
	horse.position = HORSE_POSITIONS[heading]
	horse.frame_coords.y = heading

func roll(distance: float) -> void:
	if distance < 0.04:
		horse.frame_coords.x = 0
		return
	stride += distance
	if stride >= STRIDE:
		stride -= STRIDE
		if DisplayServer.get_name() != "headless":
			hoof.pitch_scale = 1.02 if hoof.pitch_scale < 1.0 else 0.94
			hoof.play()
	horse.frame_coords.x = 1 + mini(3, int(stride * 4.0 / STRIDE))

func halt() -> void:
	stride = 0.0
	roll(0.0)
	hoof.stop()
