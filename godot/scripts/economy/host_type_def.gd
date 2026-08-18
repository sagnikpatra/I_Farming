## Static per-host-type data. See crop_def.gd's header comment -- same pattern.
class_name HostTypeDef
extends RefCounted

var display_name: String
var emoji: String
var cost: int


func _init(p_display_name: String, p_emoji: String, p_cost: int) -> void:
	display_name = p_display_name
	emoji = p_emoji
	cost = p_cost
