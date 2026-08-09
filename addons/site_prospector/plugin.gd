@tool
extends EditorPlugin

## Site Prospector: choose the ground a level sits on, and survey it before
## building anything.
##
## The dock is deliberately small. It opens the map, optionally ranks
## candidates, and hands the chosen site to whatever the host project uses -
## which is one `RegionWindow` node, and nothing else about the host.

const PROSPECT_SCENE := "res://addons/site_prospector/region_prospect.gd"
const DEMO_SCENE := "res://demo/prospect_demo.tscn"
const CHOSEN_SITE_PATH := "res://chosen_site.tres"
const RENDER_REGION_MAP := \
	"res://addons/site_prospector/tools/render_region_map.gd"

## Required. Benching, fill depth and earthwork all come from it.
const AUTOMATE_GODOT := "res://addons/automate_godot/terrain/bench_rules.gd"

var _dock: VBoxContainer
var _status: Label
var _kept: Label
var _watchdog: Timer
var _running_pid: int = -1
var _running_seconds := 0.0


func _enter_tree() -> void:
	_build_dock()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_check_dependencies()


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


## Say plainly what is missing, rather than failing somewhere deeper.
func _check_dependencies() -> void:
	if ResourceLoader.exists(AUTOMATE_GODOT):
		return
	var message := "Site Prospector needs automate-godot: install " \
		+ "addons/automate_godot/ from " \
		+ "https://github.com/VerdantAI/automate-godot. Benching, fill " \
		+ "depth and earthwork are reported from it."
	push_warning(message)
	if _status != null:
		_status.text = message


func _build_dock() -> void:
	_dock = VBoxContainer.new()
	_dock.name = "Site Prospector"

	var heading := Label.new()
	heading.text = "Site Prospector"
	heading.add_theme_font_size_override("font_size", 16)
	_dock.add_child(heading)

	var blurb := Label.new()
	blurb.text = "Ground is authored once over kilometres. A level is a " \
		+ "rectangle cut from it. Choose the rectangle."
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	_dock.add_child(blurb)

	var open := Button.new()
	open.text = "Open the map"
	open.tooltip_text = "Opens the prospect scene in 2D. Drag the Site " \
		+ "rectangle; the ground under it is surveyed as you move."
	open.pressed.connect(_on_open_map)
	_dock.add_child(open)

	_kept = Label.new()
	_kept.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock.add_child(_kept)

	var apply := Button.new()
	apply.text = "Apply kept site to RegionWindow"
	apply.tooltip_text = "Writes the kept site onto a RegionWindow in the " \
		+ "open scene."
	apply.pressed.connect(_on_apply)
	_dock.add_child(apply)

	_dock.add_child(HSeparator.new())

	var optional := Label.new()
	optional.text = "Optional: sweep the region and rank candidates by " \
		+ "contours crossed. Takes about a minute."
	optional.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	optional.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
	_dock.add_child(optional)

	var sweep := Button.new()
	sweep.text = "Rank candidate sites"
	sweep.pressed.connect(_on_sweep)
	_dock.add_child(sweep)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	_dock.add_child(_status)

	_refresh_kept()


func _on_open_map() -> void:
	if not FileAccess.file_exists(DEMO_SCENE):
		_status.text = "No prospect scene at %s. Make one with a " % DEMO_SCENE \
			+ "RegionProspect root and a Site child."
		return
	get_editor_interface().open_scene_from_path(DEMO_SCENE)
	# A Node2D root opened while the editor is on 3D shows an empty viewport,
	# which reads as the button having done nothing.
	get_editor_interface().set_main_screen_editor("2D")
	_status.text = "Press F to frame the map, then drag the Site rectangle."


func _refresh_kept() -> void:
	if _kept == null:
		return
	if not ResourceLoader.exists(CHOSEN_SITE_PATH):
		_kept.text = "No site kept yet."
		return
	var chosen: Resource = load(CHOSEN_SITE_PATH)
	_kept.text = "No site kept yet." if chosen == null \
		else "Kept: %s" % chosen.call("describe")


func _on_apply() -> void:
	_refresh_kept()
	if not ResourceLoader.exists(CHOSEN_SITE_PATH):
		_status.text = "Nothing kept. Drag the site, then tick 'keep this " \
			+ "site' in the Inspector."
		return
	var chosen: Resource = load(CHOSEN_SITE_PATH)
	var root := get_editor_interface().get_edited_scene_root()
	var window: Node = null if root == null \
		else root.find_child("RegionWindow", true, false)
	if window == null:
		_status.text = "No RegionWindow in the open scene."
		return
	window.set("window_origin", chosen.get("origin"))
	window.set("window_angle_degrees", chosen.get("angle_degrees"))
	_status.text = "Applied %s Save the scene." % chosen.call("describe")


func _on_sweep() -> void:
	if _running_pid > 0 and OS.is_process_running(_running_pid):
		_status.text = "Already sweeping."
		return
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", RENDER_REGION_MAP,
	]))
	if pid <= 0:
		_status.text = "Could not start the sweep."
		return
	_running_pid = pid
	_running_seconds = 0.0
	if _watchdog == null:
		_watchdog = Timer.new()
		_watchdog.wait_time = 0.5
		_watchdog.timeout.connect(_on_watchdog)
		_dock.add_child(_watchdog)
	_watchdog.start()


## A job that says "check back later" is not finished work.
func _on_watchdog() -> void:
	if _running_pid > 0 and OS.is_process_running(_running_pid):
		_running_seconds += 0.5
		_status.text = "Sweeping... %ds" % int(_running_seconds)
		return
	_watchdog.stop()
	var code := OS.get_process_exit_code(_running_pid)
	_running_pid = -1
	_status.text = "Sweep failed (exit %d)." % code if code > 0 \
		else "Sweep finished in %ds. See the ranking beside the map." \
			% int(_running_seconds)
