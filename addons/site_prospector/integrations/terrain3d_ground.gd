@tool
class_name Terrain3DGround
extends Node3D

## The ground, rendered and collided by Terrain3D.
##
## Answers the same `height_at(x, z)` the rest of the game already asks
## `TerrainBlockout`, so `MapBuilder` needs no change: point `terrain_path` at
## this instead and the query seam holds. That seam is the thing Phase 0 said
## to protect - one ground-height query, whoever produces the ground.
##
## **Terrain3D draws `ground`, which is terrain plus fill.** The landform source
## answers the *terrain* - the buried, pre-settlement surface that excavation
## uncovers. What the suburb rests on is that surface plus the backfill dumped
## over it, and `MapBuilder`'s grading solve is where fill thickness currently
## lives. Drawing the terrain instead of the ground puts the roads a metre in
## the air and the player underneath them, which is exactly what it did.
##
## So: `height_at` answers the landform, because that is what the grading solve
## reasons *about*; the drawn and collided surface is what the solve *produced*.
## Reading the drawn surface back into the solve would feed grading its own
## output and let the ground climb a little further every rebuild.
##
## Landform comes from a source node exposing `height_at` - `TerrainBlockout`
## today, an authored heightmap or a real DEM later. This node does not care
## which; it samples whatever it is given and writes it in one bulk import,
## which measured 6.4 ms for the board against 22.3 for a generated mesh.

## Where the shape comes from. Anything with `height_at(x, z) -> float`.
@export var landform_path: NodePath:
	set(value):
		landform_path = value
		_queue_rebuild()

## Metres of ground beyond the board on every side, so the neighbourhood does
## not end at the property line.
@export var margin: float = 120.0:
	set(value):
		margin = value
		_queue_rebuild()

## Draw the ground as shaded grey with contour lines, until it has textures.
##
## **The checkerboard is not neutral.** With no texture assets Terrain3D falls
## back to a checker, and a high-frequency pattern across a whole hillside
## cancels the shading that would otherwise read as shape - the wedge was
## invisible in a screenshot of the wedge. Grey plus contours is the
## topographic view: the same instrument the level conventions are built on,
## since the terrain takes its character from real contour sheets.
##
## Turn it off once the ground has real materials.
@export var survey_view: bool = true:
	set(value):
		survey_view = value
		_apply_survey_view()

@export var rebuild: bool = false:
	set(_value):
		rebuild = false
		_rebuild()

## Terrain3D samples one height per vertex; at spacing 1.0 a vertex is a
## terrain cell, which is the lattice the design settled on.
const VERTEX_SPACING := 1.0

## Terrain3D's region grid, in metres.
##
## **Not tunable here, which is worth recording.** An import has to start on a
## region boundary, so at 256 a board 108 x 204 with 120 m of margin - about
## 348 x 444 of actual need - is rounded out to nine regions and 768 x 768:
## twenty-seven times the board, every metre of it sampled and shaped.
##
## Smaller regions would hug the requirement, but Terrain3D ignores the
## property once its data exists; changing it means `Terrain3DData.
## change_region_size` before anything is imported. Worth doing when the
## rebuild cost matters again - it is roughly a 40% saving - and not worth it
## while the rebuild is half a second.
const REGION_SIZE := 256

## Metres over which the filled board eases back to bare terrain outside it.
const EDGE_BLEND := 24.0

## Spacing of the landform samples a rebuild takes, in metres.
##
## **The rebuild is the editor's frame budget, not a background job.** This is a
## `@tool` node, so it runs on `_ready` and on every window nudge; sampling the
## landform once per drawn metre meant 590,000 evaluations of a function that
## loops over fans, arroyos and two octaves of noise - 4.4 seconds of frozen
## editor per nudge.
##
## Sampled every few metres and interpolated between, because a fan has nothing
## to say at one-metre resolution that survives being benched anyway. The
## *built* surface is still exact: seats are read directly, so what objects sit
## on and what the player walks on are unaffected. Only the wild ground beyond
## the board is interpolated, and it is scenery.
const TERRAIN_SAMPLE := 4.0

## The layers `TerrainBlockout` used, so ground picking keeps hitting ground.
const GROUND_LAYERS := 1 | 4

## `CollisionMode.FULL_GAME`. The default is `DYNAMIC_GAME`, which builds
## shapes only within `collision_radius` of the camera - 64 m, on a board 204 m
## long, so the far end of the street has nothing to stand on and a headless
## run has nothing at all. The board is small enough to collide whole.
const COLLISION_FULL_GAME := 3

var _terrain: Node = null
var _grader: Node = null
var _board_origin := Vector2.ZERO
var _pending := false
var _rebuild_requested := false
var _builds := 0


func _ready() -> void:
	_rebuild()


func landform() -> Node:
	if landform_path.is_empty():
		return null
	return get_node_or_null(landform_path)


## The terrain at a world position - the buried surface, before backfill.
func height_at(x: float, z: float) -> float:
	var source := landform()
	if source != null and source.has_method("height_at"):
		return float(source.height_at(x, z))
	return 0.0


## The surface the player walks on: terrain plus whatever fill sits over it.
##
## Inside the board that is the grading solve, interpolated across the 12 m lot
## lattice so the ground is smooth rather than stepped at every lot line.
## Beyond the board there are no lots and no fill, so it eases back to bare
## terrain over `EDGE_BLEND` metres instead of ending at a cliff.
func ground_height_at(x: float, z: float) -> float:
	var terrain_h := height_at(x, z)
	if _grader == null or not _grader.has_method("seat_height_at_cell"):
		return terrain_h
	var cell_size := float(_grader.cell_size)
	var grid: Vector2 = _grader.grid_size
	if cell_size <= 0.0:
		return terrain_h
	# Cell centres, so a point at a centre reads that cell's seat exactly.
	var fx := (x - _board_origin.x) / cell_size - 0.5
	var fz := (z - _board_origin.y) / cell_size - 0.5
	var max_x := int(grid.x) - 1
	var max_z := int(grid.y) - 1
	var x0 := clampi(int(floorf(fx)), 0, max_x)
	var z0 := clampi(int(floorf(fz)), 0, max_z)
	var x1 := mini(x0 + 1, max_x)
	var z1 := mini(z0 + 1, max_z)
	var tx := clampf(fx - float(x0), 0.0, 1.0)
	var tz := clampf(fz - float(z0), 0.0, 1.0)
	var top := lerpf(_seat(x0, z0), _seat(x1, z0), tx)
	var bottom := lerpf(_seat(x0, z1), _seat(x1, z1), tx)
	var filled := lerpf(top, bottom, tz)

	# How far outside the board this point lies, on the worse axis.
	var out_x := maxf(_board_origin.x - x, x - (_board_origin.x + grid.x * cell_size))
	var out_z := maxf(_board_origin.y - z, z - (_board_origin.y + grid.y * cell_size))
	var outside := maxf(maxf(out_x, out_z), 0.0)
	if outside <= 0.0:
		return filled
	return lerpf(filled, terrain_h, clampf(outside / EDGE_BLEND, 0.0, 1.0))


## The drawn height at a point, using the coarse landform and exact seats.
##
## Seats are read directly rather than interpolated: they are what objects are
## placed on and what the body collides with, so an approximation there would
## put a house a few centimetres off its own ground. The landform is only ever
## the wild half of the answer, which is why it can be sampled coarsely.
func _ground_from(x: float, z: float, coarse: PackedFloat32Array,
		width: int, step: float, origin: Vector3) -> float:
	var terrain_h := _sample_coarse(x, z, coarse, width, step, origin)
	if _grader == null or not _grader.has_method("seat_height_at_cell"):
		return terrain_h
	var cell_size := float(_grader.cell_size)
	var grid: Vector2 = _grader.grid_size
	if cell_size <= 0.0:
		return terrain_h

	var out_x := maxf(_board_origin.x - x, x - (_board_origin.x + grid.x * cell_size))
	var out_z := maxf(_board_origin.y - z, z - (_board_origin.y + grid.y * cell_size))
	var outside := maxf(maxf(out_x, out_z), 0.0)
	# Well beyond the board there is no fill to blend, so the seats need not be
	# read at all - which is most of the image.
	if outside >= EDGE_BLEND:
		return terrain_h

	var fx := (x - _board_origin.x) / cell_size - 0.5
	var fz := (z - _board_origin.y) / cell_size - 0.5
	var max_x := int(grid.x) - 1
	var max_z := int(grid.y) - 1
	var x0 := clampi(int(floorf(fx)), 0, max_x)
	var z0 := clampi(int(floorf(fz)), 0, max_z)
	var x1 := mini(x0 + 1, max_x)
	var z1 := mini(z0 + 1, max_z)
	var tx := clampf(fx - float(x0), 0.0, 1.0)
	var tz := clampf(fz - float(z0), 0.0, 1.0)
	var top := lerpf(_seat(x0, z0), _seat(x1, z0), tx)
	var bottom := lerpf(_seat(x0, z1), _seat(x1, z1), tx)
	var filled := lerpf(top, bottom, tz)
	if outside <= 0.0:
		return filled
	return lerpf(filled, terrain_h, clampf(outside / EDGE_BLEND, 0.0, 1.0))


func _sample_coarse(x: float, z: float, coarse: PackedFloat32Array,
		width: int, step: float, origin: Vector3) -> float:
	var fx := (x - origin.x) / step
	var fz := (z - origin.z) / step
	var x0 := clampi(int(fx), 0, width - 2)
	var z0 := clampi(int(fz), 0, width - 2)
	var tx := clampf(fx - float(x0), 0.0, 1.0)
	var tz := clampf(fz - float(z0), 0.0, 1.0)
	var top := lerpf(coarse[z0 * width + x0], coarse[z0 * width + x0 + 1], tx)
	var bottom := lerpf(coarse[(z0 + 1) * width + x0],
		coarse[(z0 + 1) * width + x0 + 1], tx)
	return lerpf(top, bottom, tz)


func _seat(x: int, z: int) -> float:
	return float(_grader.seat_height_at_cell(Vector2i(x, z)))


## Seconds of quiet before a queued rebuild runs.
##
## **Dragging a value queues a rebuild per change, not per gesture.**
## `call_deferred` coalesces within a frame and a slider drag spans hundreds of
## them, so a rebuild that costs most of a second ran most of a second, over
## and over, for the whole drag. Waiting for the changes to stop turns that
## into one rebuild after the gesture - which is also how a designer thinks
## about it.
const REBUILD_DEBOUNCE := 0.25

## `MapBuilder` hands the terrain its grader so drawn ground follows the
## grading solve. Re-importing on every solve would be wasteful, so this only
## marks the surface stale; the next rebuild picks it up.
func set_grader(grader: Node) -> void:
	_grader = grader
	# Where the board's corner sits, asked of the same contract that places
	# every object, so the drawn ground cannot disagree with them about which
	# metre belongs to which lot.
	# Asked of `cell_world_position`, which is what actually places objects.
	# `cell_to_local` alone is not it: the builder adds a per-layer origin on
	# top, so sampling from the bare contract drew the fill offset from the
	# board it belongs to. Only Y carries the seat, so X and Z come back clean.
	if grader != null and "cell_size" in grader \
			and grader.has_method("cell_world_position"):
		var cell_size := float(grader.cell_size)
		var centre: Vector3 = grader.cell_world_position(Vector2i.ZERO, 0)
		_board_origin = Vector2(
			centre.x - cell_size * 0.5, centre.z - cell_size * 0.5)
	_queue_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree():
		return
	# **Only the editor waits.** Debouncing is for a designer dragging a value;
	# at load it delayed the rebuild that adds the fill until after the level
	# had spawned bodies onto the bare landform, and the hero came to rest 0.2 m
	# out. In game the ground has to be right before anything stands on it.
	if not Engine.is_editor_hint():
		_rebuild()
		return
	_rebuild_requested = true
	if _pending:
		return
	_pending = true
	_debounce()


## Wait for the changes to stop, then rebuild once.
func _debounce() -> void:
	while _rebuild_requested:
		_rebuild_requested = false
		var timer := get_tree().create_timer(REBUILD_DEBOUNCE)
		await timer.timeout
		if not is_inside_tree():
			_pending = false
			return
	_pending = false
	_rebuild()


func _rebuild() -> void:
	_pending = false
	if not is_inside_tree():
		return
	var source := landform()
	if source == null or not source.has_method("height_at"):
		return
	if not ClassDB.class_exists("Terrain3D"):
		push_warning("Terrain3D is not available; ground will fall back to "
			+ "the landform formula.")
		return

	if _terrain == null:
		_terrain = ClassDB.instantiate("Terrain3D")
		_terrain.name = "Terrain3D"
		_terrain.set("region_size", REGION_SIZE)
		_terrain.set("vertex_spacing", VERTEX_SPACING)
		add_child(_terrain)
	_apply_survey_view()

	# One image, one import. Terrain3D creates the regions it needs from the
	# image, which is why there is no explicit region step here.
	#
	# **The origin has to sit on a region boundary.** Regions are a fixed grid
	# of `REGION_SIZE` metres at spacing 1, and an import that starts
	# off-grid lands nowhere: `get_height` answers NaN for every position,
	# because no region covers them. The shipped demo imports at -1024 with
	# 1024 regions for exactly this reason.
	var span := _span()
	var region_m := float(REGION_SIZE) * VERTEX_SPACING
	var origin := Vector3(
		floorf(-margin / region_m) * region_m, 0.0,
		floorf(-margin / region_m) * region_m)
	var needed := maxf(span.x, span.y) + absf(origin.x)
	var regions := int(ceilf(needed / region_m))
	var size := maxi(regions, 1) * REGION_SIZE

	# The landform, sampled coarsely once and interpolated for the rest.
	var coarse_step := maxf(TERRAIN_SAMPLE, VERTEX_SPACING)
	var coarse_width := int(ceilf(float(size) / coarse_step)) + 2
	var coarse := PackedFloat32Array()
	coarse.resize(coarse_width * coarse_width)
	for iz in coarse_width:
		for ix in coarse_width:
			coarse[iz * coarse_width + ix] = height_at(
				origin.x + float(ix) * coarse_step,
				origin.z + float(iz) * coarse_step)

	# Built as a buffer rather than by `set_pixel`, which is a scripted call
	# per pixel and was most of what remained after the landform was cached.
	# `FORMAT_RF` is one float per pixel, so the array maps straight onto it.
	var pixels := PackedFloat32Array()
	pixels.resize(size * size)
	for iz in size:
		var z := origin.z + float(iz) * VERTEX_SPACING
		var row := iz * size
		for ix in size:
			pixels[row + ix] = _ground_from(
				origin.x + float(ix) * VERTEX_SPACING, z,
				coarse, coarse_width, coarse_step, origin)
	var image := Image.create_from_data(size, size, false, Image.FORMAT_RF,
		pixels.to_byte_array())

	var data: Object = _terrain.get("data")
	# **Clear before importing.** `import_images` fills regions it creates and
	# leaves regions that already exist alone, so the second import - the one
	# that adds the fill once grading reports in - silently did nothing and the
	# board kept the bare terrain it was first drawn with.
	for location in (data.call("get_region_locations") as Array).duplicate():
		data.call("remove_regionl", location)
	data.call("import_images", [image, null, null], origin, 0.0, 1.0)

	# After the heights, not before: the shapes are built from what was
	# imported, and collision configured against an empty terrain is collision
	# against nothing.
	#
	# **Off and on again, deliberately.** Setting the mode to the value it
	# already holds is a no-op, so a second import - the one that adds the fill
	# once the grading solve reports in - left the shapes built from the bare
	# terrain underneath. The board rendered at street level and collided a
	# metre down, which is the same bug in reverse.
	_terrain.set("collision_layer", GROUND_LAYERS)
	_terrain.set("collision_mode", 0)
	_terrain.set("collision_mode", COLLISION_FULL_GAME)
	_builds += 1


func _apply_survey_view() -> void:
	if _terrain == null:
		return
	var material: Object = _terrain.get("material")
	if material == null:
		return
	material.set("show_grey", survey_view)
	material.set("show_contours", survey_view)


## Board extent plus margin on both sides, in metres.
func _span() -> Vector2:
	var source := landform()
	var cell := 12.0
	var cols := 9.0
	var rows := 17.0
	if source != null:
		if "cell_size" in source:
			cell = float(source.cell_size)
		if "columns" in source:
			cols = float(source.columns)
		if "rows" in source:
			rows = float(source.rows)
	return Vector2(cols * cell + margin * 2.0, rows * cell + margin * 2.0)
