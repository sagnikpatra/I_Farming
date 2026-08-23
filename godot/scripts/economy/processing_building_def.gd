## Processing building definition. Each building is purchased as upgradeable
## infrastructure and queues multiple recipes.
## Port of design/gdd/crop-processing-pipeline.md building rules.
class_name ProcessingBuildingDef
extends RefCounted

## Unique key for this building (e.g., "spice_grinder")
var building_key: String
## Display name (e.g., "Spice Grinder")
var display_name: String
## Purchase cost (₹)
var cost: int
## Emoji for UI
var emoji: String
## Description text
var description: String
## Maximum number of recipes in queue (typically 5)
var max_queue_size: int
## Processing speed multiplier (1.0 = normal, >1.0 = faster)
var processing_speed_multiplier: float


func _init(
	p_building_key: String,
	p_display_name: String,
	p_cost: int,
	p_emoji: String,
	p_description: String,
	p_max_queue_size: int = 5,
	p_processing_speed_multiplier: float = 1.0
) -> void:
	building_key = p_building_key
	display_name = p_display_name
	cost = p_cost
	emoji = p_emoji
	description = p_description
	max_queue_size = p_max_queue_size
	processing_speed_multiplier = p_processing_speed_multiplier
