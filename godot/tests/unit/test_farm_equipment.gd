## design/gdd/farm-equipment.md. Covers:
## - GameEconomy.land_expansions_bought() (the tier-gate input)
## - GameEconomy.buy_equipment(): affordability, tier-lock, already-owned
##   no-op, and the successful-purchase state change
## - EquipmentShop.build_row_data(): tier grouping/ordering and per-row
##   owned/locked/affordable state
extends GutTest

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 10_000_000


## Appends `count` extra Open Field plots directly rather than paying for
## real land expansions -- faster, and keeps this file's tests about
## buy_equipment()'s own gating logic, not buy_land_expansion()'s (covered
## separately in test_game_economy.gd).
func _add_expansions(count: int) -> void:
	for i in range(count):
		eco.state.plots.append(Plot.new(1000 + i))


# --- land_expansions_bought() ----------------------------------------------------

func test_land_expansions_bought_is_zero_on_a_fresh_state() -> void:
	assert_eq(eco.land_expansions_bought(), 0)


func test_land_expansions_bought_counts_open_field_plots_beyond_starting() -> void:
	_add_expansions(3)
	assert_eq(eco.land_expansions_bought(), 3)


# --- buy_equipment(): tier 0 (Basic/Common), no expansions needed --------------

func test_buy_equipment_basic_tier_succeeds_with_no_expansions() -> void:
	assert_eq(FarmEquipment.tier_unlock_expansions(FarmEquipment.equipment_tier(FarmEquipment.Kind.TWINE)), 0)
	eco.buy_equipment(FarmEquipment.Kind.TWINE)
	assert_true(eco.state.owned_equipment.has(FarmEquipment.Kind.TWINE))


func test_buy_equipment_deducts_the_exact_cost() -> void:
	var cost := FarmEquipment.equipment_cost(FarmEquipment.Kind.AXE)
	eco.buy_equipment(FarmEquipment.Kind.AXE)
	assert_eq(eco.state.coins, 10_000_000 - cost)


func test_buy_equipment_unaffordable_does_not_deduct_or_grant() -> void:
	eco.state.coins = 50  # Below even the cheapest (Twine, ₹100)
	eco.buy_equipment(FarmEquipment.Kind.TWINE)
	assert_false(eco.state.owned_equipment.has(FarmEquipment.Kind.TWINE))
	assert_eq(eco.state.coins, 50)


func test_buy_equipment_already_owned_is_a_no_op_second_time() -> void:
	eco.buy_equipment(FarmEquipment.Kind.TWINE)
	var coins_after_first_buy := eco.state.coins
	eco.buy_equipment(FarmEquipment.Kind.TWINE)
	assert_eq(eco.state.coins, coins_after_first_buy)  # Not charged twice
	assert_eq(eco.state.owned_equipment.count(FarmEquipment.Kind.TWINE), 1)  # Not duplicated


# --- buy_equipment(): higher tiers require land expansions ---------------------

func test_buy_equipment_locked_tier_does_not_charge_even_if_affordable() -> void:
	# HAND_PUMP is Standard tier, unlocks at 2 expansions -- 0 expansions here.
	assert_eq(FarmEquipment.equipment_tier(FarmEquipment.Kind.HAND_PUMP), FarmEquipment.Tier.STANDARD)
	assert_eq(FarmEquipment.tier_unlock_expansions(FarmEquipment.Tier.STANDARD), 2)
	eco.buy_equipment(FarmEquipment.Kind.HAND_PUMP)
	assert_false(eco.state.owned_equipment.has(FarmEquipment.Kind.HAND_PUMP))
	assert_eq(eco.state.coins, 10_000_000)  # Untouched -- locked, not just unaffordable


func test_buy_equipment_succeeds_once_enough_expansions_are_bought() -> void:
	_add_expansions(2)
	eco.buy_equipment(FarmEquipment.Kind.HAND_PUMP)
	assert_true(eco.state.owned_equipment.has(FarmEquipment.Kind.HAND_PUMP))


func test_buy_equipment_luxury_tier_needs_eleven_expansions() -> void:
	assert_eq(FarmEquipment.tier_unlock_expansions(FarmEquipment.Tier.LUXURY), 11)
	_add_expansions(10)
	eco.buy_equipment(FarmEquipment.Kind.SOLAR_PANEL_SYSTEM)
	assert_false(eco.state.owned_equipment.has(FarmEquipment.Kind.SOLAR_PANEL_SYSTEM))
	_add_expansions(1)  # Now at 11
	eco.buy_equipment(FarmEquipment.Kind.SOLAR_PANEL_SYSTEM)
	assert_true(eco.state.owned_equipment.has(FarmEquipment.Kind.SOLAR_PANEL_SYSTEM))


# --- EquipmentShop.build_row_data() ---------------------------------------------

func test_build_row_data_starts_with_the_basic_tier_header() -> void:
	var rows := EquipmentShop.build_row_data(10_000_000, [], 0)
	assert_eq(rows[0]["row_type"], "tier_header")
	assert_eq(rows[0]["tier"], FarmEquipment.Tier.BASIC)
	assert_false(rows[0]["locked"])


func test_build_row_data_ends_with_the_luxury_tier() -> void:
	var rows := EquipmentShop.build_row_data(10_000_000, [], 0)
	var last_item_row = rows[-1]
	assert_eq(last_item_row["row_type"], "item")
	assert_eq(last_item_row["tier"], FarmEquipment.Tier.LUXURY)


func test_build_row_data_every_item_row_matches_all_equipment_count() -> void:
	var rows := EquipmentShop.build_row_data(10_000_000, [], 0)
	var item_rows: Array = rows.filter(func(r): return r["row_type"] == "item")
	assert_eq(item_rows.size(), FarmEquipment.all_equipment().size())


func test_build_row_data_luxury_tier_locked_at_zero_expansions() -> void:
	var rows := EquipmentShop.build_row_data(10_000_000, [], 0)
	var luxury_header = rows.filter(func(r): return r["row_type"] == "tier_header" and r["tier"] == FarmEquipment.Tier.LUXURY)[0]
	assert_true(luxury_header["locked"])
	assert_eq(luxury_header["expansions_remaining"], 11)


func test_build_row_data_owned_item_is_flagged_owned() -> void:
	var rows := EquipmentShop.build_row_data(10_000_000, [FarmEquipment.Kind.TWINE], 0)
	var twine_row = rows.filter(func(r): return r["row_type"] == "item" and r["kind"] == FarmEquipment.Kind.TWINE)[0]
	assert_true(twine_row["owned"])


func test_build_row_data_zero_coins_marks_every_item_unaffordable() -> void:
	var rows := EquipmentShop.build_row_data(0, [], 13)  # Fully expanded, still broke
	for row in rows:
		if row["row_type"] == "item":
			assert_false(row["affordable"])
