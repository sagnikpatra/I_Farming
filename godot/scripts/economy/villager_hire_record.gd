## Record of a hired villager in the player's farm. Persisted in GameState as
## part of the hired_villagers array. Tracks when they were hired, what they're
## assigned to, and their morale (future feature for productivity bonuses).
class_name VillagerHireRecord
extends Resource

@export var villager_id: String = ""
@export var hired_at_epoch_ms: int = 0
@export var assigned_plot_id: int = -1  # -1 = unassigned
@export var morale: int = 100  # 0-100, affects productivity (future feature)
@export var next_salary_due_epoch_ms: int = 0  # When the next daily salary is due


func _init(
	p_villager_id: String = "",
	p_hired_at_epoch_ms: int = 0,
	p_assigned_plot_id: int = -1,
	p_morale: int = 100,
	p_next_salary_due_epoch_ms: int = 0
) -> void:
	villager_id = p_villager_id
	hired_at_epoch_ms = p_hired_at_epoch_ms
	assigned_plot_id = p_assigned_plot_id
	morale = p_morale
	next_salary_due_epoch_ms = p_next_salary_due_epoch_ms
