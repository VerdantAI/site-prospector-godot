@tool
class_name SurveyLayer
extends Resource

## One thing a surveyor can read off the ground.
##
## **Elevation is not the only question a site is asked.** The developer and
## eventually the player will want fertility, minerals, soil depth, water -
## Farthest Frontier's survey is exactly this, and the reason it works is that
## every layer answers the same three questions: what is the value here, how
## should it be coloured, and what does a whole site's worth of it add up to.
##
## So a layer is a resource with `sample`, a colour ramp, and a summary. The
## prospector holds a list of them, prints one HUD line each, and can draw any
## one of them as the backdrop - which is what makes "reload the image later"
## a change of index rather than a rewrite.
##
## Layers may read the landform, so a fertility that depends on slope and
## drainage is expressible rather than being noise pretending to be soil.

## Shown in the HUD.
@export var layer_name: String = "Layer"
## Appended to the mean, e.g. "%" or " m". Empty for a bare number.
@export var units: String = ""
## The band a value is normalised against for colouring and for `fraction`.
@export var low_value: float = 0.0
@export var high_value: float = 1.0
## Ends of the ramp used when this layer is the backdrop.
@export var low_colour := Color(0.35, 0.30, 0.24)
@export var high_colour := Color(0.45, 0.70, 0.35)
## Values at or above this count towards "good" lots in the summary.
@export var good_threshold: float = 0.6


## The value at a point in region metres. Override this.
##
## `region` is the landform, passed so a layer can be derived from the ground
## rather than invented beside it.
func sample(_region: Resource, _x: float, _z: float) -> float:
	return 0.0


## Where a value sits in this layer's band, 0 to 1.
func fraction(value: float) -> float:
	return clampf((value - low_value) / maxf(high_value - low_value, 0.0001),
		0.0, 1.0)


func tint(value: float) -> Color:
	return low_colour.lerp(high_colour, fraction(value))


## One HUD line for a site's worth of samples.
func summarise(values: Array) -> String:
	if values.is_empty():
		return "%s: no reading" % layer_name
	var total := 0.0
	var good := 0
	for value in values:
		total += float(value)
		if float(value) >= good_threshold:
			good += 1
	var mean := total / float(values.size())
	return "%s %.0f%s  -  %d of %d lots good" % [layer_name, mean, units,
		good, values.size()]
