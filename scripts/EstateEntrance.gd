extends Node2D

const DOOR_ART := preload("res://resources/estate-door.gdshader")
const OPEN_DISTANCE := 36.0
const CLOSE_DISTANCE := 48.0
const SPILL_WIDTH := 56
const SPILL_DEPTH := 36
const SPILL_RESOLUTION := 2

static var _sill_textures: Dictionary[int, ImageTexture] = {}

@onready var _player: Player = $"../Player"
@onready var _threshold: Area2D = $Entrance

var _door_art: ShaderMaterial
var _sill_light: PointLight2D
var _sill_edge: Vector2
var _has_leaves := false
var _opening := 0.0
var _opening_target := false
var _window_glow := -1.0

func _ready() -> void:
	set_process(false)
	GameEvents.estate_room_changed.connect(_update_room_light)

func _update_room_light(_room: Global.EstateRoom) -> void:
	if _door_art:
		_refresh_light()

func paint_door(facade: Sprite2D, aperture: Rect2, has_leaves: bool,
		window: Rect2, second_window := Rect2(), rail_y := -128.0) -> void:
	_has_leaves = has_leaves
	_opening = 0.0 if has_leaves else 1.0
	_window_glow = -1.0
	_door_art = ShaderMaterial.new()
	_door_art.shader = DOOR_ART
	_door_art.set_shader_parameter(&"aperture_origin", aperture.position)
	_door_art.set_shader_parameter(&"aperture_size", aperture.size)
	_door_art.set_shader_parameter(&"has_leaves", has_leaves)
	_door_art.set_shader_parameter(&"opening", _opening)
	_door_art.set_shader_parameter(&"window_left", Vector4(window.position.x, window.position.y, window.size.x, window.size.y))
	_door_art.set_shader_parameter(&"window_right",
		Vector4(second_window.position.x, second_window.position.y, second_window.size.x, second_window.size.y))
	_door_art.set_shader_parameter(&"window_rail_y", rail_y)
	facade.material = _door_art
	_sill_light = PointLight2D.new()
	_sill_light.name = "SillLight"
	_sill_light.texture = _door_light_texture(roundi(aperture.size.x))
	_sill_edge = Vector2(aperture.get_center().x, aperture.end.y - 1.0)
	_sill_light.color = Color("#ffb578")
	_sill_light.range_z_min = -4
	_sill_light.range_z_max = 0
	facade.add_child(_sill_light)
	_place_sill_light()
	_refresh_light()
	set_process(visible)

func set_available(available: bool) -> void:
	if visible == available:
		return
	visible = available
	for shape: CollisionShape2D in $Walls.get_children():
		shape.set_deferred("disabled", not available)
	set_process(visible and _door_art != null)
	if _door_art and not available:
		_opening_target = false
		_set_opening(0.0 if _has_leaves else 1.0)
		_refresh_light()

func present_exit() -> void:
	if _door_art:
		if _has_leaves:
			_opening_target = true
			_set_opening(1.0)
		_refresh_light()

func _process(delta: float) -> void:
	if _has_leaves:
		var foot := _threshold.to_local(_player.global_position)
		var depth := CLOSE_DISTANCE if _opening_target else OPEN_DISTANCE
		var side := 26.0 if _opening_target else 18.0
		_opening_target = absf(foot.x) < side and foot.y > -10.0 and foot.y < depth
		_set_opening(move_toward(_opening, float(_opening_target), delta * 6.25))
	_refresh_light()

func _set_opening(amount: float) -> void:
	if not is_equal_approx(amount, _opening):
		_opening = amount
		_door_art.set_shader_parameter(&"opening", _opening)
		_place_sill_light()

func _refresh_light() -> void:
	var lamps := Global.dusk_amount() if visible and not Global.is_indoors() else 0.0
	if not is_equal_approx(_window_glow, lamps):
		_window_glow = lamps
		_door_art.set_shader_parameter(&"window_glow", lamps)
	var glow := lamps * _opening
	var energy := glow * 0.50
	if _sill_light.enabled == (glow > 0.0) and is_equal_approx(_sill_light.energy, energy):
		return
	_sill_light.enabled = glow > 0.0
	_sill_light.energy = energy
	_door_art.set_shader_parameter(&"lamp_glow", glow)

func _place_sill_light() -> void:
	var reach := lerpf(0.63, 1.0, _opening)
	_sill_light.texture_scale = reach / SPILL_RESOLUTION
	_sill_light.position = _sill_edge + Vector2(0.0, SPILL_DEPTH * 0.5 * reach)

static func _door_light_texture(aperture_width: int) -> ImageTexture:
	if _sill_textures.has(aperture_width):
		return _sill_textures[aperture_width]
	var image := Image.create_empty(
		SPILL_WIDTH * SPILL_RESOLUTION, SPILL_DEPTH * SPILL_RESOLUTION, false, Image.FORMAT_RGB8)
	for y in image.get_height():
		var depth := (y + 0.5) / SPILL_RESOLUTION
		var half_width := (aperture_width + depth) * 0.39
		var softness := lerpf(1.4, 6.0, depth / SPILL_DEPTH)
		var falloff := smoothstep(0.0, 2.4, depth) * (1.0 - smoothstep(9.0, float(SPILL_DEPTH), depth))
		for x in image.get_width():
			# The indoor lamp is right of the doorway. Its light opens slightly left on the paving.
			var across := (x + 0.5) / SPILL_RESOLUTION - SPILL_WIDTH * 0.5 + depth * 0.10
			var intensity := falloff * smoothstep(0.0, softness, half_width - absf(across))
			image.set_pixel(x, y, Color(intensity, intensity, intensity))
	var texture := ImageTexture.create_from_image(image)
	_sill_textures[aperture_width] = texture
	return texture
