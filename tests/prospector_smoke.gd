extends SceneTree

## The addon works in a project that is not the game it came from.
##
## That is the whole point of the extraction, and the only test that can catch
## the failure it is guarding against: a hidden dependence on being inside
## burb-sweeper would show up here as a missing path or an unresolved class.


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run() -> void:
	var scene: Node = (load("res://demo/prospect_demo.tscn") as PackedScene) \
		.instantiate()
	root.add_child(scene)
	await process_frame

	if scene.call("_own_backdrop") == null:
		_fail("The map drew nothing; the scene depends on a file it lacks.")

	var site: Node2D = scene.get_node("Site")
	site.position = Vector2(139, 126)
	scene.call("_restate")
	var reading: Dictionary = scene.get("_reading")
	if reading.is_empty():
		_fail("Dragging the site produced no survey.")
	for key in ["relief", "buildable", "drainage", "benches", "fill_volume"]:
		if not reading.has(key):
			_fail("Survey is missing %s." % key)
	if int(reading["benches"]) <= 0:
		_fail("No benches: automate-godot is missing or not being reached.")

	var layers: Array = scene.get("layers")
	if layers.size() < 2:
		_fail("Demo should carry fertility and a mineral layer.")
	for layer in layers:
		if layer.call("summarise", (reading["layers"] as Array)[
				layers.find(layer)]).is_empty():
			_fail("A survey layer summarised to nothing.")

	# The site survives the trip through disk, which is how the map hands a
	# choice to a level in another scene.
	scene.keep_this_site = true
	await process_frame
	var chosen: Resource = load("res://chosen_site.tres")
	if chosen == null or not chosen.call("describe").contains("buildable"):
		_fail("Keeping a site did not survive the round trip.")

	print("Site Prospector: surveys, benches and keeps a site in a project "
		+ "of its own.")
	quit(0)
