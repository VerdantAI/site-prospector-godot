@tool
class_name SiteProspectorConfig
extends RefCounted

## Where the assistant's setup comes from, and in what order.
##
## Four scopes, because four different questions are being answered and putting
## them in one place gets at least one of them wrong:
##
## | Scope | Lives in | Committed | Answers |
## | --- | --- | --- | --- |
## | **Environment** | the shell | no | secrets, and CI |
## | **Local file** | `res://site_prospector.local.cfg` | **gitignored** | this project, on this machine |
## | **Editor settings** | `~/.config` | no | this developer, every project |
## | **Defaults** | here | — | something sensible |
##
## **The local file exists because `EditorSettings` is not reachable headless.**
## Every tool this addon ships runs as `godot --headless --script`, where there
## is no editor and therefore no editor settings, so configuration kept only
## there would be invisible to exactly the batch jobs most likely to want it.
##
## **Secrets come from the environment and nowhere else.** Both settings files
## are plain text on disk and one of them is in git. A hosted endpoint's key is
## read from a variable; only the variable's *name* is ever recorded.

const LOCAL_FILE := "res://site_prospector.local.cfg"
const SECTION := "assistant"

const ENABLED := "enabled"
const HOST := "host"
const MODEL := "model"
const KEY_VARIABLE := "key_variable"

const DEFAULTS := {
	ENABLED: false,
	HOST: "http://localhost:11434",
	MODEL: "qwen3:8b",
	KEY_VARIABLE: "",
}

## Editor settings are namespaced; the local file and environment are not, so
## they read `host` where the editor reads `site_prospector/assistant/host`.
const EDITOR_PREFIX := "site_prospector/assistant/"
const ENVIRONMENT_PREFIX := "SITE_PROSPECTOR_"


## Resolve one setting, most specific source first.
##
## Environment beats the local file beats editor settings beats the default, so
## a machine can override a project, a project can override a developer, and CI
## can override everything without editing a file it would then have to unedit.
static func get_value(key: String) -> Variant:
	var from_environment := OS.get_environment(
		ENVIRONMENT_PREFIX + key.to_upper())
	if not from_environment.is_empty():
		return _coerce(key, from_environment)

	var local := ConfigFile.new()
	if local.load(LOCAL_FILE) == OK and local.has_section_key(SECTION, key):
		return local.get_value(SECTION, key)

	var editor := _editor_settings()
	if editor != null and editor.has_setting(EDITOR_PREFIX + key):
		return editor.get_setting(EDITOR_PREFIX + key)

	return DEFAULTS.get(key)


## Where a resolved value came from, so a panel can say so rather than leaving
## a developer to wonder why their edit did nothing.
static func source_of(key: String) -> String:
	if not OS.get_environment(ENVIRONMENT_PREFIX + key.to_upper()).is_empty():
		return "environment"
	var local := ConfigFile.new()
	if local.load(LOCAL_FILE) == OK and local.has_section_key(SECTION, key):
		return "local file"
	var editor := _editor_settings()
	if editor != null and editor.has_setting(EDITOR_PREFIX + key):
		return "editor settings"
	return "default"


## The credential, read from the environment or not at all.
static func api_key() -> String:
	var variable := str(get_value(KEY_VARIABLE))
	if variable.is_empty():
		return ""
	return OS.get_environment(variable)


static func is_enabled() -> bool:
	return bool(get_value(ENABLED))


## Write the local file, so a developer can start from something rather than a
## blank page. Never writes a secret - only the name of the variable holding it.
static func write_local_template() -> Error:
	var local := ConfigFile.new()
	local.load(LOCAL_FILE)
	for key in DEFAULTS:
		if key == KEY_VARIABLE:
			continue
		if not local.has_section_key(SECTION, key):
			local.set_value(SECTION, key, DEFAULTS[key])
	return local.save(LOCAL_FILE)


## `EditorSettings` when there is an editor, and null when there is not.
##
## A headless tool run has neither, which is the whole reason the local file
## exists; asking for it there must answer nothing rather than fail.
static func _editor_settings() -> Object:
	if not Engine.is_editor_hint():
		return null
	if not Engine.has_singleton("EditorInterface"):
		return null
	var interface: Object = Engine.get_singleton("EditorInterface")
	if interface == null or not interface.has_method("get_editor_settings"):
		return null
	return interface.call("get_editor_settings")


## Environment variables are strings; the setting they stand in for may not be.
static func _coerce(key: String, raw: String) -> Variant:
	var default: Variant = DEFAULTS.get(key)
	match typeof(default):
		TYPE_BOOL:
			return raw.to_lower() in ["1", "true", "yes", "on"]
		TYPE_INT:
			return int(raw)
		TYPE_FLOAT:
			return float(raw)
		_:
			return raw
