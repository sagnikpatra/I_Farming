## One row of the Farmhouse tier table. Port of GameData.kt's
## `FarmhouseLevel` data class. Looked up via GameData.farmhouse_level_def(level).
class_name FarmhouseLevelDef
extends RefCounted

var level: int
var display_name: String
var emoji: String
var upgrade_cost: int
## Max total harvested-but-unsold crop units the player can hold at once.
var storage_capacity: int
## % reduction applied to every crop's effective grow time, farm-wide.
var growth_speed_bonus_percent: int
## % bonus applied to every sale, farm-wide.
var sell_price_bonus_percent: int


func _init(
	p_level: int,
	p_display_name: String,
	p_emoji: String,
	p_upgrade_cost: int,
	p_storage_capacity: int,
	p_growth_speed_bonus_percent: int,
	p_sell_price_bonus_percent: int,
) -> void:
	level = p_level
	display_name = p_display_name
	emoji = p_emoji
	upgrade_cost = p_upgrade_cost
	storage_capacity = p_storage_capacity
	growth_speed_bonus_percent = p_growth_speed_bonus_percent
	sell_price_bonus_percent = p_sell_price_bonus_percent
