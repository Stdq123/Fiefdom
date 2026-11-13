@tool
extends Texture2D

@export var pixels: PortableCompressedTexture2D
@export var logical_size: Vector2i

var texture_rid := RID()

func _get_width() -> int:
	return logical_size.x

func _get_height() -> int:
	return logical_size.y

func _has_alpha() -> bool:
	return pixels.has_alpha()

func _get_rid() -> RID:
	if not texture_rid.is_valid():
		texture_rid = pixels.get_rid()
		RenderingServer.texture_set_size_override(texture_rid, logical_size.x, logical_size.y)
	return texture_rid

func _get_image() -> Image:
	var image := pixels.get_image()
	# AtlasTexture also uses the logical coordinates when cropping CPU images.
	image.resize(logical_size.x, logical_size.y, Image.INTERPOLATE_NEAREST)
	return image
