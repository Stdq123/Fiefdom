@tool
extends EditorImportPlugin

const ART_TEXTURE := preload("res://addons/fiefdom_art/art_texture.gd")
const PIXEL_SCALE := 2

func _get_importer_name() -> String:
	return "fiefdom_art"

func _get_visible_name() -> String:
	return "Fiefdom 2× Pixel Art"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["svg", "png"])

func _get_save_extension() -> String:
	return "res"

func _get_resource_type() -> String:
	return "Texture2D"

func _get_import_order() -> int:
	return 0

func _get_priority() -> float:
	return 0.0

func _get_preset_count() -> int:
	return 1

func _get_preset_name(_preset_index: int) -> String:
	return "2× Pixel Art"

func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []

func _import(source_file: String, save_path: String, _options: Dictionary,
		_platform_variants: Array[String], _gen_files: Array[String]) -> Error:
	var image := Image.new()
	var source := FileAccess.get_file_as_bytes(source_file)
	var error := image.load_svg_from_buffer(source, PIXEL_SCALE) if source_file.ends_with(".svg") else image.load_png_from_buffer(source)
	if error != OK:
		return error
	if source_file.ends_with(".png"):
		image = _scale_pixel_art(image)
	image.fix_alpha_edges()
	var pixels := PortableCompressedTexture2D.new()
	pixels.set_keep_compressed_buffer(true)
	pixels.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	var texture := ART_TEXTURE.new()
	texture.logical_size = image.get_size() / PIXEL_SCALE
	texture.pixels = pixels
	return ResourceSaver.save(texture, save_path + ".res")

func _scale_pixel_art(source: Image) -> Image:
	var width := source.get_width()
	var height := source.get_height()
	var result := Image.create_empty(width * PIXEL_SCALE, height * PIXEL_SCALE, false, Image.FORMAT_RGBA8)
	# Scale2x follows diagonals in the existing palette. Keep each source pixel's alpha.
	for y in height:
		for x in width:
			var center := source.get_pixel(x, y)
			var above := source.get_pixel(x, maxi(y - 1, 0))
			var left := source.get_pixel(maxi(x - 1, 0), y)
			var right := source.get_pixel(mini(x + 1, width - 1), y)
			var below := source.get_pixel(x, mini(y + 1, height - 1))
			var diagonal := above != below and left != right
			var left_edge := diagonal and left.a == center.a
			var right_edge := diagonal and right.a == center.a
			var dx := x * PIXEL_SCALE
			var dy := y * PIXEL_SCALE
			result.set_pixel(dx, dy, left if left_edge and left == above else center)
			result.set_pixel(dx + 1, dy, right if right_edge and right == above else center)
			result.set_pixel(dx, dy + 1, left if left_edge and left == below else center)
			result.set_pixel(dx + 1, dy + 1, right if right_edge and right == below else center)
	return result
