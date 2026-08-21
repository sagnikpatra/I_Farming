## One daily-task template pool entry. Port-style def class, mirrors
## FestivalDef/ChandaFestivalDef's shape exactly. Looked up via
## GameData.DAILY_TASK_POOL / GameData.daily_task_def(kind).
class_name DailyTaskDef
extends RefCounted

var kind: DailyTaskKind.Kind
var display_name: String
var emoji: String
var target: int
var gem_reward: int


func _init(p_kind: DailyTaskKind.Kind, p_display_name: String, p_emoji: String, p_target: int, p_gem_reward: int) -> void:
	kind = p_kind
	display_name = p_display_name
	emoji = p_emoji
	target = p_target
	gem_reward = p_gem_reward
