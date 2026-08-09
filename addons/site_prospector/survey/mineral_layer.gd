@tool
class_name MineralLayer
extends SurveyLayer

## A mineral in the ground, in patches rather than everywhere.
##
## **Deposits are places, not a texture.** A layer that returns smooth noise
## makes every site equally worth digging, which is the opposite of a reason to
## prospect. This returns near-zero across most of the region and rises inside
## a handful of bodies, so finding one is an event and a site either has it or
## does not.
##
## Reusable by construction: iron, clay, sand and gravel are the same resource
## with a different seed, richness and count.

## How rich a body is at its centre.
@export var richness: float = 100.0
## Radius of a body, in metres.
@export var body_radius: float = 260.0
## How many bodies the region carries.
@export var body_count: int = 7
## Changes where the bodies are without changing anything else.
@export var seed_value: int = 4711
## Bodies are drawn inside this, matching the region.
@export var extent := Vector2(3000.0, 3000.0)

var _bodies: PackedVector2Array


func _init() -> void:
	layer_name = "mineral"
	units = ""
	low_value = 0.0
	high_value = 100.0
	low_colour = Color(0.34, 0.32, 0.30)
	high_colour = Color(0.85, 0.62, 0.30)
	good_threshold = 25.0


func sample(_region: Resource, x: float, z: float) -> float:
	if _bodies.is_empty():
		_place_bodies()
	var best := 0.0
	for centre in _bodies:
		var distance := Vector2(x, z).distance_to(centre)
		if distance >= body_radius:
			continue
		var falloff := 1.0 - distance / body_radius
		best = maxf(best, richness * falloff * falloff)
	return best


## Deterministic from the seed, so a region's deposits do not move between
## runs - a prospector who found iron yesterday finds it there today.
func _place_bodies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_bodies = PackedVector2Array()
	for _index in maxi(body_count, 0):
		_bodies.append(Vector2(rng.randf() * extent.x, rng.randf() * extent.y))
