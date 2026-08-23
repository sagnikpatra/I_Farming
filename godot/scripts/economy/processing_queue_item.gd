## A single item in a processing building's queue. Tracks when a recipe was
## started and when it will complete. The first item in a building's queue is
## the "active" recipe; subsequent items are "pending."
class_name ProcessingQueueItem
extends Resource

## Recipe key being processed (e.g., "turmeric_to_spice")
@export var recipe_key: String = ""
## When this recipe started processing (epoch ms)
@export var started_at_epoch_ms: int = 0
## When this recipe will complete (epoch ms)
@export var completion_at_epoch_ms: int = 0
## Output item name (e.g., "Premium Spice Jar")
@export var output_item_name: String = ""


func _init(
	p_recipe_key: String = "",
	p_started_at: int = 0,
	p_completion_at: int = 0,
	p_output_item: String = ""
) -> void:
	recipe_key = p_recipe_key
	started_at_epoch_ms = p_started_at
	completion_at_epoch_ms = p_completion_at
	output_item_name = p_output_item
