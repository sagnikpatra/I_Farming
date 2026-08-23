## Definition for a hireable villager. Pool of available workers the player can
## hire to automate farm tasks. Extends the EPIC-M7 worker assignment system
## with a hiring economy: workers cost money to hire, consume food daily, and
## require housing capacity (tied to farmhouse progression).
class_name VillagerHireDef
extends RefCounted

var villager_id: String
var name: String
var skill_level: int  # 1-3, affects future production bonuses
var hire_cost: int  # One-time ₹ cost to hire
var monthly_salary: int  # Monthly wage (daily = monthly / 30)
var food_consumption_per_day: int  # Units of wheat/food consumed daily


func _init(
	p_villager_id: String,
	p_name: String,
	p_skill_level: int,
	p_hire_cost: int,
	p_monthly_salary: int,
	p_food_consumption_per_day: int
) -> void:
	villager_id = p_villager_id
	name = p_name
	skill_level = p_skill_level
	hire_cost = p_hire_cost
	monthly_salary = p_monthly_salary
	food_consumption_per_day = p_food_consumption_per_day


## Daily salary derived from monthly (monthly / 30).
func daily_salary() -> int:
	return roundi(float(monthly_salary) / 30.0)
