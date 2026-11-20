extends Node2D

const DOOR_ART := preload("res://resources/estate-door.gdshader")
const OPEN_DISTANCE := 36.0
const CLOSE_DISTANCE := 48.0

static var _sill_texture: GradientTexture2D

@onready var _player: Player = $"../Player"
@onready var _threshold: Area2D = $Entrance

var _door_art: ShaderMaterial
var _sill_light: PointLight2D
var _has_leaves := false
var _opening := 0.0
var _opening_target := false

func _ready() -> void:
	set_process(false)

func paint_door(facade: Sprite2D, aperture: Rect2, has_leaves: bool) -> void:
	_has_leaves = has_leaves
	_opening = 0.0 if has_leaves else 1.0
	_door_art = ShaderMaterial.new()
	_door_art.shader = DOOR_ART
	_door_art.set_shader_parameter(&"aperture_origin", aperture.position)
	_door_art.set_shader_parameter(&"aperture_size", aperture.size)
	_door_art.set_shader_parameter(&"has_leaves", has_leaves)
	_door_art.set_shader_parameter(&"opening", _opening)
	facade.material = _door_art
	_sill_light = PointLight2D.new()
	_sill_light.name = "SillLight"
	_sill_light.texture = _door_light_texture()
	_sill_light.position = Vector2(aperture.get_center().x, aperture.end.y + 8.0)
	_sill_light.color = Color("#ffb578")
	_sill_light.range_z_min = -4
	_sill_light.range_z_max = 0
	facade.add_child(_sill_light)
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

func _refresh_light() -> void:
	var glow := Global.dusk_amount() * _opening if visible and not Global.is_indoors() else 0.0
	var energy := glow * 0.50
	if _sill_light.enabled == (glow > 0.0) and is_equal_approx(_sill_light.energy, energy):
		return
	_sill_light.enabled = glow > 0.0
	_sill_light.energy = energy
	_door_art.set_shader_parameter(&"lamp_glow", glow)

static func _door_light_texture() -> GradientTexture2D:
	if _sill_texture == null:
		var falloff := Gradient.new()
		falloff.set_color(0, Color.WHITE)
		falloff.add_point(0.36, Color(0.57, 0.57, 0.57))
		falloff.add_point(0.73, Color(0.11, 0.11, 0.11))
		falloff.set_color(falloff.get_point_count() - 1, Color.BLACK)
		_sill_texture = GradientTexture2D.new()
		_sill_texture.gradient = falloff
		_sill_texture.width = 40
		_sill_texture.height = 32
		_sill_texture.fill = GradientTexture2D.FILL_RADIAL
		_sill_texture.fill_from = Vector2(0.5, 0.5)
		_sill_texture.fill_to = Vector2(1.0, 0.5)
	return _sill_texture
