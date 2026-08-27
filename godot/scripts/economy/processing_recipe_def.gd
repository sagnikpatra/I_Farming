## Processing recipe definition. Each recipe transforms input crops into a
## single output product with a value multiplier (2-5x) over a fixed duration.
## Port of the design/gdd/crop-processing-pipeline.md recipe rules.
class_name ProcessingRecipeDef
extends RefCounted

## Unique key for this recipe (e.g., "turmeric_to_spice")
var recipe_key: String
## Display name (e.g., "Premium Spice Jar")
var display_name: String
## Input crop type (CropType.Kind ordinal)
var input_crop: int
## How many units of input_crop are consumed per cycle
var input_quantity: int
## Display name of the output item (stored in inventory as this string)
var output_item_name: String
## Base sell price of the output item (₹)
var base_output_price: int
## How long the recipe takes to process (seconds)
var duration_seconds: int
## Required building key (e.g., "spice_grinder")
var required_building: String
## Unlock requirement (e.g., "fan_pad"), or empty string if always available
var unlock_requirement: String


func _init(
	p_recipe_key: String,
	p_display_name: String,
	p_input_crop: int,
	p_input_quantity: int,
	p_output_item_name: String,
	p_base_output_price: int,
	p_duration_seconds: int,
	p_required_building: String,
	p_unlock_requirement: String = ""
) -> void:
	recipe_key = p_recipe_key
	display_name = p_display_name
	input_crop = p_input_crop
	input_quantity = p_input_quantity
	output_item_name = p_output_item_name
	base_output_price = p_base_output_price
	duration_seconds = p_duration_seconds
	required_building = p_required_building
	unlock_requirement = p_unlock_requirement
