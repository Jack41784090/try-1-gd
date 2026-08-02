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
const RIG_SVG_BASE := "res://assets/rig_textures/"
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
	# --- _build_scene_tree ---
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

	# --- _start_stdin_thread ---
	_stdin_mutex = Mutex.new()
	_stdin_thread = Thread.new()
	_stdin_thread.start(_stdin_reader)

	_load_canvas(DEFAULT_CANVAS)
	_initialized = true
	_out("Canvas ready. Type 'help' for commands.")


func _process(delta: float) -> void:
	if not _initialized:
		return

	# --- _drain_stdin ---
	_stdin_mutex.lock()
	var lines := _stdin_buffer.duplicate()
	_stdin_buffer.clear()
	_stdin_mutex.unlock()
	for line in lines:
		_command_queue.append(line)

	# --- _process_commands ---
	if not _busy:
		if _command_queue.size() > 0:
			var cmd: String = _command_queue.pop_front()
			_handle_command(cmd)

	if _debounce_timer > 0.0:
		_debounce_timer -= delta
		if _debounce_timer <= 0.0 and _pending_file_reload and not _busy:
			_debounce_timer = 0.0
			_pending_file_reload = false
			# --- _do_file_reload ---
			_busy = true
			if _mode == "rig":
				_out("Rig SVGs changed, reloading...")
				_reload_rig_svgs()
			else:
				_out("Files changed, reloading...")
				_reload_canvas()
			# --- _reload_changed_shaders ---
			for shader_path in _shader_mtimes.keys():
				if not FileAccess.file_exists(shader_path):
					continue
				var shader_mtime := FileAccess.get_modified_time(shader_path)
				if shader_mtime != _shader_mtimes[shader_path]:
					_shader_mtimes[shader_path] = shader_mtime
					var sf := FileAccess.open(shader_path, FileAccess.READ)
					if sf:
						var code := sf.get_as_text()
						sf.close()
						if _shader_materials.has(shader_path):
							var smat: ShaderMaterial = _shader_materials[shader_path]
							smat.shader.code = code
							_out("Shader reloaded: %s" % shader_path.get_file())
			_busy = false

	_watch_timer += delta
	if _watch_timer >= WATCH_INTERVAL:
		_watch_timer = 0.0
		if not _busy:
			# --- _check_file_changes ---
			if _mode == "rig":
				# --- _check_rig_svg_changes ---
				for rig_path in _rig_svg_mtimes.keys():
					if not FileAccess.file_exists(rig_path):
						continue
					var rig_mtime := FileAccess.get_modified_time(rig_path)
					if rig_mtime != _rig_svg_mtimes[rig_path]:
						_schedule_file_reload()
						break
			else:
				# --- _check_canvas_changes ---
				if not _loaded_canvas_path.is_empty():
					var canvas_abs := ProjectSettings.globalize_path(_loaded_canvas_path)
					if FileAccess.file_exists(canvas_abs):
						var canvas_mtime := FileAccess.get_modified_time(canvas_abs)
						if canvas_mtime != _canvas_mtime:
							_schedule_file_reload()
				# --- _check_svg_changes ---
				var svg_changed := false
				for svg_path in _svg_mtimes.keys():
					if not FileAccess.file_exists(svg_path):
						continue
					var svg_mtime := FileAccess.get_modified_time(svg_path)
					if svg_mtime != _svg_mtimes[svg_path]:
						svg_changed = true
						break
				if svg_changed:
					_schedule_file_reload()
			# --- _check_shader_changes ---
			for watch_path in _shader_mtimes.keys():
				if not FileAccess.file_exists(watch_path):
					continue
				var watch_mtime := FileAccess.get_modified_time(watch_path)
				if watch_mtime != _shader_mtimes[watch_path]:
					_schedule_file_reload()
					break

	# --- _update_info_label ---
	_info_label.text = "%s | %s | zoom:%.2f | pos:(%.0f,%.0f)" % [
		_mode.to_upper(),
		_rig_class_name if _mode == "rig" else _loaded_canvas_name,
		_camera.zoom.x,
		_camera.position.x,
		_camera.position.y,
	]


func _exit_tree() -> void:
	_should_quit = true
	if _stdin_thread and _stdin_thread.is_started():
		_stdin_thread.wait_to_finish()


#region Stdin / Command System

func _stdin_reader() -> void:
	while not _should_quit:
		var line := OS.read_string_from_stdin(256).strip_edges()
		if line.is_empty():
			continue
		_stdin_mutex.lock()
		_stdin_buffer.append(line)
		_stdin_mutex.unlock()


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
			# --- _cmd_zoom ---
			if arg.is_empty():
				_out("Current zoom: %.2f" % _camera.zoom.x)
			else:
				var val := clampf(arg.to_float(), 0.1, 10.0)
				_camera.zoom = Vector2(val, val)
				_out("Zoom set to %.2f" % val)
		"zoom_in", "zi":
			_cmd_zoom_relative(1.5)
		"zoom_out", "zo":
			_cmd_zoom_relative(1.0 / 1.5)
		"pan":
			if args.size() >= 2:
				# --- _cmd_pan ---
				var px := args[0].to_float()
				var py := args[1].to_float()
				_camera.position = Vector2(px, py)
				_out("Camera at (%.0f, %.0f)" % [px, py])
			else:
				_out("Usage: pan <x> <y>")
		"center":
			# --- _cmd_center ---
			_camera.position = Vector2(960, 540)
			_camera.zoom = Vector2(1.0, 1.0)
			_out("Camera centered, zoom 1.0")
		"reload", "r":
			# --- _cmd_reload ---
			_busy = true
			if _mode == "rig":
				_reload_rig_svgs()
			else:
				_reload_canvas()
			_busy = false
			_out("Reloaded.")
		"load":
			# --- _cmd_load ---
			if arg.is_empty():
				_out("Usage: load <name>  (loads scenes/demos/canvas/<name>.tscn)")
			else:
				_busy = true
				_exit_rig_mode()
				_load_canvas(arg)
				_busy = false
		"info", "i":
			# --- _cmd_info ---
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
		"tree":
			# --- _cmd_tree ---
			_out("── Node Tree ──")
			if _mode == "rig" and _rig:
				_print_tree_recursive(_rig, 0, 3)
			elif _canvas_node:
				_print_tree_recursive(_canvas_node, 0, 5)
			else:
				_out("  (no content loaded)")
		"bg":
			# --- _cmd_bg ---
			if arg.is_empty():
				_out("Usage: bg <hex>  (e.g. bg #1a1a2e)")
			else:
				var hex := arg
				if not hex.begins_with("#"):
					hex = "#" + hex
				_background.color = Color.from_string(hex, Color(0.12, 0.12, 0.14, 1.0))
				_out("Background: %s" % hex)
		"grid":
			# --- _cmd_grid ---
			_grid_visible = not _grid_visible
			# --- _rebuild_grid ---
			for child in _grid_node.get_children():
				child.queue_free()
			if _grid_visible:
				var grid_size := 2000.0
				var spacing := 100.0
				var grid_color := Color(0.3, 0.3, 0.35, 0.3)
				var axis_color := Color(0.5, 0.3, 0.3, 0.5)
				var y_axis_color := Color(0.3, 0.5, 0.3, 0.5)
				var x_start := -grid_size + 960
				var x_end := grid_size + 960
				var y_start := -grid_size + 540
				var y_end := grid_size + 540
				var gx := x_start
				while gx <= x_end:
					var vline := Line2D.new()
					vline.points = PackedVector2Array([Vector2(gx, y_start), Vector2(gx, y_end)])
					vline.width = 1.0 if not is_equal_approx(gx, 960.0) else 2.0
					vline.default_color = grid_color if not is_equal_approx(gx, 960.0) else y_axis_color
					_grid_node.add_child(vline)
					gx += spacing
				var gy := y_start
				while gy <= y_end:
					var hline := Line2D.new()
					hline.points = PackedVector2Array([Vector2(x_start, gy), Vector2(x_end, gy)])
					hline.width = 1.0 if not is_equal_approx(gy, 540.0) else 2.0
					hline.default_color = grid_color if not is_equal_approx(gy, 540.0) else axis_color
					_grid_node.add_child(hline)
					gy += spacing
			_grid_node.visible = _grid_visible
			_out("Grid: %s" % ("ON" if _grid_visible else "OFF"))
		"rig":
			# --- _cmd_rig ---
			var cn := arg.to_lower() if not arg.is_empty() else "landsknecht"
			_busy = true
			_exit_rig_mode()
			_clear_canvas()
			_mode = "rig"
			_rig_class_name = cn

			var scene: PackedScene = load("res://scenes/rig/warrior_rig.tscn")
			assert(scene, "Failed to load warrior_rig.tscn")
			_rig = scene.instantiate() as WarriorRig
			_rig.position = Vector2(960, 700)
			# --- _class_name_to_id ---
			var class_id: EntityClasses.Types
			match cn:
				"landsknecht": class_id = EntityClasses.Types.Landsknecht
				"healer": class_id = EntityClasses.Types.Healer
				"crossbowman": class_id = EntityClasses.Types.Crossbowman
				"arquebusier": class_id = EntityClasses.Types.Arquebusier
				"pikeman": class_id = EntityClasses.Types.Pikeman
				"feldprediger": class_id = EntityClasses.Types.Feldprediger
				"gelehrter": class_id = EntityClasses.Types.Gelehrter
				_: class_id = EntityClasses.Types.Landsknecht
			_rig.setup(class_id, "canvas_preview")
			_content_root.add_child(_rig)

			_camera.position = Vector2(960, 600)
			_camera.zoom = Vector2(3.0, 3.0)

			_reload_rig_svgs()
			_busy = false
			_out("Rig mode: %s (edit SVGs in assets/rig_textures/%s/)" % [cn, cn])
			_out("  Bone SVGs: %d / %d loaded" % [_rig_svg_mtimes.size(), BONE_NAMES.size()])
			_out("  Use 'anim idle', 'anim walk', etc. to animate")
		"anim":
			# --- _cmd_anim ---
			if not _rig:
				_out("No rig loaded. Use 'rig <class>' first.")
			elif arg.is_empty():
				_out("Usage: anim <name>  (idle, walk, attack, defend, hurt, die, talk, gesture)")
			else:
				# --- _anim_name_to_behavior ---
				var behavior: int
				match arg.to_lower():
					"idle": behavior = AnimTypes.Behavior.IDLE
					"walk", "walking": behavior = AnimTypes.Behavior.WALKING
					"attack", "attacking": behavior = AnimTypes.Behavior.ATTACKING
					"defend", "defending": behavior = AnimTypes.Behavior.DEFENDING
					"hurt": behavior = AnimTypes.Behavior.HURT
					"die", "dying": behavior = AnimTypes.Behavior.DYING
					"talk", "talking": behavior = AnimTypes.Behavior.TALKING
					"gesture", "gesturing": behavior = AnimTypes.Behavior.GESTURING
					_: behavior = -1
				if behavior == -1:
					_out("Unknown animation: %s" % arg)
				else:
					_rig.play_behavior(behavior as AnimTypes.Behavior)
					_out("Playing: %s" % arg)
		"stop":
			# --- _cmd_stop ---
			if not _rig:
				_out("No rig loaded.")
			else:
				_rig.play_behavior(AnimTypes.Behavior.IDLE)
				_out("Stopped (idle)")
		"shader":
			if args.size() >= 3:
				# --- _cmd_shader ---
				var target: Node = null
				# --- _find_content_node ---
				if _mode == "rig" and _rig:
					target = _rig.get_node_or_null(NodePath(args[0]))
				elif _canvas_node:
					target = _canvas_node.get_node_or_null(NodePath(args[0]))
				if not target:
					_out("Node not found: %s" % args[0])
				elif not target is CanvasItem:
					_out("Node is not a CanvasItem: %s" % args[0])
				else:
					var ci := target as CanvasItem
					if not ci.material is ShaderMaterial:
						_out("Node has no ShaderMaterial: %s" % args[0])
					else:
						var mat := ci.material as ShaderMaterial
						# --- _parse_shader_value ---
						var val
						var sv := args[2]
						if sv.begins_with("#"):
							val = Color.from_string(sv, Color.WHITE)
						elif sv.contains(","):
							var sv_parts := sv.split(",")
							if sv_parts.size() == 2:
								val = Vector2(sv_parts[0].to_float(), sv_parts[1].to_float())
							elif sv_parts.size() == 3:
								val = Vector3(sv_parts[0].to_float(), sv_parts[1].to_float(), sv_parts[2].to_float())
							elif sv_parts.size() == 4:
								val = Color(sv_parts[0].to_float(), sv_parts[1].to_float(), sv_parts[2].to_float(), sv_parts[3].to_float())
						elif sv == "true":
							val = true
						elif sv == "false":
							val = false
						else:
							val = sv.to_float()
						mat.set_shader_parameter(args[1], val)
						_out("Set %s.%s = %s" % [args[0], args[1], str(val)])
			else:
				_out("Usage: shader <node_path> <param> <value>")
		"sizes":
			# --- _cmd_sizes ---
			_out("── Bone Display Sizes (base px, ×%d for SVG) ──" % int(SVG_RENDER_SCALE))
			for bone_name in BONE_NAMES:
				var s: Vector2 = WarriorRig.BONE_DISPLAY_SIZES[bone_name]
				var svg_w := int(s.x * SVG_RENDER_SCALE)
				var svg_h := int(s.y * SVG_RENDER_SCALE)
				_out("  %s: %dx%d base → %dx%d SVG" % [bone_name, int(s.x), int(s.y), svg_w, svg_h])
		"quit":
			_should_quit = true
			get_tree().quit()
		_:
			_out("Unknown command: %s. Type 'help' for commands." % cmd)

#endregion


#region Commands (multi-use or async)

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


func _cmd_zoom_relative(factor: float) -> void:
	var val := clampf(_camera.zoom.x * factor, 0.1, 10.0)
	_camera.zoom = Vector2(val, val)
	_out("Zoom: %.2f" % val)

#endregion


#region Rig Mode

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
		# --- _set_config_texture ---
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

	_rig.apply_config(config)


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

func _schedule_file_reload() -> void:
	_pending_file_reload = true
	_debounce_timer = DEBOUNCE_INTERVAL

#endregion


#region Helpers

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


func _out(text: String) -> void:
	print(text)

#endregion
