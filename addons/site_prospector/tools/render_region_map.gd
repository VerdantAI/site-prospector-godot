extends SceneTree

## Renders the region, and prospects it for level-sized ground.
##
## Three artefacts, and the order matters:
##
## 1. **The topographic map** - shaded relief with contours, over the whole
##    region. Deliberately far larger than a level, because its job is to be
##    prospected against: you look at kilometres and choose the few hundred
##    metres worth building on.
## 2. **The height map** - the same ground as greyscale elevation, which is what
##    a terrain importer eats and what a heightmap edit acts on.
## 3. **The street map** - `render_neighbourhood_plan.gd`, for the window that
##    was chosen. Not this tool's job; this tool decides *where*.
##
## Prospecting scores candidate windows the way a developer would: enough
## buildable ground to be worth platting, enough relief to be interesting, and
## an arroyo crossing it so the grid has a reason to break.
##
##   godot --headless --path . \
##     --script res://scripts/tools/render_region_map.gd -- --write

const LANDFORM := preload("res://addons/site_prospector/region_landform.gd")

const TOPO_OUT := "res://demo/generated/region_topo.png"
const HEIGHT_OUT := "res://demo/generated/region_height.png"
## Where the ranking is left for the editor dock to read. The dock cannot see
## a spawned process's console, so the sites have to land in a file or the
## tool is a button that appears to do nothing.
const SITES_OUT := "res://demo/generated/prospect_sites.json"

## Metres per pixel on the rendered maps.
const METRES_PER_PIXEL := 3.0

## Contour interval. Five metres over a fan reads; one metre would be solid ink.
const CONTOUR_INTERVAL := 5.0
## Every fifth contour is an index contour, drawn heavier, as on a real sheet.
const INDEX_EVERY := 5

## The board being prospected for, in metres.
##
## **This has to match the level's `board_extent` or the ranking answers a
## question about a different board.** It was 288 x 492 - a 24 x 41 board that
## does not exist yet - while Gravel Sands is 9 x 17 lots. The winning site
## therefore described ground six times the area actually used, and the board
## landed in one corner of it, which is how a site scored for having a stream
## delivered a level with no stream on it.
##
## Override with `--window=WIDTHxHEIGHT` when prospecting for a larger board.
var window := Vector2(108.0, 204.0)
## How far the prospecting window moves between samples. Coarse on purpose:
## twelve orientations at a fine stride is millions of samples for a decision
## measured in tens of metres.
const STRIDE := 96.0
## Sample spacing inside a window during the coarse sweep.
##
## **The screen has to be fine enough to see what it is selecting for.** At
## 24 m it stepped over arroyos 18 m wide, so windows containing one never
## accumulated stream lots, never ranked, and never reached verification - the
## prospector was selecting for a feature it could not perceive. One lot is the
## natural resolution: it is the unit the level is built in.
const SAMPLE_STEP := 12.0

## **The coarse sweep can step over the thing that disqualifies a site.** A
## range front rises hundreds of metres across tens; a 24 m grid straddled one
## and reported 8.61 m of relief for a rectangle that actually holds 28. The
## top candidates are therefore re-measured finely and re-ranked, which is
## cheap because there are a dozen of them rather than eight thousand.
const VERIFY_STEP := 6.0
const VERIFY_COUNT := 24
## Ground steeper than this is not built on - LA's hillside street limit.
const MAX_GRADE := 0.15

## **Relief is a gate, not a bonus.** Scoring it as a bonus put the winning
## windows against the range front: the front is steep, steep ground counts as
## cut, and cut earned points, so the prospector kept choosing mountainsides
## with 70 m of relief across a board. Nobody plats that. A window has to sit
## inside the relief budget before anything else about it matters.
## The bible's relief budget, not a round number: about 12 m across the long
## axis. Set at 20 the prospector kept returning ground that broke the budget
## and fragmented the street network into unconnected scraps.
const MAX_RELIEF := 13.0
const MIN_BUILDABLE := 0.6

## **Prospect the way a developer does: find the flattest large rectangle.**
##
## Nobody surveying for a subdivision looks for broken ground - they look for
## the biggest piece of land they can lay out cheaply, at whatever angle it
## happens to sit, and take whatever drainage comes with it. Scoring *for*
## rough ground was backwards; it kept choosing sites against the range front
## because the front is steep and steepness was earning points.
##
## The measure is **contours crossed**. A rectangle that few contours cross is
## flat, whatever direction it faces - which is exactly the judgement made by
## eye on a topographic sheet, and why the sheet is the artefact to prospect
## against.
const ISOCLINE_INTERVAL := 2.0

## Enough fall to be worth benching. Dead-flat ground gives an unbroken grid
## and nothing to excavate.
const MIN_RELIEF := 4.0

## A stream is hoped for, not required. It earns its place in the score, but a
## flat site without one still beats a broken site with one.
const STREAM_LOTS := 6

## Orientations tried per site, in degrees. **The rectangle is not portrait.**
## It sits at whatever angle the ground rewards - the level is then rotated to
## match, which is how a fan suburb is actually platted and why the grid turns
## from one fan to the next. Twelve steps over 180 degrees covers landscape and
## portrait alike, since a rectangle at 90 degrees is the other aspect.
## Six steps of 30 degrees. Halved when the sweep went to lot resolution, to
## keep the pass affordable; a rectangle rarely cares about 15 degrees.
const ORIENTATIONS := [0.0, 30.0, 60.0, 90.0, 120.0, 150.0]

const SUN := Vector3(-0.55, 0.62, -0.55)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var landform: Resource = LANDFORM.new()
	var extent: Vector2 = landform.extent
	var width := int(extent.x / METRES_PER_PIXEL)
	var height := int(extent.y / METRES_PER_PIXEL)

	# One pass of elevations, reused by both images and by the prospector.
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(width * height)
	var lowest := INF
	var highest := -INF
	for py in height:
		for px in width:
			var value: float = landform.height_at(
				float(px) * METRES_PER_PIXEL, float(py) * METRES_PER_PIXEL)
			heights[py * width + px] = value
			lowest = minf(lowest, value)
			highest = maxf(highest, value)
	var span := maxf(highest - lowest, 0.001)

	var candidates := _prospect(landform, extent)

	_write_height_map(heights, width, height, lowest, span)
	_write_topographic_map(heights, width, height, lowest, span, candidates)

	print("Region %.0f x %.0f m at %.0f m/px, elevation %.1f .. %.1f m"
		% [extent.x, extent.y, METRES_PER_PIXEL, lowest, highest])
	print("  %s" % TOPO_OUT)
	print("  %s" % HEIGHT_OUT)
	_write_sites(candidates)
	print("Prospected for a %.0f x %.0f m board:" % [window.x, window.y])
	for index in mini(candidates.size(), 5):
		var site: Dictionary = candidates[index]
		print("  %d. at (%4.0f, %4.0f) m - relief %5.2f m, %3.0f%% buildable, "
			% [index + 1, site["x"], site["z"], site["relief"],
				site["buildable"] * 100.0]
			+ "%d stream lots, %3.0f deg, %.2f contours/lot, score %.2f"
				% [site["cut"], site["angle"],
					float(site["crossings"]) / float(maxi(int(site["cut"]) + 1, 1)) * 0.0
					+ float(site["crossings"]) / 984.0, site["score"]])
	quit(0)


## Leave the ranking where the editor can pick it up.
func _write_sites(candidates: Array) -> void:
	var top: Array = []
	for index in mini(candidates.size(), 12):
		var site: Dictionary = candidates[index]
		top.append({
			"rank": index + 1,
			"x": site["x"], "z": site["z"], "angle": site["angle"],
			"relief": site["relief"], "buildable": site["buildable"],
			"stream_lots": site["cut"], "score": site["score"],
			"contours_per_lot": float(site["crossings"]) / 984.0,
		})
	var file := FileAccess.open(SITES_OUT, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s." % SITES_OUT)
		return
	file.store_string(JSON.stringify({
		"window": {"x": window.x, "y": window.y},
		"sites": top,
	}, "  "))


## Slide a board-sized window over the region and score what it would contain.
##
## The scoring is a developer's, not a hiker's: **mostly buildable, but not
## flat, and cut by something.** Ground that is entirely gentle plats into an
## unbroken grid, which is the thing the design is trying not to have; ground
## that is mostly steep has nowhere to put a suburb. What earns a site is an
## arroyo running through buildable ground, because that is where a street has
## a reason to stop.
func _prospect(landform: Resource, extent: Vector2) -> Array:
	var sites: Array = []
	var z := 0.0
	while z + window.y <= extent.y:
		var x := 0.0
		while x + window.x <= extent.x:
			var best: Dictionary = {}
			for degrees in ORIENTATIONS:
				var site := _assess(landform, Vector2(x, z),
					deg_to_rad(float(degrees)), extent)
				if site.is_empty():
					continue
				if best.is_empty() or float(site["score"]) > float(best["score"]):
					best = site
			if not best.is_empty():
				sites.append(best)
			x += STRIDE
		z += STRIDE
	sites.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))

	# Fine verification of the leaders. A site that only passed because the
	# coarse grid missed a scarp is dropped here rather than shipped.
	var verified: Array = []
	for index in mini(sites.size(), VERIFY_COUNT):
		var coarse: Dictionary = sites[index]
		var site := _assess(landform, Vector2(coarse["x"], coarse["z"]),
			deg_to_rad(float(coarse["angle"])), extent, VERIFY_STEP)
		if not site.is_empty():
			verified.append(site)
	verified.sort_custom(
		func(a, b): return float(a["score"]) > float(b["score"]))
	log_dropped(sites.size(), verified.size())
	return verified


## Say what verification threw away, rather than letting a shorter list look
## like a thinner region.
static func log_dropped(coarse_count: int, verified_count: int) -> void:
	var checked := mini(coarse_count, VERIFY_COUNT)
	if verified_count < checked:
		print("  verification dropped %d of %d leaders: the coarse sweep "
			% [checked - verified_count, checked]
			+ "missed ground that disqualifies them")


## Measure one window at one orientation. Returns empty if it fails a gate.
func _assess(landform: Resource, origin: Vector2, angle: float,
		extent: Vector2, step: float = SAMPLE_STEP) -> Dictionary:
	var forward := Vector2(cos(angle), sin(angle))
	var side := Vector2(-forward.y, forward.x)
	var lowest := INF
	var highest := -INF
	var lots := 0
	var buildable := 0
	var cut := 0
	var crossings := 0
	var along := 0.0
	while along < window.y:
		var across := 0.0
		while across < window.x:
			var point := origin + forward * along + side * across
			if point.x < 0.0 or point.y < 0.0 \
					or point.x >= extent.x or point.y >= extent.y:
				return {}
			var here: float = landform.height_at(point.x, point.y)
			lowest = minf(lowest, here)
			highest = maxf(highest, here)
			var band := floorf(here / ISOCLINE_INTERVAL)
			var ahead: float = landform.height_at(
				point.x + forward.x * step,
				point.y + forward.y * step)
			var beside: float = landform.height_at(
				point.x + side.x * step, point.y + side.y * step)
			# Contours crossed, which is flatness measured the way a sheet
			# shows it: closely spaced lines are steep ground.
			if band != floorf(ahead / ISOCLINE_INTERVAL):
				crossings += 1
			if band != floorf(beside / ISOCLINE_INTERVAL):
				crossings += 1
			var grade := maxf(absf(ahead - here), absf(beside - here)) / step
			lots += 1
			if grade <= MAX_GRADE:
				buildable += 1
			elif grade > MAX_GRADE * 2.0:
				cut += 1
			across += step
		along += step
	var fraction := float(buildable) / float(maxi(lots, 1))
	var relief := highest - lowest
	if relief > MAX_RELIEF or relief < MIN_RELIEF or fraction < MIN_BUILDABLE:
		return {}
	return {
		"x": origin.x, "z": origin.y, "angle": rad_to_deg(angle),
		"relief": relief, "buildable": fraction, "cut": cut,
		"crossings": crossings,
		"score": _score(fraction, cut, crossings, lots),
	}


func _score(buildable: float, cut: int, crossings: int, lots: int) -> float:
	# Contours crossed per sample. Flat ground crosses few; a hillside crosses
	# one every step. This is the whole judgement, so it carries the weight.
	var density := float(crossings) / float(maxi(lots, 1) * 2)
	var flat := clampf(1.0 - density, 0.0, 1.0)
	# Land that can actually be laid out.
	var plat := clampf(buildable, 0.0, 1.0)
	# A stream, if one happens to run through it.
	var stream := clampf(float(cut) / float(STREAM_LOTS), 0.0, 1.0)
	return flat * 0.55 + plat * 0.25 + stream * 0.20


func _write_height_map(heights: PackedFloat32Array, width: int, height: int,
		lowest: float, span: float) -> void:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for py in height:
		for px in width:
			var value := (heights[py * width + px] - lowest) / span
			image.set_pixel(px, py, Color(value, value, value, 1.0))
	_save(image, HEIGHT_OUT)


## Shaded relief, hypsometric tint and contours - a sheet you can read.
func _write_topographic_map(heights: PackedFloat32Array, width: int,
		height: int, lowest: float, span: float, candidates: Array) -> void:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var sun := SUN.normalized()
	for py in height:
		for px in width:
			var here := heights[py * width + px]
			var east := heights[py * width + mini(px + 1, width - 1)]
			var south := heights[mini(py + 1, height - 1) * width + px]
			var normal := Vector3(here - east, METRES_PER_PIXEL, here - south) \
				.normalized()
			var light := clampf(normal.dot(sun) * 0.75 + 0.45, 0.15, 1.0)
			var band := (here - lowest) / span
			var colour := _hypsometric(band) * light
			# Contours, found by band crossing rather than traced.
			var level := floorf(here / CONTOUR_INTERVAL)
			if level != floorf(east / CONTOUR_INTERVAL) \
					or level != floorf(south / CONTOUR_INTERVAL):
				var index_contour := int(level) % INDEX_EVERY == 0
				colour = colour.lerp(Color(0.32, 0.20, 0.10),
					0.85 if index_contour else 0.45)
			image.set_pixel(px, py, Color(colour.r, colour.g, colour.b, 1.0))
	# Mark what prospecting chose, best first.
	for index in mini(candidates.size(), 3):
		var site: Dictionary = candidates[index]
		_outline(image, site, Color(0.95, 0.25, 0.15) if index == 0
			else Color(0.95, 0.75, 0.15))
	_save(image, TOPO_OUT)


func _hypsometric(band: float) -> Color:
	# Valley green through fan tan to mountain grey, the usual sheet ramp.
	if band < 0.35:
		return Color(0.55, 0.62, 0.42).lerp(Color(0.78, 0.74, 0.52),
			band / 0.35)
	if band < 0.7:
		return Color(0.78, 0.74, 0.52).lerp(Color(0.72, 0.58, 0.42),
			(band - 0.35) / 0.35)
	return Color(0.72, 0.58, 0.42).lerp(Color(0.88, 0.88, 0.86),
		(band - 0.7) / 0.3)


func _outline(image: Image, site: Dictionary, colour: Color) -> void:
	var angle := deg_to_rad(float(site["angle"]))
	var forward := Vector2(cos(angle), sin(angle))
	var side := Vector2(-forward.y, forward.x)
	var origin := Vector2(float(site["x"]), float(site["z"]))
	var corners := [
		origin,
		origin + side * window.x,
		origin + side * window.x + forward * window.y,
		origin + forward * window.y,
	]
	for index in 4:
		_line(image, corners[index], corners[(index + 1) % 4], colour)


func _line(image: Image, from: Vector2, to: Vector2, colour: Color) -> void:
	var steps := int(from.distance_to(to) / METRES_PER_PIXEL) + 1
	for step in steps + 1:
		var point := from.lerp(to, float(step) / float(maxi(steps, 1)))
		var px := int(point.x / METRES_PER_PIXEL)
		var py := int(point.y / METRES_PER_PIXEL)
		if px >= 0 and py >= 0 and px < image.get_width() \
				and py < image.get_height():
			image.set_pixel(px, py, colour)


func _save(image: Image, path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error := image.save_png(absolute)
	if error != OK:
		push_error("Could not write %s: %s." % [path, error_string(error)])
