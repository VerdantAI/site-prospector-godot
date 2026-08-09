@tool
class_name FertilityLayer
extends SurveyLayer

## How well anything grows here, derived from the ground rather than sprinkled
## over it.
##
## **The level is called Gravel Sands, and that is a statement about soil.** An
## alluvial fan sorts its material by distance: coarse gravel and cobbles near
## the canyon mouth where the water still had energy, fines and silt far out
## where it slowed. So fertility rises downslope, and rises again in hollows,
## where fines collect and water lingers. Steep ground keeps neither.
##
## That makes soil a consequence of the same landform everything else reads,
## which is why the good farmland ends up where the old channels ran - and why
## recovering a buried drainage recovers the ground worth farming.

## Fertility on the gentlest, lowest ground, before anything is taken away.
@export var best: float = 82.0
## Taken off for being high on the fan, where the deposit is coarse.
@export var upslope_penalty: float = 46.0
## Added in hollows, where fines and moisture collect.
@export var hollow_bonus: float = 22.0
## Taken off per unit of grade. Steep ground sheds its own soil.
@export var slope_penalty: float = 180.0
## How far around a point is sampled to judge hollow or shoulder, in metres.
@export var neighbourhood: float = 24.0


func _init() -> void:
	layer_name = "fertility"
	units = "%"
	low_value = 0.0
	high_value = 100.0
	low_colour = Color(0.62, 0.52, 0.36)
	high_colour = Color(0.30, 0.58, 0.26)
	good_threshold = 55.0


func sample(region: Resource, x: float, z: float) -> float:
	if region == null or not region.has_method("height_at"):
		return 0.0
	var here := float(region.height_at(x, z))
	var east := float(region.height_at(x + neighbourhood, z))
	var west := float(region.height_at(x - neighbourhood, z))
	var south := float(region.height_at(x, z + neighbourhood))
	var north := float(region.height_at(x, z - neighbourhood))

	var grade := maxf(absf(east - west), absf(south - north)) \
		/ (neighbourhood * 2.0)
	# Below its surroundings means fines and water collect here.
	var hollow := ((east + west + south + north) * 0.25) - here

	# Height on the fan stands in for distance from the canyon mouth, which is
	# what actually sorts the material.
	var extent: Vector2 = region.get("extent") if "extent" in region \
		else Vector2(3000.0, 3000.0)
	var ceiling := maxf(float(region.get("apex_height")) \
		if "apex_height" in region else 60.0, 1.0)
	var upslope := clampf(here / ceiling, 0.0, 1.0)

	var value := best - upslope_penalty * upslope \
		+ hollow_bonus * clampf(hollow, -1.0, 2.0) \
		- slope_penalty * grade
	return clampf(value, 0.0, 100.0)
