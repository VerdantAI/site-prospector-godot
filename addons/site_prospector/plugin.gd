@tool
extends EditorPlugin

## Site Prospector: choose the ground a level sits on, and survey it before
## building anything.
##
## The dock is deliberately small. It opens the map, optionally ranks
## candidates, and hands the chosen site to whatever the host project uses -
## which is one `RegionWindow` node, and nothing else about the host.

## Where this project keeps its prospect scene and its kept site.
##
## **Settings, not constants.** The addon shipped pointing at its own demo, so
## every host either kept its map at `res://demo/` or found the button broken.
## A project declares where its things live; an addon does not get to decide.
const SETTING_SCENE := "site_prospector/prospect_scene"
const SETTING_CHOSEN := "site_prospector/chosen_site"
const DEFAULT_SCENE := "res://demo/prospect_demo.tscn"
const DEFAULT_CHOSEN := "res://chosen_site.tres"

## Per-developer, in `EditorSettings`: a machine's setup, not a project's.
const ASSISTANT_ENABLED := "site_prospector/assistant/enabled"
const ASSISTANT_HOST := "site_prospector/assistant/host"
const ASSISTANT_MODEL := "site_prospector/assistant/model"
const RENDER_REGION_MAP := \
	"res://addons/site_prospector/tools/render_region_map.gd"

## Required. Benching, fill depth and earthwork all come from it.
const AUTOMATE_GODOT := "res://addons/automate_godot/terrain/bench_rules.gd"

const CONFIG := preload("res://addons/site_prospector/assistant_config.gd")

var _dock: VBoxContainer
var _status: Label
var _kept: Label
var _watchdog: Timer
var _running_pid: int = -1
var _running_seconds := 0.0
var _assistant_enabled: CheckBox
var _assistant_host: LineEdit
var _assistant_model: LineEdit
var _assistant_key: LineEdit
var _assistant_status: Label


func _enter_tree() -> void:
	_declare_settings()
	_build_dock()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_check_dependencies()


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


## Declare where things live, in the scope each of them belongs to.
##
## **Three scopes, and the difference matters.** `ProjectSettings` is committed
## in `project.godot`, so it holds what every teammate must agree on - which
## scene is this project's map, where a kept site is written. `EditorSettings`
## lives in the developer's own config directory and is never committed, so it
## holds what is true of a *machine* rather than of a project: where a model is
## running and which one. Putting a host URL in project settings would commit
## one developer's localhost to everybody else's checkout.
##
## `set_as_basic` matters more than it looks: without it a setting only appears
## once "Advanced Settings" is toggled on, which is where settings go to not be
## found.
func _declare_settings() -> void:
	for setting in [[SETTING_SCENE, DEFAULT_SCENE], [SETTING_CHOSEN,
			DEFAULT_CHOSEN]]:
		if not ProjectSettings.has_setting(setting[0]):
			ProjectSettings.set_setting(setting[0], setting[1])
		ProjectSettings.set_initial_value(setting[0], setting[1])
		ProjectSettings.set_as_basic(setting[0], true)
		ProjectSettings.add_property_info({
			"name": setting[0], "type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
		})
	_declare_editor_settings()


## Per-developer setup, in the editor's own settings rather than the project's.
##
## A host URL and a model name describe the machine a designer is sitting at.
## They are the same across every project that person opens, and they are wrong
## for everyone else on the team, so `EditorSettings` is their home. A future
## hosted endpoint's credential belongs in neither: an environment variable,
## with only its *name* recorded here, because both settings files sit in
## plain text on disk and one of them is in git.
func _declare_editor_settings() -> void:
	var editor := get_editor_interface().get_editor_settings()
	if editor == null:
		return
	var defaults := {
		ASSISTANT_ENABLED: false,
		ASSISTANT_HOST: "http://localhost:11434",
		ASSISTANT_MODEL: "qwen3:8b",
	}
	for name in defaults:
		if not editor.has_setting(name):
			editor.set_setting(name, defaults[name])
		editor.set_initial_value(name, defaults[name], false)
		editor.add_property_info({
			"name": name,
			"type": typeof(defaults[name]),
		})


func prospect_scene() -> String:
	return str(ProjectSettings.get_setting(SETTING_SCENE, DEFAULT_SCENE))


func chosen_site_path() -> String:
	return str(ProjectSettings.get_setting(SETTING_CHOSEN, DEFAULT_CHOSEN))


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

	_dock.add_child(HSeparator.new())
	_build_assistant_controls()

	_refresh_kept()


## The assistant's setup, editable here.
##
## **Files are the mechanism; this is the interface.** Configuration resolves
## from the environment, then a gitignored local file, then editor settings -
## which is what lets a headless tool and a CI run see it - but nobody should
## have to open a `.cfg` to point the addon at a model. Each field says where
## its current value came from, because a setting edited in the wrong scope
## looks exactly like a setting that did not save.
func _build_assistant_controls() -> void:
	var heading := Label.new()
	heading.text = "Assistant (optional)"
	heading.add_theme_font_size_override("font_size", 14)
	_dock.add_child(heading)

	var blurb := Label.new()
	blurb.text = "A locally hosted model proposes landform parameters and " \
		+ "reads a survey back. Everything here works without one."
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
	_dock.add_child(blurb)

	_assistant_enabled = CheckBox.new()
	_assistant_enabled.text = "Use a model"
	_dock.add_child(_assistant_enabled)

	_assistant_host = _labelled_field("Host", CONFIG.HOST)
	_assistant_model = _labelled_field("Model", CONFIG.MODEL)
	_assistant_key = _labelled_field("Key variable", CONFIG.KEY_VARIABLE)
	_assistant_key.tooltip_text = "Name of an environment variable holding a " \
		+ "credential. The key itself is never stored - both settings files " \
		+ "are plain text and one of them is in git."

	var buttons := HBoxContainer.new()
	var save_global := Button.new()
	save_global.text = "Save for me"
	save_global.tooltip_text = "Editor settings: this developer, every project."
	save_global.pressed.connect(_on_save_assistant.bind(false))
	buttons.add_child(save_global)
	var save_local := Button.new()
	save_local.text = "Save for this project"
	save_local.tooltip_text = "A gitignored file beside the project, which a " \
		+ "headless tool run can also read."
	save_local.pressed.connect(_on_save_assistant.bind(true))
	buttons.add_child(save_local)
	_dock.add_child(buttons)

	_assistant_status = Label.new()
	_assistant_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_assistant_status.add_theme_color_override(
		"font_color", Color(0.55, 0.6, 0.65))
	_dock.add_child(_assistant_status)

	_load_assistant()


func _labelled_field(caption: String, key: String) -> LineEdit:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(84, 0)
	row.add_child(label)
	var field := LineEdit.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.set_meta("setting_key", key)
	row.add_child(field)
	_dock.add_child(row)
	return field


func _load_assistant() -> void:
	_assistant_enabled.button_pressed = bool(CONFIG.get_value(CONFIG.ENABLED))
	_assistant_host.text = str(CONFIG.get_value(CONFIG.HOST))
	_assistant_model.text = str(CONFIG.get_value(CONFIG.MODEL))
	_assistant_key.text = str(CONFIG.get_value(CONFIG.KEY_VARIABLE))
	var sources: Array[String] = []
	for key in [CONFIG.ENABLED, CONFIG.HOST, CONFIG.MODEL]:
		sources.append("%s: %s" % [key, CONFIG.source_of(key)])
	_assistant_status.text = ", ".join(sources)


## Write the fields to one scope, and say which.
##
## Environment beats both, so an overridden field is reported rather than
## silently accepted - a value that will not take effect looks identical to one
## that did not save.
func _on_save_assistant(local: bool) -> void:
	var values := {
		CONFIG.ENABLED: _assistant_enabled.button_pressed,
		CONFIG.HOST: _assistant_host.text.strip_edges(),
		CONFIG.MODEL: _assistant_model.text.strip_edges(),
		CONFIG.KEY_VARIABLE: _assistant_key.text.strip_edges(),
	}
	if local:
		var file := ConfigFile.new()
		file.load(CONFIG.LOCAL_FILE)
		for key in values:
			file.set_value(CONFIG.SECTION, key, values[key])
		var error := file.save(CONFIG.LOCAL_FILE)
		if error != OK:
			_assistant_status.text = "Could not write %s: %s" % [
				CONFIG.LOCAL_FILE, error_string(error)]
			return
	else:
		var editor := get_editor_interface().get_editor_settings()
		if editor == null:
			_assistant_status.text = "No editor settings available."
			return
		for key in values:
			editor.set_setting(CONFIG.EDITOR_PREFIX + key, values[key])

	var overridden: Array[String] = []
	for key in values:
		if CONFIG.source_of(key) == "environment":
			overridden.append(key)
	_load_assistant()
	if not overridden.is_empty():
		_assistant_status.text += "  -  %s still comes from the environment." \
			% ", ".join(overridden)


func _on_open_map() -> void:
	var scene := prospect_scene()
	if not FileAccess.file_exists(scene):
		_status.text = "No prospect scene at %s. Make one with a " % scene \
			+ "RegionProspect root and a Site child, or point " \
			+ "site_prospector/prospect_scene at yours."
		return
	get_editor_interface().open_scene_from_path(scene)
	# A Node2D root opened while the editor is on 3D shows an empty viewport,
	# which reads as the button having done nothing.
	get_editor_interface().set_main_screen_editor("2D")
	_status.text = "Press F to frame the map, then drag the Site rectangle."


func _refresh_kept() -> void:
	if _kept == null:
		return
	if not ResourceLoader.exists(chosen_site_path()):
		_kept.text = "No site kept yet."
		return
	var chosen: Resource = load(chosen_site_path())
	_kept.text = "No site kept yet." if chosen == null \
		else "Kept: %s" % chosen.call("describe")


func _on_apply() -> void:
	_refresh_kept()
	if not ResourceLoader.exists(chosen_site_path()):
		_status.text = "Nothing kept. Drag the site, then tick 'keep this " \
			+ "site' in the Inspector."
		return
	var chosen: Resource = load(chosen_site_path())
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
