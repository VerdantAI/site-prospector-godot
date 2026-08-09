@tool
class_name ChosenSite
extends Resource

## A site somebody picked, on its way from the map to a level.
##
## The map and the level are different scenes, so the choice cannot be handed
## over directly - only one is open at a time. This is the note left on the
## table between them: the prospector writes it, the Level Authoring dock reads
## it and applies it to the level's `RegionWindow`.
##
## It carries the reading as well as the position, so the dock can say what was
## chosen rather than just moving numbers silently.

@export var origin := Vector2.ZERO
@export var angle_degrees: float = 0.0
@export var board_lots := Vector2i(9, 17)
@export var relief: float = 0.0
@export var buildable: float = 0.0
@export var drainage_lots: int = 0
@export var verdict: String = ""


func describe() -> String:
	return "(%.0f, %.0f) at %.0f deg - %.0f%% buildable, %d drainage, %s" % [
		origin.x, origin.y, angle_degrees, buildable * 100.0, drainage_lots,
		verdict]
