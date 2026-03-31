extends Control
## AI SVG Drawing Canvas — Edit .tscn and .svg files, see results via screenshot.
##
## Loads a canvas .tscn file, scans Sprite2D children for "svg_path" metadata,
## loads SVGs at runtime via Image.load_svg_from_string(), and applies as textures.
## Auto-reloads on file changes. Includes rig preview mode for warrior body parts.
##
## Usage: godot-mono --path . scenes/demos/canvas_demo.tscn
##
## Commands:
##   screenshot/ss — Save viewport screenshot to /tmp/condor_screenshot.png
##   zoom <f>      — Set camera zoom (0.1–10.0)
##   zoom_in/zi    — Zoom ×1.5
##   zoom_out/zo   — Zoom ÷1.5
##   pan <x> <y>   — Set camera position
##   center        — Reset camera to origin, zoom 1.0
##   reload/r      — Force reload all SVGs + scene
##   load <name>   — Load canvas from scenes/demos/canvas/<name>.tscn
##   info/i        — Print camera state, loaded file, tracked SVGs
##   tree          — Print node tree of canvas content
##   bg <hex>      — Change background color (e.g. bg #1a1a2e)
##   grid          — Toggle reference grid overlay
##   rig [class]   — Switch to rig preview mode (landsknecht, healer, etc.)
##   anim <name>   — Play rig animation (idle, walk, attack, defend, hurt, die)
##   stop          — Stop rig animation
##   help          — Show commands

const SCREENSHOT_PATH := "/tmp/condor_screenshot.png"
const CANVAS_BASE := "res://scenes/demos/canvas/"
const SVG_BASE := "res://scenes/demos/canvas/svgs/"
const RIG_SVG_BASE := "res://scenes/demos/canvas/svgs/rig/"
const DEFAULT_CANVAS := "default"
const SVG_RENDER_SCALE := 4.0

const BONE_NAMES: Array[String] = [
	"Head", "Torso", "Hips",
	"LeftArm", "LeftForearm", "LeftHand",
	"RightArm", "RightForearm", "RightHand",
	"LeftLeg", "LeftShin", "LeftFoot",
	"RightLeg", "RightShin", "RightFoot",
]

const BONE_FILE_MAP: Dictionary = {
	"Head": "head", "Torso": "torso", "Hips": "hips",
	"LeftArm": "leftarm", "LeftForearm": "leftforearm", "LeftHand": "lefthand",
	"RightArm": "rightarm", "RightForearm": "rightforearm", "RightHand": "righthand",
	"LeftLeg": "leftleg", "LeftShin": "leftshin", "LeftFoot": "leftfoot",
	"RightLeg": "rightleg", "RightShin": "rightshin", "RightFoot": "rightfoot",
}

var _viewport: SubViewport
var _camera: Camera2D
var _content_root: Node2D
var _background: ColorRect
var _info_label: Label
var _grid_visible := false
var _grid_node: Node2D

var _loaded_canvas_name := ""
var _loaded_canvas_path := ""
var _canvas_node: Node
var _canvas_mtime: int = 0

var _svg_mtimes: Dictionary = {}
var _svg_textures: Dictionary = {}
var _svg_sprites: Dictionary = {}

var _shader_mtimes: Dictionary = {}
var _shader_materials: Dictionary = {}

var _watch_timer := 0.0
const WATCH_INTERVAL := 0.5

var _busy := false
var _pending_file_reload := false
var _debounce_timer := 0.0
const DEBOUNCE_INTERVAL := 0.3

var _mode := "canvas"
var _rig: WarriorRig
var _rig_class_name := ""
var _rig_svg_mtimes: Dictionary = {}

var _stdin_thread: Thread
var _stdin_mutex: Mutex
var _stdin_buffer: Array[String] = []
var _command_queue: Array[String] = []
var _should_quit := false
var _initialized := false


func _ready() -> void:
	_build_scene_tree()
	_start_stdin_thread()
	_load_canvas(DEFAULT_CANVAS)
	_initialized = true
	_out("Canvas ready. Type 'help' for commands.")


func _process(delta: float) -> void:
	if not _initialized:
		return

	_drain_stdin()
	if not _busy:
		_process_commands()

	if _debounce_timer > 0.0:
		_debounce_timer -= delta
		if _debounce_timer <= 0.0 and _pending_file_reload and not _busy:
			_debounce_timer = 0.0
			_pending_file_reload = false
			_do_file_reload()

	_watch_timer += delta
	if _watch_timer >= WATCH_INTERVAL:
		_watch_timer = 0.0
		if not _busy:
			_check_file_changes()

	_update_info_label()


func _exit_tree() -> void:
	_should_quit = true
	if _stdin_thread and _stdin_thread.is_started():
		_stdin_thread.wait_to_finish()


#region Scene Tree Setup

func _build_scene_tree() -> void:
	_background = ColorRect.new()
	_background.color = Color(0.12, 0.12, 0.14, 1.0)
	_background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_background)

	var vpc := SubViewportContainer.new()
	vpc.set_anchors_preset(PRESET_FULL_RECT)
	vpc.stretch = true
	add_child(vpc)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(_viewport)

	_camera = Camera2D.new()
	_camera.position = Vector2(960, 540)
	_viewport.add_child(_camera)

	_content_root = Node2D.new()
	_content_root.name = "ContentRoot"
	_viewport.add_child(_content_root)

	_grid_node = Node2D.new()
	_grid_node.name = "GridOverlay"
	_grid_node.visible = false
	_grid_node.z_index = 100
	_viewport.add_child(_grid_node)

	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)

	_info_label = Label.new()
	_info_label.position = Vector2(10, 10)
	_info_label.add_theme_font_size_override("font_size", 16)
	_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	canvas_layer.add_child(_info_label)

#endregion


#region Stdin / Command System

func _start_stdin_thread() -> void:
	_stdin_mutex = Mutex.new()
	_stdin_thread = Thread.new()
	_stdin_thread.start(_stdin_reader)


func _stdin_reader() -> void:
	while not _should_quit:
		var line := OS.read_string_from_stdin(256).strip_edges()
		if line.is_empty():
			continue
		_stdin_mutex.lock()
		_stdin_buffer.append(line)
		_stdin_mutex.unlock()


func _drain_stdin() -> void:
	_stdin_mutex.lock()
	var lines := _stdin_buffer.duplicate()
	_stdin_buffer.clear()
	_stdin_mutex.unlock()
	for line in lines:
		_command_queue.append(line)


func _process_commands() -> void:
	if _command_queue.size() > 0:
		var cmd: String = _command_queue.pop_front()
		_handle_command(cmd)


func _handle_command(input: String) -> void:
	var parts := input.split(" ", false)
	if parts.is_empty():
		return

	var cmd := parts[0].to_lower()
	var args := parts.slice(1)
	var arg := args[0] if args.size() > 0 else ""

	match cmd:
		"help", "h", "?":
			_cmd_help()
		"screenshot", "ss":
			await _cmd_screenshot(arg)
		"zoom", "z":
			_cmd_zoom(arg)
		"zoom_in", "zi":
			_cmd_zoom_relative(1.5)
		"zoom_out", "zo":
			_cmd_zoom_relative(1.0 / 1.5)
		"pan":
			if args.size() >= 2:
				_cmd_pan(args[0].to_float(), args[1].to_float())
			else:
				_out("Usage: pan <x> <y>")
		"center":
			_cmd_center()
		"reload", "r":
			_cmd_reload()
		"load":
			_cmd_load(arg)
		"info", "i":
			_cmd_info()
		"tree":
			_cmd_tree()
		"bg":
			_cmd_bg(arg)
		"grid":
			_cmd_grid()
		"rig":
			_cmd_rig(arg)
		"anim":
			_cmd_anim(arg)
		"stop":
			_cmd_stop()
		"shader":
			if args.size() >= 3:
				_cmd_shader(args[0], args[1], args[2])
			else:
				_out("Usage: shader <node_path> <param> <value>")
		"sizes":
			_cmd_sizes()
		"quit":
			_should_quit = true
			get_tree().quit()
		_:
			_out("Unknown command: %s. Type 'help' for commands." % cmd)

#endregion


#region Commands

func _cmd_help() -> void:
	_out("╔══════════════════════════════════════════╗")
	_out("║       CONDOR — SVG Drawing Canvas        ║")
	_out("╠══════════════════════════════════════════╣")
	_out("║ screenshot/ss [path]  — Take screenshot  ║")
	_out("║ zoom/z <float>        — Set camera zoom  ║")
	_out("║ zoom_in/zi            — Zoom ×1.5        ║")
	_out("║ zoom_out/zo           — Zoom ÷1.5        ║")
	_out("║ pan <x> <y>           — Set camera pos   ║")
	_out("║ center                — Reset camera      ║")
	_out("║ reload/r              — Reload all files  ║")
	_out("║ load <name>           — Load canvas .tscn ║")
	_out("║ info/i                — Show state info   ║")
	_out("║ tree                  — Node tree dump    ║")
	_out("║ bg <hex>              — Background color  ║")
	_out("║ grid                  — Toggle grid       ║")
	_out("║ rig [class]           — Rig preview mode  ║")
	_out("║ anim <name>           — Play rig anim     ║")
	_out("║ stop                  — Stop rig anim     ║")
	_out("║ sizes                 — Print bone sizes  ║")
	_out("║ shader <n> <p> <v>    — Set shader param ║")
	_out("║ quit                  — Exit              ║")
	_out("╚══════════════════════════════════════════╝")


func _cmd_screenshot(arg: String) -> void:
	var path := arg if not arg.is_empty() else SCREENSHOT_PATH
	if DisplayServer.get_name() == "headless":
		_out("ERROR: Screenshots require GUI mode. Use tools/start_canvas.sh")
		return
	_busy = true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	_busy = false
	if err != OK:
		_out("ERROR: Failed to save screenshot (error %d)" % err)
		return
	_out("SCREENSHOT_SAVED:%s" % path)


func _cmd_zoom(arg: String) -> void:
	if arg.is_empty():
		_out("Current zoom: %.2f" % _camera.zoom.x)
		return
	var val := clampf(arg.to_float(), 0.1, 10.0)
	_camera.zoom = Vector2(val, val)
	_out("Zoom set to %.2f" % val)


func _cmd_zoom_relative(factor: float) -> void:
	var val := clampf(_camera.zoom.x * factor, 0.1, 10.0)
	_camera.zoom = Vector2(val, val)
	_out("Zoom: %.2f" % val)


func _cmd_pan(x: float, y: float) -> void:
	_camera.position = Vector2(x, y)
	_out("Camera at (%.0f, %.0f)" % [x, y])


func _cmd_center() -> void:
	_camera.position = Vector2(960, 540)
	_camera.zoom = Vector2(1.0, 1.0)
	_out("Camera centered, zoom 1.0")


func _cmd_reload() -> void:
	_busy = true
	if _mode == "rig":
		_reload_rig_svgs()
	else:
		_reload_canvas()
	_busy = false
	_out("Reloaded.")


func _cmd_load(name: String) -> void:
	if name.is_empty():
		_out("Usage: load <name>  (loads scenes/demos/canvas/<name>.tscn)")
		return
	_busy = true
	_exit_rig_mode()
	_load_canvas(name)
	_busy = false


func _cmd_info() -> void:
	_out("── Canvas Info ──")
	_out("  Mode: %s" % _mode)
	if _mode == "rig":
		_out("  Rig class: %s" % _rig_class_name)
		_out("  Rig SVG dir: %s" % (RIG_SVG_BASE + _rig_class_name + "/"))
		_out("  Bone SVGs loaded: %d / %d" % [_rig_svg_mtimes.size(), BONE_NAMES.size()])
	else:
		_out("  Canvas: %s" % _loaded_canvas_name)
		_out("  Path: %s" % _loaded_canvas_path)
		_out("  SVGs tracked: %d" % _svg_mtimes.size())
	_out("  Camera pos: (%.0f, %.0f)" % [_camera.position.x, _camera.position.y])
	_out("  Camera zoom: %.2f" % _camera.zoom.x)
	_out("  Grid: %s" % ("ON" if _grid_visible else "OFF"))
	_out("  Shaders tracked: %d" % _shader_mtimes.size())


func _cmd_tree() -> void:
	_out("── Node Tree ──")
	if _mode == "rig" and _rig:
		_print_tree_recursive(_rig, 0, 3)
	elif _canvas_node:
		_print_tree_recursive(_canvas_node, 0, 5)
	else:
		_out("  (no content loaded)")


func _cmd_bg(hex: String) -> void:
	if hex.is_empty():
		_out("Usage: bg <hex>  (e.g. bg #1a1a2e)")
		return
	if not hex.begins_with("#"):
		hex = "#" + hex
	_background.color = Color.from_string(hex, Color(0.12, 0.12, 0.14, 1.0))
	_out("Background: %s" % hex)


func _cmd_grid() -> void:
	_grid_visible = not _grid_visible
	_rebuild_grid()
	_grid_node.visible = _grid_visible
	_out("Grid: %s" % ("ON" if _grid_visible else "OFF"))


func _cmd_sizes() -> void:
	_out("── Bone Display Sizes (base px, ×%d for SVG) ──" % int(SVG_RENDER_SCALE))
	for bone_name in BONE_NAMES:
		var s: Vector2 = WarriorRig.BONE_DISPLAY_SIZES[bone_name]
		var svg_w := int(s.x * SVG_RENDER_SCALE)
		var svg_h := int(s.y * SVG_RENDER_SCALE)
		_out("  %s: %dx%d base → %dx%d SVG" % [bone_name, int(s.x), int(s.y), svg_w, svg_h])


func _cmd_shader(node_path: String, param: String, value_str: String) -> void:
	var target := _find_content_node(node_path)
	if not target:
		_out("Node not found: %s" % node_path)
		return
	if not target is CanvasItem:
		_out("Node is not a CanvasItem: %s" % node_path)
		return
	var ci := target as CanvasItem
	if not ci.material is ShaderMaterial:
		_out("Node has no ShaderMaterial: %s" % node_path)
		return
	var mat := ci.material as ShaderMaterial
	var val = _parse_shader_value(value_str)
	mat.set_shader_parameter(param, val)
	_out("Set %s.%s = %s" % [node_path, param, str(val)])

#endregion


#region Rig Mode

func _cmd_rig(class_name_arg: String) -> void:
	var cn := class_name_arg.to_lower() if not class_name_arg.is_empty() else "landsknecht"
	_busy = true
	_exit_rig_mode()
	_clear_canvas()
	_mode = "rig"
	_rig_class_name = cn

	var scene: PackedScene = load("res://scenes/warrior_rig.tscn")
	assert(scene, "Failed to load warrior_rig.tscn")
	_rig = scene.instantiate() as WarriorRig
	_rig.position = Vector2(960, 700)
	var class_id := _class_name_to_id(cn)
	_rig.setup(class_id, "canvas_preview")
	_content_root.add_child(_rig)

	_camera.position = Vector2(960, 600)
	_camera.zoom = Vector2(3.0, 3.0)

	_reload_rig_svgs()
	_busy = false
	_out("Rig mode: %s (edit SVGs in scenes/demos/canvas/svgs/rig/%s/)" % [cn, cn])
	_out("  Bone SVGs: %d / %d loaded" % [_rig_svg_mtimes.size(), BONE_NAMES.size()])
	_out("  Use 'anim idle', 'anim walk', etc. to animate")


func _cmd_anim(name: String) -> void:
	if not _rig:
		_out("No rig loaded. Use 'rig <class>' first.")
		return
	if name.is_empty():
		_out("Usage: anim <name>  (idle, walk, attack, defend, hurt, die, talk, gesture)")
		return
	var behavior := _anim_name_to_behavior(name)
	if behavior == -1:
		_out("Unknown animation: %s" % name)
		return
	_rig.play_behavior(behavior as AnimTypes.Behavior)
	_out("Playing: %s" % name)


func _cmd_stop() -> void:
	if not _rig:
		_out("No rig loaded.")
		return
	_rig.play_behavior(AnimTypes.Behavior.IDLE)
	_out("Stopped (idle)")


func _reload_rig_svgs() -> void:
	if not _rig:
		return
	var config := WarriorRigConfig.new()
	var svg_dir := RIG_SVG_BASE + _rig_class_name + "/"
	var abs_svg_dir := ProjectSettings.globalize_path(svg_dir)

	_rig_svg_mtimes.clear()

	for bone_name in BONE_NAMES:
		var file_stem: String = BONE_FILE_MAP[bone_name]
		var svg_path := svg_dir + file_stem + ".svg"
		var abs_path := ProjectSettings.globalize_path(svg_path)

		if not FileAccess.file_exists(abs_path):
			continue

		var tex := _load_svg_from_disk(abs_path, SVG_RENDER_SCALE)
		if not tex:
			continue

		_rig_svg_mtimes[abs_path] = FileAccess.get_modified_time(abs_path)
		_set_config_texture(config, bone_name, tex)

	_rig.apply_config(config)


func _set_config_texture(config: WarriorRigConfig, bone_name: String, tex: ImageTexture) -> void:
	match bone_name:
		"Head": config.head_texture = tex
		"Torso": config.torso_texture = tex
		"Hips": config.hips_texture = tex
		"LeftArm": config.left_arm_texture = tex
		"LeftForearm": config.left_forearm_texture = tex
		"LeftHand": config.left_hand_texture = tex
		"RightArm": config.right_arm_texture = tex
		"RightForearm": config.right_forearm_texture = tex
		"RightHand": config.right_hand_texture = tex
		"LeftLeg": config.left_leg_texture = tex
		"LeftShin": config.left_shin_texture = tex
		"LeftFoot": config.left_foot_texture = tex
		"RightLeg": config.right_leg_texture = tex
		"RightShin": config.right_shin_texture = tex
		"RightFoot": config.right_foot_texture = tex


func _exit_rig_mode() -> void:
	if _rig and is_instance_valid(_rig):
		_rig.queue_free()
		_rig = null
	_rig_class_name = ""
	_rig_svg_mtimes.clear()
	_mode = "canvas"

#endregion


#region Canvas Loading

func _load_canvas(canvas_name: String) -> void:
	_clear_canvas()
	_loaded_canvas_name = canvas_name
	_loaded_canvas_path = CANVAS_BASE + canvas_name + ".tscn"
	_svg_mtimes.clear()
	_svg_textures.clear()
	_svg_sprites.clear()
	_shader_mtimes.clear()
	_shader_materials.clear()

	var abs_path := ProjectSettings.globalize_path(_loaded_canvas_path)
	if not FileAccess.file_exists(abs_path):
		_out("Canvas not found: %s" % _loaded_canvas_path)
		return

	_canvas_mtime = FileAccess.get_modified_time(abs_path)

	var scene := load(_loaded_canvas_path) as PackedScene
	if not scene:
		_out("Failed to load: %s" % _loaded_canvas_path)
		return

	_canvas_node = scene.instantiate()
	_content_root.add_child(_canvas_node)

	_scan_and_apply_svgs(_canvas_node)
	_scan_shaders(_canvas_node)
	_out("Loaded canvas: %s (%d SVGs, %d shaders)" % [
		canvas_name, _svg_mtimes.size(), _shader_mtimes.size()])


func _reload_canvas() -> void:
	if _loaded_canvas_name.is_empty():
		return
	ResourceLoader.load(_loaded_canvas_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_load_canvas(_loaded_canvas_name)


func _clear_canvas() -> void:
	if _canvas_node and is_instance_valid(_canvas_node):
		_canvas_node.queue_free()
		_canvas_node = null
	_svg_mtimes.clear()
	_svg_textures.clear()
	_svg_sprites.clear()
	_shader_mtimes.clear()
	_shader_materials.clear()


func _scan_and_apply_svgs(root: Node) -> void:
	if root is Sprite2D and root.has_meta("svg_path"):
		var svg_rel: String = root.get_meta("svg_path")
		var svg_path := SVG_BASE + svg_rel
		var abs_path := ProjectSettings.globalize_path(svg_path)
		if FileAccess.file_exists(abs_path):
			var scale_meta: float = root.get_meta("svg_scale", SVG_RENDER_SCALE)
			var tex := _load_svg_from_disk(abs_path, scale_meta)
			if tex:
				(root as Sprite2D).texture = tex
				_svg_mtimes[abs_path] = FileAccess.get_modified_time(abs_path)
				_svg_textures[abs_path] = tex
				_svg_sprites[abs_path] = root
	for child in root.get_children():
		_scan_and_apply_svgs(child)


func _scan_shaders(root: Node) -> void:
	if root is CanvasItem:
		var ci := root as CanvasItem
		if ci.material is ShaderMaterial:
			var mat := ci.material as ShaderMaterial
			if mat.shader:
				var shader_path := mat.shader.resource_path
				if not shader_path.is_empty():
					var abs_path := ProjectSettings.globalize_path(shader_path)
					if FileAccess.file_exists(abs_path):
						_shader_mtimes[abs_path] = FileAccess.get_modified_time(abs_path)
						_shader_materials[abs_path] = mat
	for child in root.get_children():
		_scan_shaders(child)

#endregion


#region SVG Loading

func _load_svg_from_disk(abs_path: String, svg_scale: float) -> ImageTexture:
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if not file:
		_out("ERROR: Cannot open SVG: %s" % abs_path)
		return null
	var svg_text := file.get_as_text()
	file.close()

	var image := Image.new()
	var err := image.load_svg_from_string(svg_text, svg_scale)
	if err != OK:
		_out("ERROR: Failed to parse SVG (error %d): %s" % [err, abs_path])
		return null

	return ImageTexture.create_from_image(image)

#endregion


#region File Watching

func _check_file_changes() -> void:
	if _mode == "rig":
		_check_rig_svg_changes()
	else:
		_check_canvas_changes()
		_check_svg_changes()
	_check_shader_changes()


func _check_canvas_changes() -> void:
	if _loaded_canvas_path.is_empty():
		return
	var abs_path := ProjectSettings.globalize_path(_loaded_canvas_path)
	if not FileAccess.file_exists(abs_path):
		return
	var current_mtime := FileAccess.get_modified_time(abs_path)
	if current_mtime != _canvas_mtime:
		_schedule_file_reload()


func _check_svg_changes() -> void:
	var changed := false
	for abs_path in _svg_mtimes.keys():
		if not FileAccess.file_exists(abs_path):
			continue
		var current_mtime := FileAccess.get_modified_time(abs_path)
		if current_mtime != _svg_mtimes[abs_path]:
			changed = true
			break
	if changed:
		_schedule_file_reload()


func _check_rig_svg_changes() -> void:
	for abs_path in _rig_svg_mtimes.keys():
		if not FileAccess.file_exists(abs_path):
			continue
		var current_mtime := FileAccess.get_modified_time(abs_path)
		if current_mtime != _rig_svg_mtimes[abs_path]:
			_schedule_file_reload()
			return


func _check_shader_changes() -> void:
	for abs_path in _shader_mtimes.keys():
		if not FileAccess.file_exists(abs_path):
			continue
		var current_mtime := FileAccess.get_modified_time(abs_path)
		if current_mtime != _shader_mtimes[abs_path]:
			_schedule_file_reload()
			return


func _schedule_file_reload() -> void:
	_pending_file_reload = true
	_debounce_timer = DEBOUNCE_INTERVAL


func _do_file_reload() -> void:
	_busy = true
	if _mode == "rig":
		_out("Rig SVGs changed, reloading...")
		_reload_rig_svgs()
	else:
		_out("Files changed, reloading...")
		_reload_canvas()
	_reload_changed_shaders()
	_busy = false


func _reload_changed_shaders() -> void:
	for abs_path in _shader_mtimes.keys():
		if not FileAccess.file_exists(abs_path):
			continue
		var current_mtime := FileAccess.get_modified_time(abs_path)
		if current_mtime != _shader_mtimes[abs_path]:
			_shader_mtimes[abs_path] = current_mtime
			var file := FileAccess.open(abs_path, FileAccess.READ)
			if file:
				var code := file.get_as_text()
				file.close()
				if _shader_materials.has(abs_path):
					var mat: ShaderMaterial = _shader_materials[abs_path]
					mat.shader.code = code
					_out("Shader reloaded: %s" % abs_path.get_file())

#endregion


#region Grid

func _rebuild_grid() -> void:
	for child in _grid_node.get_children():
		child.queue_free()

	if not _grid_visible:
		return

	var grid_size := 2000.0
	var spacing := 100.0
	var grid_color := Color(0.3, 0.3, 0.35, 0.3)
	var axis_color := Color(0.5, 0.3, 0.3, 0.5)
	var y_axis_color := Color(0.3, 0.5, 0.3, 0.5)

	var x_start := -grid_size + 960
	var x_end := grid_size + 960
	var y_start := -grid_size + 540
	var y_end := grid_size + 540

	var x := x_start
	while x <= x_end:
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(x, y_start), Vector2(x, y_end)])
		line.width = 1.0 if not is_equal_approx(x, 960.0) else 2.0
		line.default_color = grid_color if not is_equal_approx(x, 960.0) else y_axis_color
		_grid_node.add_child(line)
		x += spacing

	var y := y_start
	while y <= y_end:
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(x_start, y), Vector2(x_end, y)])
		line.width = 1.0 if not is_equal_approx(y, 540.0) else 2.0
		line.default_color = grid_color if not is_equal_approx(y, 540.0) else axis_color
		_grid_node.add_child(line)
		y += spacing

#endregion


#region Helpers

func _update_info_label() -> void:
	_info_label.text = "%s | %s | zoom:%.2f | pos:(%.0f,%.0f)" % [
		_mode.to_upper(),
		_rig_class_name if _mode == "rig" else _loaded_canvas_name,
		_camera.zoom.x,
		_camera.position.x,
		_camera.position.y,
	]


func _print_tree_recursive(node: Node, depth: int, max_depth: int) -> void:
	if depth > max_depth:
		return
	var indent := "  ".repeat(depth)
	var type_name := node.get_class()
	var extra := ""
	if node is Sprite2D and node.has_meta("svg_path"):
		extra = " [svg:%s]" % node.get_meta("svg_path")
	if node is CanvasItem and (node as CanvasItem).material is ShaderMaterial:
		extra += " [shader]"
	_out("%s%s (%s)%s" % [indent, node.name, type_name, extra])
	for child in node.get_children():
		_print_tree_recursive(child, depth + 1, max_depth)


func _find_content_node(path: String) -> Node:
	if _mode == "rig" and _rig:
		return _rig.get_node_or_null(NodePath(path))
	elif _canvas_node:
		return _canvas_node.get_node_or_null(NodePath(path))
	return null


func _class_name_to_id(cn: String) -> EntityClasses.Types:
	match cn:
		"landsknecht": return EntityClasses.Types.Landsknecht
		"healer": return EntityClasses.Types.Healer
		"crossbowman": return EntityClasses.Types.Crossbowman
		"arquebusier": return EntityClasses.Types.Arquebusier
		"pikeman": return EntityClasses.Types.Pikeman
		"feldprediger": return EntityClasses.Types.Feldprediger
		"gelehrter": return EntityClasses.Types.Gelehrter
		_: return EntityClasses.Types.Landsknecht


func _anim_name_to_behavior(name: String) -> int:
	match name.to_lower():
		"idle": return AnimTypes.Behavior.IDLE
		"walk", "walking": return AnimTypes.Behavior.WALKING
		"attack", "attacking": return AnimTypes.Behavior.ATTACKING
		"defend", "defending": return AnimTypes.Behavior.DEFENDING
		"hurt": return AnimTypes.Behavior.HURT
		"die", "dying": return AnimTypes.Behavior.DYING
		"talk", "talking": return AnimTypes.Behavior.TALKING
		"gesture", "gesturing": return AnimTypes.Behavior.GESTURING
		_: return -1


func _parse_shader_value(v: String):
	if v.begins_with("#"):
		return Color.from_string(v, Color.WHITE)
	if v.contains(","):
		var parts := v.split(",")
		if parts.size() == 2:
			return Vector2(parts[0].to_float(), parts[1].to_float())
		if parts.size() == 3:
			return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
		if parts.size() == 4:
			return Color(parts[0].to_float(), parts[1].to_float(), parts[2].to_float(), parts[3].to_float())
	if v == "true": return true
	if v == "false": return false
	return v.to_float()


func _out(text: String) -> void:
	print(text)

#endregion
