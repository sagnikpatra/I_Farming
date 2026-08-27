## Immutable data class for a farmhouse progression level.
## Defines cost, display name, unlocks, and passive income/bonuses at that level.
##
## Maps to design/gdd/farmhouse-progression.md -- all values validated against
## that GDD's Level Details (§3) table. Unlocks are crop processor names
## (e.g., "dairy_processor", "textile_loom") -- validated upstream in GameData
## when the complete farmhouse_levels catalogue is built.
class_name FarmhouseLevelDef
extends RefCounted

@export var level: int
@export var display_name: String
@export var emoji: String
@export var upgrade_cost: int
@export var storage_capacity: int
@export var worker_slots_added: int
@export var growth_speed_bonus_percent: float
@export var passive_income_per_hour: int
@export var sell_price_bonus_percent: float
@export var unlocks: Array[String]


func _init(
	p_level: int,
	p_display_name: String,
	p_emoji: String,
	p_upgrade_cost: int,
	p_storage_capacity: int,
	p_worker_slots_added: int,
	p_growth_speed_bonus_percent: float = 0.0,
	p_passive_income_per_hour: int = 0,
	p_sell_price_bonus_percent: float = 0.0,
	p_unlocks: Array[String] = []
) -> void:
	level = p_level
	display_name = p_display_name
	emoji = p_emoji
	upgrade_cost = p_upgrade_cost
	storage_capacity = p_storage_capacity
	worker_slots_added = p_worker_slots_added
	growth_speed_bonus_percent = p_growth_speed_bonus_percent
	passive_income_per_hour = p_passive_income_per_hour
	sell_price_bonus_percent = p_sell_price_bonus_percent
	unlocks = p_unlocks
