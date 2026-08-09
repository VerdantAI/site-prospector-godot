@tool
extends Resource
class_name RegionLandform

## A whole region of ground, from which level-sized windows are cut.
##
## **The region comes first and the board is a window onto it.** Authoring a
## landform to fit one board bakes that board's size into the shape - the
## foothill ends up at some fraction of the level rather than at a place - and
## the next region along cannot be the same hillside further up. So the ground
## is defined once, in metres, over kilometres, and a level is a rectangle
## chosen from it.
##
## ## What it is modelled on
##
## Lake View Terrace and Altadena are the same landform twice: suburbs built on
## **alluvial fans at the foot of the San Gabriels**, and every feature that
## matters to this game is a consequence of that.
##
## - **The range front is abrupt.** The mountains do not ease into the valley;
##   they stop. Behind the last street the ground goes from a few per cent to
##   thirty in a hundred metres. That hard line is why the suburb has a definite
##   edge rather than fading out.
## - **Fans spread from canyon mouths.** Each canyon delivers debris to a cone
##   that spreads and flattens downslope - steep near the apex, gentle far out.
##   The profile is concave, which is why the top of a fan suburb is noticeably
##   steeper than the bottom.
## - **Fans coalesce into a bajada.** Where neighbouring fans meet they merge
##   into one continuous apron. The seam between two fans is a slight swale, and
##   it is where drainage collects.
## - **Arroyos are incised.** Rubio, Las Flores, Millard and Eaton in Altadena;
##   Big Tujunga at Lake View Terrace. These are not swales - they are cut
##   channels with banks, and a street either bridges one or stops at it. They
##   are the reason a fan suburb's grid is interrupted rather than complete.
## - **The grid bends to the fan.** Streets run down the fan and cross-streets
##   follow the contours, so the grid rotates slightly from fan to fan.
##
## Elevations are metres above the shared datum, per the one-datum rule.

## Extent of the region in metres. Kilometres, not a board.
@export var extent := Vector2(3000.0, 3000.0)

@export_group("Range front")
## Mean distance from the north edge to the foot of the mountains.
@export var front_distance: float = 500.0
## How far the foot of the range wanders north and south, in metres.
##
## **A range front is not a ruled line.** It embays where canyons have cut back
## into it and projects where a spur of harder rock has held out, and the fan
## apexes sit in the embayments because that is where the canyons are. Drawn
## straight it reads as a wall someone built, which is exactly how it looked.
@export var front_sinuosity: float = 220.0
## How far the range climbs within the region. It keeps climbing beyond it;
## this is only the part the region can see. The San Gabriel front runs roughly
## 30-45% where it is not cliffed, so this is set against the distance it has
## to climb in rather than chosen for drama.
@export var front_height: float = 260.0
## Elevation of the fan apexes, where the canyons deliver.
@export var apex_height: float = 60.0

@export_group("Fans")
## Canyon mouths along the front, as distances east from the west edge. Three
## fans is what a stretch of range front this wide actually carries.
@export var canyon_mouths: PackedFloat32Array = PackedFloat32Array(
	[520.0, 1480.0, 2360.0])
## How far a fan runs before it has spent itself.
@export var fan_reach: float = 2100.0
## Concavity of the fan profile. Above 1 is steep at the apex and flat far out,
## which is what a real fan does; 1.0 would be a cone.
@export var fan_concavity: float = 1.7

@export_group("Arroyos")
## Depth of the cut where an arroyo leaves its canyon. They shallow downslope
## as the fan spreads.
##
## **Sized to the board, not to the real thing.** This was 14 m - the depth of
## an actual barranca - and it made the region unusable: any window holding one
## broke the 12 m relief budget, so gating at the budget left only streamless
## flat ground. The bible already says it: at 1:1 metres, choose features that
## fit rather than shrinking ones that do not, and a barranca that fits a board
## is 2-4 m deep and 10-20 m wide. A 14 m cut belongs to a bigger region.
@export var arroyo_depth: float = 3.6
## Half-width of the cut. Narrow: these are channels with banks, not valleys.
@export var arroyo_width: float = 9.0
## How far the channel wanders across the fan over its length.
@export var arroyo_wander: float = 190.0

@export_group("Texture")
## Gentle undulation so the fans are not glass. Real fan surfaces carry old
## abandoned channels and low interfluves.
@export var relief_noise: float = 3.2
@export var noise_scale: float = 260.0
@export var seed_value: int = 20260808


## Ground elevation at a point in region metres, against the shared datum.
##
## North is `z = 0` and the land falls southward, matching the board convention
## where `+z` is south.
func height_at(x: float, z: float) -> float:
	var height := _fan_surface(x, z)
	height = maxf(height, _range_front(x, z))
	height += _texture(x, z)
	height -= _arroyo_cut(x, z)
	return height


## The bajada: the highest of the overlapping fans, which is what coalescing
## means. Taking the maximum rather than the sum is why the seam between two
## fans is a swale - each fan has fallen away there and neither fills it.
func _fan_surface(x: float, z: float) -> float:
	var best := 0.0
	for mouth in canyon_mouths:
		var from_mouth := Vector2(x - float(mouth), z - _front_at(float(mouth)))
		# Fans spread downslope, not uphill: north of the mouth is the canyon.
		if from_mouth.y < 0.0:
			from_mouth.y *= 3.0
		var distance := from_mouth.length()
		if distance >= fan_reach:
			continue
		var along := distance / fan_reach
		# Concave profile: steep near the apex, flattening far out.
		var surface := apex_height * (1.0 - pow(along, 1.0 / fan_concavity))
		best = maxf(best, surface)
	return best


## The mountains, which stop rather than taper. Beyond the front the ground
## climbs at a grade nothing is built on.
func _range_front(x: float, z: float) -> float:
	var foot := _front_at(x)
	if z >= foot:
		return 0.0
	var into := (foot - z) / maxf(foot, 0.001)
	return apex_height + front_height * into * into


## Where the foot of the range lies at a given easting. Canyon mouths sit in
## the embayments, so the front is pulled north at each of them.
func _front_at(x: float) -> float:
	var wander := sin(x / 620.0) * 0.6 + sin(x / 210.0 + 1.7) * 0.4
	var foot := front_distance + wander * front_sinuosity
	for mouth in canyon_mouths:
		var from_mouth := absf(x - float(mouth))
		# An embayment around each canyon, deepest at the mouth itself.
		foot -= front_sinuosity * 0.8 * exp(
			-(from_mouth * from_mouth) / (2.0 * 240.0 * 240.0))
	return maxf(foot, 80.0)


## An incised channel from each canyon mouth, wandering as it descends and
## shallowing as the fan spreads. A street bridges one of these or stops at it.
func _arroyo_cut(x: float, z: float) -> float:
	var deepest := 0.0
	for index in canyon_mouths.size():
		var mouth := float(canyon_mouths[index])
		var down := z - _front_at(mouth)
		if down < -40.0:
			continue
		var along := clampf(down / fan_reach, 0.0, 1.0)
		# Each channel wanders on its own phase so they do not run in parallel.
		var centre := mouth + sin(along * PI * 1.6 + float(index) * 2.1) \
			* arroyo_wander
		var across := absf(x - centre)
		if across > arroyo_width * 3.0:
			continue
		var profile := exp(-(across * across)
			/ (2.0 * arroyo_width * arroyo_width))
		# Shallowing downslope, as the channel loses its confinement.
		var depth := arroyo_depth * (1.0 - along * 0.72)
		deepest = maxf(deepest, depth * profile)
	return deepest


## Two octaves of value noise. Enough to break the surface without inventing
## landforms the model does not claim.
func _texture(x: float, z: float) -> float:
	var value := _noise(x / noise_scale, z / noise_scale)
	value += _noise(x / (noise_scale * 0.37), z / (noise_scale * 0.37)) * 0.4
	return value * relief_noise


func _noise(x: float, z: float) -> float:
	var x0 := floorf(x)
	var z0 := floorf(z)
	var fx := x - x0
	var fz := z - z0
	# Smoothstep, so the lattice does not show as creases.
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := _hash(int(x0), int(z0))
	var b := _hash(int(x0) + 1, int(z0))
	var c := _hash(int(x0), int(z0) + 1)
	var d := _hash(int(x0) + 1, int(z0) + 1)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


func _hash(x: int, z: int) -> float:
	var n := x * 374761393 + z * 668265263 + seed_value * 1442695040
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 32767.5 - 1.0
