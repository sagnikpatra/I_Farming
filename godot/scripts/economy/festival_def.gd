## One recurring LiveOps festival definition. Port of GameData.kt's
## `FestivalDef` data class. Looked up via GameData.festival_def(cycle_index).
class_name FestivalDef
extends RefCounted

var display_name: String
var emoji: String
var target_crop: CropType.Kind


func _init(p_display_name: String, p_emoji: String, p_target_crop: CropType.Kind) -> void:
	display_name = p_display_name
	emoji = p_emoji
	target_crop = p_target_crop
