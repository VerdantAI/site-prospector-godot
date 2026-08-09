@tool
class_name RegionProspect
extends Node2D

## Prospect by dragging a rectangle over the region, and read the ground under
## it as you go.
##
## **The ranked list answers "where is good"; this answers "what about here".**
## A score cannot know that the opening beat needs a pond within sight of the
## first house, or that a street should dead-end where the player will first
## look, so the last move is always a human one. Opening a PNG in an image
## viewer made that move impossible: you could see the ground and not measure
## it, and the numbers were somewhere else entirely.
##
## Open the scene, drag the `Site` child with the ordinary move and rotate
## tools, and the metrics under it update live. When it reads well, copy the
## origin and angle onto the level's `RegionWindow` - or press `save_site` and
## let the dock apply it.
##
## The map is a backdrop, not the source. Every number here is sampled from the
## `RegionLandform` itself, so a stale PNG cannot lie about the ground.

## The ground being prospected.
@export var region: Resource:
	set(value):
		region = value
		_restate()

## Backdrop, optional.
##
## **Prospecting is an offer, not a gate.** Assigning the sweep's output here
## shows the ranked candidates drawn on it; leaving it empty makes this scene
## draw its own shaded relief from the landform, so a level that wants to place
## a site by hand never waits on a minute-long sweep it did not ask for.
@export var map_texture: Texture2D:
	set(value):
		map_texture = value
		queue_redraw()

## Metres per pixel of the backdrop this scene draws for itself. Coarser than
## the sweep's output on purpose: it is a picture to aim by, and the numbers
## come from the landform regardless.
@export var preview_metres_per_pixel: float = 8.0:
	set(value):
		preview_metres_per_pixel = maxf(value, 1.0)
		_backdrop = null
		queue_redraw()

## Redraw the backdrop from the landform. Needed after the ground changes.
@export var refresh_backdrop: bool = false:
	set(_value):
		refresh_backdrop = false
		_backdrop = null
		queue_redraw()

## Metres per pixel of the backdrop, which is how canvas position becomes a
## region position. Must match `render_region_map.gd`.
@export var metres_per_pixel: float = 3.0:
	set(value):
		metres_per_pixel = maxf(value, 0.01)
		_restate()

## The site's shape, in lots.
##
## **A level is not obliged to be 9 x 17.** The rectangle followed a constant,
## so every level was prospected as though it were Gravel Sands; change this
## and the rectangle, the metrics and the verdict all follow. Non-rectangular
## sites are the next shape to support - the effective outline is already
## organic once benching removes the ground too steep to build on, so what is
## missing is an authored boundary rather than a derived one.
@export var board_lots := Vector2i(9, 17):
	set(value):
		board_lots = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		_restate()

## The site in metres, derived from lots.
var board_extent: Vector2:
	get:
		return Vector2(board_lots) * cell_size

## Lot size, so metrics are reported in the unit levels are built in.
@export var cell_size: float = 12.0:
	set(value):
		cell_size = maxf(value, 1.0)
		_restate()

## Metres below its neighbours' mean before a lot counts as drainage, at one
## lot's spacing. Set above the terrain's own roughness: a few metres of
## undulation makes half a metre of local variation over a 12 m lot, and
## counting that as drainage reports channels where there is only texture.
@export var channel_depth_threshold: float = 0.8:
	set(value):
		channel_depth_threshold = maxf(value, 0.01)
		_restate()

## What else this site is asked about: fertility, minerals, soil, water.
##
## **Elevation is only the first question.** Each layer prints its own HUD line
## and any one of them can be drawn as the backdrop, so adding "how good is the
## soil here" is a resource in this array rather than a change to this script.
@export var layers: Array[Resource] = []:
	set(value):
		layers = value
		_backdrop = null
		_restate()

## Which layer the backdrop draws. -1 is the ground itself.
@export var backdrop_layer: int = -1:
	set(value):
		backdrop_layer = value
		_backdrop = null
		queue_redraw()

## Ground steeper than this is not built on. LA's hillside street limit.
@export var max_grade: float = 0.15:
	set(value):
		max_grade = maxf(value, 0.001)
		_restate()

## **Keep this site.** Writes it to `res://levels/chosen_site.tres`; the Level
## Authoring dock then applies it to the level's `RegionWindow`.
##
## Two steps because the map and the level are different scenes and only one is
## open at a time, so the choice has to be left somewhere rather than handed
## over. It was a checkbox at the bottom of a collapsed group, which is not a
## save point anybody would find.
@export var keep_this_site: bool = false:
	set(_value):
		keep_this_site = false
		_save()

@export_group("Result")
## Where the site's south-west corner lands, in region metres.
@export var site_origin := Vector2.ZERO
## How far the board is turned, in degrees.
@export var site_angle_degrees: float = 0.0

const CHOSEN_SITE_PATH := "res://chosen_site.tres"
## **Loaded rather than preloaded, on purpose.** `automate-godot` is required,
## but a hard `preload` of a missing file is a parse error, and a parse error
## takes the whole addon down with a message about a path rather than about a
## missing dependency. Loading it lets the plugin say what is wrong instead.
const BENCH_RULES_PATH := \
	"res://addons/automate_godot/terrain/bench_rules.gd"

static var _bench_rules: GDScript


static func bench_rules() -> GDScript:
	if _bench_rules == null and ResourceLoader.exists(BENCH_RULES_PATH):
		_bench_rules = load(BENCH_RULES_PATH)
	return _bench_rules
const CHOSEN_SITE := preload("res://addons/site_prospector/chosen_site.gd")


## Digits grouped, because six-figure earthwork is unreadable otherwise.
static func _thousands(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	while text.length() > 3:
		out = "," + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + out

var _site: Node2D
var _last_transform := Transform2D()
var _reading: Dictionary = {}
var _backdrop: ImageTexture


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	_restate()


## Polled rather than signalled: a child's transform notification does not
## reach its parent, and the child is the thing being dragged.
func _process(_delta: float) -> void:
	var site := _site_node()
	if site == null:
		return
	if site.transform != _last_transform:
		_last_transform = site.transform
		_restate()


func _site_node() -> Node2D:
	if _site != null and is_instance_valid(_site):
		return _site
	_site = get_node_or_null(^"Site") as Node2D
	return _site


## Re-read the ground under the rectangle.
##
## **This is a survey, and it is meant to become a player one.** Reading ground
## before committing labour to it is already what the game is about - test
## pits, transects, the isopach as the level's own map - so the numbers here
## are chosen to be ones a person standing on the land could care about, not
## ones only a level tool understands: how much of it can be built on, where
## the water goes, how much earth has to move, and how deep the fill is over
## whatever is buried.
func _restate() -> void:
	var site := _site_node()
	if site == null or region == null or not region.has_method("height_at"):
		_reading = {}
		queue_redraw()
		return

	var angle := site.rotation
	site_angle_degrees = snappedf(rad_to_deg(angle), 1.0)
	site_origin = (site.position * metres_per_pixel).round()

	var forward := Vector2(cos(angle), sin(angle))
	var side := Vector2(-forward.y, forward.x)
	var columns := board_lots.x
	var rows := board_lots.y

	# One pass of lot heights; every metric below reads from it.
	var heights: Array = []
	heights.resize(columns * rows)
	var lowest := INF
	var highest := -INF
	for row in rows:
		for column in columns:
			var point := site_origin + forward * (float(row) * cell_size) \
				+ side * (float(column) * cell_size)
			var here := float(region.height_at(point.x, point.y))
			heights[row * columns + column] = here
			lowest = minf(lowest, here)
			highest = maxf(highest, here)

	var buildable := 0
	var drainage := 0
	var crossings := 0
	var grade_total := 0.0
	for row in rows:
		for column in columns:
			var index := row * columns + column
			var here: float = heights[index]
			var neighbours: Array = []
			if column + 1 < columns:
				neighbours.append(float(heights[index + 1]))
			if column > 0:
				neighbours.append(float(heights[index - 1]))
			if row + 1 < rows:
				neighbours.append(float(heights[index + columns]))
			if row > 0:
				neighbours.append(float(heights[index - columns]))
			if neighbours.is_empty():
				continue
			var steepest := 0.0
			var mean := 0.0
			for value in neighbours:
				steepest = maxf(steepest, absf(float(value) - here) / cell_size)
				mean += float(value)
				if floorf(here / 2.0) != floorf(float(value) / 2.0):
					crossings += 1
			mean /= float(neighbours.size())
			grade_total += steepest
			if steepest <= max_grade:
				buildable += 1
			# **A channel is a low line, not a steep one.** Finding streams by
			# steepness missed them: at 12 m lot spacing a 3.6 m arroyo averages
			# to about 28% and slips under a 30% threshold, so a rectangle
			# sitting squarely over a drainage reported none. Ground below the
			# mean of its neighbours is a hollow however gently it got there,
			# which is what water follows.
			if here < mean - channel_depth_threshold:
				drainage += 1

	# Every other layer, sampled over the same lots.
	var layer_values: Array = []
	for layer in layers:
		if layer == null or not layer.has_method("sample"):
			layer_values.append([])
			continue
		var values: Array = []
		for row in rows:
			for column in columns:
				var point := site_origin + forward * (float(row) * cell_size) \
					+ side * (float(column) * cell_size)
				values.append(float(layer.sample(region, point.x, point.y)))
		layer_values.append(values)

	var lots := columns * rows
	var rules := bench_rules()
	var solved: Dictionary = {} if rules == null \
		else rules.solve(heights, columns, rows, {
		"bench_step": 1.8, "min_bench_cells": 6, "cell_size": cell_size,
		"max_grade": max_grade,
	})
	var earthwork: Dictionary = {"fill_volume": 0.0}
	var deepest := 0.0
	var bench_count := 0
	if not solved.is_empty():
		earthwork = rules.earthwork(solved, cell_size * cell_size)
		bench_count = (solved["benches"] as Array).size()
		for value in (solved["fill"] as Array):
			deepest = maxf(deepest, float(value))

	_reading = {
		"lots": lots,
		"columns": columns,
		"rows": rows,
		"lowest": lowest,
		"highest": highest,
		"relief": highest - lowest,
		"mean_grade": grade_total / float(maxi(lots, 1)),
		"buildable": float(buildable) / float(maxi(lots, 1)),
		"buildable_lots": buildable,
		"drainage": drainage,
		"benches": bench_count,
		"deepest_fill": deepest,
		"fill_volume": float(earthwork["fill_volume"]),
		"contours": float(crossings) / float(maxi(lots, 1) * 4),
		"layers": layer_values,
	}
	queue_redraw()


func _draw() -> void:
	if map_texture != null:
		draw_texture(map_texture, Vector2.ZERO)
	else:
		var own := _own_backdrop()
		if own != null:
			# Drawn coarse, scaled up to the same canvas metres-per-pixel, so
			# the site rectangle means the same thing either way.
			var scale := preview_metres_per_pixel / metres_per_pixel
			draw_texture_rect(own, Rect2(Vector2.ZERO,
				Vector2(own.get_size()) * scale), false)
	var site := _site_node()
	if site == null:
		return

	# The rectangle, in canvas pixels, at the site's own rotation.
	var pixels := board_extent / metres_per_pixel
	var forward := Vector2(cos(site.rotation), sin(site.rotation))
	var side := Vector2(-forward.y, forward.x)
	var corners := PackedVector2Array([
		site.position,
		site.position + side * pixels.x,
		site.position + side * pixels.x + forward * pixels.y,
		site.position + forward * pixels.y,
		site.position,
	])
	draw_polyline(corners, Color(0.95, 0.25, 0.15), 2.0)
	# A tick on the leading edge, so the board's orientation is not ambiguous.
	draw_line(site.position, site.position + forward * 18.0,
		Color(0.95, 0.75, 0.15), 2.0)

	if _reading.is_empty():
		return
	var font := ThemeDB.fallback_font
	var lines := PackedStringArray([
		"(%.0f, %.0f) m at %.0f deg" % [site_origin.x, site_origin.y,
			site_angle_degrees],
		"%d x %d lots  -  %.0f x %.0f m" % [_reading["columns"],
			_reading["rows"], board_extent.x, board_extent.y],
		"elevation %.0f - %.0f m  (relief %.1f)" % [_reading["lowest"],
			_reading["highest"], float(_reading["relief"])],
		"mean grade %.0f%%" % (float(_reading["mean_grade"]) * 100.0),
		"%.0f%% buildable  -  %d lots" % [
			float(_reading["buildable"]) * 100.0, int(_reading["buildable_lots"])],
		"drainage %d lots" % int(_reading["drainage"]),
		"%d benches, deepest fill %.1f m" % [int(_reading["benches"]),
			float(_reading["deepest_fill"])],
		"earthwork %s m3" % _thousands(int(float(_reading["fill_volume"]))),
		"%.2f contours/lot" % float(_reading["contours"]),
	])
	var layer_values: Array = _reading.get("layers", [])
	for index in mini(layers.size(), layer_values.size()):
		var layer: Resource = layers[index]
		if layer == null or not layer.has_method("summarise"):
			continue
		lines.append(layer.call("summarise", layer_values[index]))
	lines.append(_verdict())
	lines.append("Inspector: tick 'keep this site' to save it")
	var origin := site.position + Vector2(8.0, -8.0 - 16.0 * lines.size())
	draw_rect(Rect2(origin + Vector2(-6, -14),
		Vector2(240, 16.0 * lines.size() + 10)), Color(0, 0, 0, 0.65))
	for index in lines.size():
		draw_string(font, origin + Vector2(0.0, 16.0 * index), lines[index],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, _line_colour(index))


## Shaded relief drawn from the landform itself, so this scene is usable the
## first time it is opened and does not depend on any file having been made.
func _own_backdrop() -> ImageTexture:
	if _backdrop != null:
		return _backdrop
	if region == null or not region.has_method("height_at"):
		return null
	var extent: Vector2 = region.get("extent")
	var width := int(extent.x / preview_metres_per_pixel)
	var height := int(extent.y / preview_metres_per_pixel)
	if width <= 0 or height <= 0:
		return null
	var heights := PackedFloat32Array()
	heights.resize(width * height)
	var lowest := INF
	var highest := -INF
	for py in height:
		for px in width:
			var value := float(region.height_at(
				float(px) * preview_metres_per_pixel,
				float(py) * preview_metres_per_pixel))
			heights[py * width + px] = value
			lowest = minf(lowest, value)
			highest = maxf(highest, value)
	var span := maxf(highest - lowest, 0.001)
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var sun := Vector3(-0.55, 0.62, -0.55).normalized()
	var chosen: Resource = null
	if backdrop_layer >= 0 and backdrop_layer < layers.size():
		chosen = layers[backdrop_layer]
	for py in height:
		for px in width:
			var here := heights[py * width + px]
			var east := heights[py * width + mini(px + 1, width - 1)]
			var south := heights[mini(py + 1, height - 1) * width + px]
			var normal := Vector3(here - east, preview_metres_per_pixel,
				here - south).normalized()
			var light := clampf(normal.dot(sun) * 0.75 + 0.45, 0.15, 1.0)
			var band := (here - lowest) / span
			var tint := Color(0.55, 0.62, 0.42).lerp(Color(0.82, 0.78, 0.62),
				band)
			if chosen != null:
				# Shaded by the ground, coloured by the layer, so relief still
				# reads underneath whatever is being surveyed.
				tint = chosen.call("tint", chosen.call("sample", region,
					float(px) * preview_metres_per_pixel,
					float(py) * preview_metres_per_pixel))
			# Contours, so steepness reads without a legend.
			if floorf(here / 5.0) != floorf(east / 5.0) \
					or floorf(here / 5.0) != floorf(south / 5.0):
				tint = tint.lerp(Color(0.32, 0.20, 0.10), 0.5)
			image.set_pixel(px, py, Color(tint.r * light, tint.g * light,
				tint.b * light, 1.0))
	_backdrop = ImageTexture.create_from_image(image)
	return _backdrop


## The judgement the procedure states, applied to what is under the rectangle.
func _verdict() -> String:
	var relief := float(_reading["relief"])
	var buildable := float(_reading["buildable"])
	if buildable < 0.6:
		return "too steep to plat"
	if relief > 13.0:
		return "over the relief budget"
	if relief < 4.0:
		return "dead flat - nothing to dig"
	if int(_reading["drainage"]) == 0:
		return "no drainage - grid will not break"
	return "good ground"


## How many HUD lines there are, so the verdict can be coloured as the last of
## them however many layers were added.
func lines_count() -> int:
	return 9 + layers.size() + 2


func _line_colour(index: int) -> Color:
	if index < 2:
		return Color(0.85, 0.88, 0.9)
	if index == lines_count() - 2:
		return Color(0.55, 0.85, 0.45) if _verdict() == "good ground" \
			else Color(0.95, 0.7, 0.35)
	return Color(0.75, 0.8, 0.85)


func _save() -> void:
	if _reading.is_empty():
		push_warning("Nothing measured yet - drag the Site first.")
		return
	var chosen := CHOSEN_SITE.new()
	chosen.origin = site_origin
	chosen.angle_degrees = site_angle_degrees
	chosen.board_lots = board_lots
	chosen.relief = float(_reading["relief"])
	chosen.buildable = float(_reading["buildable"])
	chosen.drainage_lots = int(_reading["drainage"])
	chosen.verdict = _verdict()
	var error := ResourceSaver.save(chosen, CHOSEN_SITE_PATH)
	if error != OK:
		push_error("Could not save %s: %s" % [CHOSEN_SITE_PATH,
			error_string(error)])
		return
	print("Kept: %s" % chosen.describe())
