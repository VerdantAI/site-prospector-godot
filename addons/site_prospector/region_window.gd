@tool
class_name RegionWindow
extends Node3D

## The level's window onto the region: an origin, an angle, and nothing else.
##
## **Prospecting proposes; a hand disposes.** `render_region_map.gd` scores
## rectangles across kilometres and reports the best few, but a score cannot
## know that the opening beat needs a pond within sight of the first house, or
## that a street should dead-end where the player will first look. So the tool's
## answer arrives here as two numbers a designer can nudge, re-render, and
## judge - rather than as a landform baked to fit.
##
## This replaces the bespoke per-level formula. A level used to carry its own
## wedge, which meant its features were fractions of *it* and the ground moved
## whenever the board did. Now the ground exists once, over kilometres, and a
## level is a rectangle cut from it at an angle.
##
## Answers `height_at(x, z)` in board-local metres, so `Terrain3DGround` and
## `MapBuilder` need no idea any of this happened.

## The ground this window looks at.
@export var region: Resource:
	set(value):
		region = value
		_notify()

## South-west corner of the window, in region metres. Straight from the
## prospector's report.
@export var window_origin := Vector2(1344.0, 864.0):
	set(value):
		window_origin = value
		_notify()

## How far the board is turned within the region. A fan suburb's grid follows
## its fan, so the level is rotated to the ground rather than the ground to the
## level.
@export_range(0.0, 360.0, 1.0) var window_angle_degrees: float = 165.0:
	set(value):
		window_angle_degrees = value
		_notify()

## Half a cell, which is what stands between corner-based board coordinates and
## the rectangle the prospector measured. Cell (0, 0) is a cell *centre*, so the
## board's edge is half a cell further out.
@export var board_local_offset := Vector2(6.0, 6.0):
	set(value):
		board_local_offset = value
		_notify()

## Board extent in metres. The rectangle the prospector scored.
@export var board_extent := Vector2(108.0, 204.0):
	set(value):
		board_extent = value
		_notify()

## Subtracted from every sample so the board sits near zero whatever its
## elevation against the shared datum. **The datum is not discarded** - this is
## a presentation offset, and `datum_elevation()` reports what was taken off.
@export var level_to_datum: bool = true:
	set(value):
		level_to_datum = value
		_notify()

var _datum := 0.0
var _datum_valid := false


func _ready() -> void:
	_resolve_datum()


## Board-local metres to region metres, and back with the ground.
func height_at(x: float, z: float) -> float:
	if region == null or not region.has_method("height_at"):
		return 0.0
	var point := to_region(x, z)
	var height := float(region.height_at(point.x, point.y))
	if not level_to_datum:
		return height
	if not _datum_valid:
		_resolve_datum()
	return height - _datum


## Where a board-local point lands in the region.
##
## **Board-local coordinates are corner-based, not centred.** Cell (0, 0) sits
## at local (0, 0) and the far cell at (96, 192), so the board occupies
## -6 .. 102 by -6 .. 198 - half a cell either side of a 108 x 204 rectangle.
##
## This previously added half the board extent, assuming local coordinates were
## centred on zero. They are not, so the window landed offset by half a board
## from the rectangle that was prospected: a site measured at 8.6 m of relief
## rendered at 24.9, because the board had slid onto the range front. The level
## was never looking at the ground the prospector scored.
func to_region(x: float, z: float) -> Vector2:
	var angle := deg_to_rad(window_angle_degrees)
	var forward := Vector2(cos(angle), sin(angle))
	var side := Vector2(-forward.y, forward.x)
	var local := Vector2(x, z) + board_local_offset
	return window_origin + side * local.x + forward * local.y


## Elevation above the shared datum that the level's zero corresponds to.
func datum_elevation() -> float:
	if not _datum_valid:
		_resolve_datum()
	return _datum


## The mean elevation under the board, so levelling does not tilt it.
func _resolve_datum() -> void:
	_datum = 0.0
	_datum_valid = true
	if region == null or not region.has_method("height_at") \
			or not level_to_datum:
		return
	var total := 0.0
	var samples := 0
	var steps := 12
	for row in steps + 1:
		for column in steps + 1:
			var local := Vector2(
				float(column) / float(steps) * board_extent.x
					- board_local_offset.x,
				float(row) / float(steps) * board_extent.y
					- board_local_offset.y)
			var point := to_region(local.x, local.y)
			total += float(region.height_at(point.x, point.y))
			samples += 1
	_datum = total / float(maxi(samples, 1))


## Nodes told to redraw when the window moves - whatever renders this ground.
##
## **Named rather than assumed.** This used to notify a hardcoded group, which
## is the one line in the whole siting toolkit that knew it was inside this
## game. Anything that draws a landform can be listed here instead, so the
## toolkit carries no opinion about a host project's group names.
@export var dependents: Array[NodePath] = []

## Group notified in addition to `dependents`, for hosts that prefer groups.
@export var dependent_group: StringName = &""


func _notify() -> void:
	_datum_valid = false
	if not is_inside_tree():
		return
	# The drawn ground and every seated object are downstream of this.
	for path in dependents:
		var node := get_node_or_null(path)
		if node != null and node.has_method("_queue_rebuild"):
			node.call_deferred("_queue_rebuild")
	if dependent_group == &"":
		return
	for node in get_tree().get_nodes_in_group(dependent_group):
		if node != self and node.has_method("_queue_rebuild"):
			node.call_deferred("_queue_rebuild")
