extends SceneTree

## Configuration resolves in the right order, and headless is the case that
## matters: every tool this addon ships runs without an editor, so a setup that
## only lived in editor settings would be invisible exactly where a batch job
## wants it.


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run() -> void:
	const CONFIG := preload("res://addons/site_prospector/assistant_config.gd")

	# Defaults, with no file and no environment.
	if str(CONFIG.get_value(CONFIG.HOST)) != "http://localhost:11434":
		_fail("Default host is wrong.")
	if CONFIG.source_of(CONFIG.HOST) != "default":
		_fail("With nothing set, the source should be the default.")

	# A local file overrides the default, and is readable headless - which
	# editor settings are not.
	var file := ConfigFile.new()
	file.set_value(CONFIG.SECTION, CONFIG.HOST, "http://box:11434")
	file.set_value(CONFIG.SECTION, CONFIG.MODEL, "olmo2:7b")
	if file.save(CONFIG.LOCAL_FILE) != OK:
		_fail("Could not write the local file.")
	if str(CONFIG.get_value(CONFIG.HOST)) != "http://box:11434":
		_fail("The local file did not override the default.")
	if CONFIG.source_of(CONFIG.MODEL) != "local file":
		_fail("The local file's source was misreported.")

	# The environment beats the file, so CI can override without editing one.
	OS.set_environment("SITE_PROSPECTOR_HOST", "http://ci:11434")
	if str(CONFIG.get_value(CONFIG.HOST)) != "http://ci:11434":
		_fail("The environment did not win over the local file.")
	if CONFIG.source_of(CONFIG.HOST) != "environment":
		_fail("The environment's source was misreported.")

	# Strings from the environment become the type the setting actually is.
	OS.set_environment("SITE_PROSPECTOR_ENABLED", "true")
	if typeof(CONFIG.get_value(CONFIG.ENABLED)) != TYPE_BOOL \
			or not CONFIG.is_enabled():
		_fail("A boolean from the environment stayed a string.")

	# A credential is never a setting - only the name of the variable holding
	# it, because both settings files are plain text and one is in git.
	OS.set_environment("SITE_PROSPECTOR_KEY_VARIABLE", "MY_SECRET")
	OS.set_environment("MY_SECRET", "shhh")
	if CONFIG.api_key() != "shhh":
		_fail("The key was not read from its named variable.")
	var written := ConfigFile.new()
	written.load(CONFIG.LOCAL_FILE)
	for key in written.get_section_keys(CONFIG.SECTION):
		if str(written.get_value(CONFIG.SECTION, key)).contains("shhh"):
			_fail("A secret was written to the local file.")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		CONFIG.LOCAL_FILE))
	print("Assistant config: environment beats the local file beats editor "
		+ "settings, and it all works with no editor.")
	quit(0)
