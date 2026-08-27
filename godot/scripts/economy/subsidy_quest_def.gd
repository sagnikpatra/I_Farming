## Data class for government subsidy quest definitions.
## Mirrors design/gdd/government-subsidy-quests.md.
class_name SubsidyQuestDef
extends RefCounted

## Unique identifier (e.g., "harvest_50_paddy")
var quest_key: String
## Display name shown to player (e.g., "Monsoon Harvest Initiative")
var display_name: String
## Description text explaining the quest goal
var description: String
## Type of reward: "building_discount", "building_unlock", "processing_speed"
var reward_type: String
## Reward value: discount percentage (e.g., 50 for 50% off) or building key
var reward_value: Variant
## Number of harvests required to complete
var required_harvests: int
## Array of CropType.Kind values (empty = any crops count)
var required_crops: Array[int]
## Time limit in real days (-1 = unlimited)
var time_limit_days: int


func _init(
	p_quest_key: String,
	p_display_name: String,
	p_description: String,
	p_reward_type: String,
	p_reward_value: Variant,
	p_required_harvests: int,
	p_required_crops: Array[int] = [],
	p_time_limit_days: int = -1
) -> void:
	quest_key = p_quest_key
	display_name = p_display_name
	description = p_description
	reward_type = p_reward_type
	reward_value = p_reward_value
	required_harvests = p_required_harvests
	required_crops = p_required_crops
	time_limit_days = p_time_limit_days
