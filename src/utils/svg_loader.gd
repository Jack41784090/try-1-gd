class_name SvgLoader
extends RefCounted
## Runtime texture loader for SVG (and raster) files read straight off disk.
## Centralizes the load-from-string pattern used by the canvas demo and the rig
## cutscene hot-reload so scenery props can share the same path.

const DEFAULT_SCALE: float = 4.0


static func load_svg(path: String, scale: float = DEFAULT_SCALE) -> Texture2D:
## Accepts a res://, user://, or absolute filesystem path. SVGs are rasterized
## at `scale`; other formats load as-is. Returns null on any failure.
	var abs_path := path
	if path.begins_with("res://") or path.begins_with("user://"):
		abs_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null

	if abs_path.to_lower().ends_with(".svg"):
		var file := FileAccess.open(abs_path, FileAccess.READ)
		if not file:
			return null
		var svg_text := file.get_as_text()
		file.close()
		var image := Image.new()
		if image.load_svg_from_string(svg_text, scale) != OK:
			return null
		return ImageTexture.create_from_image(image)

	var img := Image.new()
	if img.load(abs_path) != OK:
		return null
	return ImageTexture.create_from_image(img)
