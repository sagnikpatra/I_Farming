## Comprehensive test suite for farmhouse progression system.
## Covers level progression, costs, unlocks, storage, processing speed,
## passive income, and offline accrual caps.
##
## design/gdd/farmhouse-progression.md, confirmed 2026-08-21.
extends GutTest


func test_level_0_is_free() -> void:
	var def := GameData.farmhouse_level_def(0)
	assert_eq(def.upgrade_cost, 0, "Level 0 should be free")
	assert_eq(def.level, 0)


func test_level_progression_costs() -> void:
	# L1: ₹2k
	assert_eq(GameData.farmhouse_level_def(1).upgrade_cost, 2_000)
	# L2: ₹5k
	assert_eq(GameData.farmhouse_level_def(2).upgrade_cost, 5_000)
	# L3: ₹12k
	assert_eq(GameData.farmhouse_level_def(3).upgrade_cost, 12_000)
	# L4: ₹25k
	assert_eq(GameData.farmhouse_level_def(4).upgrade_cost, 25_000)
	# L5: ₹50k
	assert_eq(GameData.farmhouse_level_def(5).upgrade_cost, 50_000)
	# L6: ₹75k
	assert_eq(GameData.farmhouse_level_def(6).upgrade_cost, 75_000)
	# L7: ₹112.5k
	assert_eq(GameData.farmhouse_level_def(7).upgrade_cost, 112_500)
	# L8: ₹168.75k
	assert_eq(GameData.farmhouse_level_def(8).upgrade_cost, 168_750)
	# L9: ₹253.125k
	assert_eq(GameData.farmhouse_level_def(9).upgrade_cost, 253_125)
	# L10: ₹1.5M (max)
	assert_eq(GameData.farmhouse_level_def(10).upgrade_cost, 1_500_000)


func test_max_level_is_10() -> void:
	assert_eq(GameData.farmhouse_max_level(), 10)


func test_cannot_upgrade_past_max_level() -> void:
	var economy := GameEconomy.new()
	economy.state.farmhouse_level = 10
	economy.state.coins = 999_999_999
	var result := economy.upgrade_farmhouse(0)
	assert_false(result, "Should not be able to upgrade past level 10")
	assert_eq(economy.state.farmhouse_level, 10)


func test_upgrade_farmhouse_insufficient_coins() -> void:
	var economy := GameEconomy.new()
	economy.state.farmhouse_level = 0
	economy.state.coins = 500  # Not enough for L1 (₹2k)
	var result := economy.upgrade_farmhouse(0)
	assert_false(result, "Should fail with insufficient coins")
	assert_eq(economy.state.farmhouse_level, 0)


func test_upgrade_farmhouse_succeeds() -> void:
	var economy := GameEconomy.new()
	economy.state.farmhouse_level = 0
	economy.state.coins = 2_000
	var result := economy.upgrade_farmhouse(0)
	assert_true(result, "Upgrade should succeed")
	assert_eq(economy.state.farmhouse_level, 1)
	assert_eq(economy.state.coins, 0)


func test_level_2_unlocks_spice_grinder() -> void:
	var def := GameData.farmhouse_level_def(2)
	assert_true(def.unlocks.has("spice_grinder"))


func test_level_3_unlocks_textile_loom_and_oil_press() -> void:
	var def := GameData.farmhouse_level_def(3)
	assert_true(def.unlocks.has("textile_loom"))
	assert_true(def.unlocks.has("oil_press"))


func test_level_5_unlocks_dairy_processor() -> void:
	var def := GameData.farmhouse_level_def(5)
	assert_true(def.unlocks.has("dairy_processor"))


func test_level_6_unlocks_mandi_terminal() -> void:
	var def := GameData.farmhouse_level_def(6)
	assert_true(def.unlocks.has("mandi_terminal"))


func test_level_7_unlocks_essential_oil_distillery() -> void:
	var def := GameData.farmhouse_level_def(7)
	assert_true(def.unlocks.has("essential_oil_distillery"))


func test_level_8_unlocks_aquaculture() -> void:
	var def := GameData.farmhouse_level_def(8)
	assert_true(def.unlocks.has("aquaculture"))


func test_level_9_unlocks_vertical_farm() -> void:
	var def := GameData.farmhouse_level_def(9)
	assert_true(def.unlocks.has("vertical_farm"))


func test_storage_capacity_is_the_current_levels_absolute_total() -> void:
	## Each FarmhouseLevelDef.storage_capacity is already the absolute total
	## for that tier (see _ensure_farmhouse_levels()'s catalogue comments --
	## e.g. Level 4's stored value of 2500 already IS "Level 3's 1500 + this
	## level's +1000", not a delta to sum again). get_total_storage_capacity()
	## must return just the current level's value, not a sum across levels --
	## bugfixed this session; this test originally encoded the pre-fix
	## (summing) behavior and was corrected to match.
	var economy := GameEconomy.new()
	# Level 0: 1000
	assert_eq(economy.get_total_storage_capacity(), 1000)

	economy.state.farmhouse_level = 1
	# Level 1: 1500 (not 1000+1500)
	assert_eq(economy.get_total_storage_capacity(), 1500)

	economy.state.farmhouse_level = 4
	# Level 4: 2500 (not the sum of levels 0-4)
	assert_eq(economy.get_total_storage_capacity(), 2500)


func test_storage_level_1_adds_500() -> void:
	var def1 := GameData.farmhouse_level_def(0)
	var def2 := GameData.farmhouse_level_def(1)
	assert_eq(def2.storage_capacity - def1.storage_capacity, 500)


func test_storage_level_4_adds_1000() -> void:
	var def4 := GameData.farmhouse_level_def(4)
	assert_eq(def4.storage_capacity, 2500)


func test_storage_level_8_adds_2000() -> void:
	var def8 := GameData.farmhouse_level_def(8)
	assert_eq(def8.storage_capacity, 4500)


func test_storage_level_10_adds_3000() -> void:
	var def10 := GameData.farmhouse_level_def(10)
	assert_eq(def10.storage_capacity, 7500)


func test_processing_speed_level_3_is_1_1x() -> void:
	var def := GameData.farmhouse_level_def(3)
	assert_eq(def.growth_speed_bonus_percent, 10.0)


func test_processing_speed_level_5_is_1_2x() -> void:
	var def := GameData.farmhouse_level_def(5)
	assert_eq(def.growth_speed_bonus_percent, 20.0)


func test_processing_speed_level_9_is_1_35x() -> void:
	var def := GameData.farmhouse_level_def(9)
	assert_eq(def.growth_speed_bonus_percent, 35.0)


func test_get_processing_speed_multiplier() -> void:
	var economy := GameEconomy.new()

	# Level 0: no bonus
	economy.state.farmhouse_level = 0
	assert_almost_eq(economy.get_processing_speed_multiplier(), 1.0, 0.01)

	# Level 3: 10% bonus = 0.9x speed
	economy.state.farmhouse_level = 3
	assert_almost_eq(economy.get_processing_speed_multiplier(), 0.9, 0.01)

	# Level 5: 20% bonus = 0.8x speed
	economy.state.farmhouse_level = 5
	assert_almost_eq(economy.get_processing_speed_multiplier(), 0.8, 0.01)


func test_passive_income_level_5_is_100_per_hour() -> void:
	var def := GameData.farmhouse_level_def(5)
	assert_eq(def.passive_income_per_hour, 100)


func test_passive_income_level_6_is_150_per_hour() -> void:
	var def := GameData.farmhouse_level_def(6)
	assert_eq(def.passive_income_per_hour, 150)


func test_passive_income_level_10_is_500_per_hour() -> void:
	var def := GameData.farmhouse_level_def(10)
	assert_eq(def.passive_income_per_hour, 500)


func test_resolve_passive_income_first_call_initializes() -> void:
	var economy := GameEconomy.new()
	economy.state.farmhouse_level = 5
	var now := 1000

	var coins_added := economy.resolve_passive_income(now)
	assert_eq(coins_added, 0, "First resolution should return 0")
	assert_eq(economy.state.passive_income_last_resolution_epoch_ms, now)


func test_resolve_growth_completions_now_also_accrues_passive_income() -> void:
	## resolve_passive_income() existed but was never called from anywhere
	## (see production/session-state/active.md's 2026-08-23 entry) until it
	## was wired into resolve_growth_completions() -- the tick every real
	## playthrough already calls. This is the integration check for that
	## wiring, not just the isolated function above.
	var economy := GameEconomy.new()
	economy.state.farmhouse_level = 5
	economy.resolve_growth_completions(0)  # first call: initializes the clock
	economy.resolve_growth_completions(3_600_000)  # 1 hour later
	assert_eq(economy.state.pending_passive_income, 100)


func test_resolve_passive_income_1_hour_earns_100() -> void:
	var economy := GameEconomy.new()
	economy.state.farmhouse_level = 5
	var start_time := 0
	var one_hour_later := 3_600_000  # 1 hour in ms

	# First call: initialize
	economy.resolve_passive_income(start_time)

	# Second call: 1 hour later
	var coins_added := economy.resolve_passive_income(one_hour_later)
	assert_eq(coins_added, 100, "1 hour at level 5 (100/hr) should earn 100")
	assert_eq(economy.state.pending_passive_income, 100)


func test_resolve_passive_income_12_hours_soft_cap() -> void:
	var economy := GameEconomy.new()
	economy.state.farmhouse_level = 5
	var start_time := 0
	var offline_for_24_hours := 24 * 3_600_000  # 24 hours in ms

	# First call: initialize
	economy.resolve_passive_income(start_time)

	# Second call: 24 hours later (should be capped at 12)
	var coins_added := economy.resolve_passive_income(offline_for_24_hours)
	var expected := 100 * 12  # 12 hours capped
	assert_eq(coins_added, expected, "Offline for 24h should cap at 12h = 1200 coins")


func test_resolve_passive_income_no_income_at_level_0() -> void:
	var economy := GameEconomy.new()
	economy.state.farmhouse_level = 0
	var start_time := 0
	var one_hour_later := 3_600_000

	economy.resolve_passive_income(start_time)
	var coins_added := economy.resolve_passive_income(one_hour_later)
	assert_eq(coins_added, 0, "Level 0 should not generate passive income")


func test_collect_pending_passive_income() -> void:
	var economy := GameEconomy.new()
	economy.state.pending_passive_income = 500
	economy.state.coins = 100

	var collected := economy.collect_pending_passive_income()
	assert_eq(collected, 500)
	assert_eq(economy.state.coins, 600)
	assert_eq(economy.state.pending_passive_income, 0)


func test_collect_pending_passive_income_empty() -> void:
	var economy := GameEconomy.new()
	economy.state.pending_passive_income = 0
	economy.state.coins = 100

	var collected := economy.collect_pending_passive_income()
	assert_eq(collected, 0)
	assert_eq(economy.state.coins, 100)


func test_get_farmhouse_level_def() -> void:
	var economy := GameEconomy.new()
	economy.state.farmhouse_level = 5

	var def := economy.get_farmhouse_level_def()
	assert_eq(def.level, 5)
	assert_eq(def.display_name, "Upgraded Haveli")


func test_level_0_no_unlocks() -> void:
	var def := GameData.farmhouse_level_def(0)
	assert_true(def.unlocks.is_empty())


func test_level_1_no_unlocks() -> void:
	var def := GameData.farmhouse_level_def(1)
	assert_true(def.unlocks.is_empty())


func test_level_4_no_unlocks() -> void:
	var def := GameData.farmhouse_level_def(4)
	assert_true(def.unlocks.is_empty())


func test_upgrade_sequence_scenario() -> void:
	var economy := GameEconomy.new()
	economy.state.coins = 2_000 + 5_000 + 12_000  # Enough for L0->L1->L2->L3

	# Upgrade to L1
	var result1 := economy.upgrade_farmhouse(0)
	assert_true(result1)
	assert_eq(economy.state.farmhouse_level, 1)

	# Upgrade to L2 (unlocks spice_grinder)
	var result2 := economy.upgrade_farmhouse(0)
	assert_true(result2)
	assert_eq(economy.state.farmhouse_level, 2)
	var def2 := economy.get_farmhouse_level_def()
	assert_true(def2.unlocks.has("spice_grinder"))

	# Upgrade to L3
	var result3 := economy.upgrade_farmhouse(0)
	assert_true(result3)
	assert_eq(economy.state.farmhouse_level, 3)


func test_passive_income_accumulates_over_multiple_resolutions() -> void:
	var economy := GameEconomy.new()
	economy.state.farmhouse_level = 6  # 150/hour
	var start_time := 0
	var one_hour := 3_600_000

	economy.resolve_passive_income(start_time)
	economy.resolve_passive_income(one_hour)  # +150
	assert_eq(economy.state.pending_passive_income, 150)

	economy.resolve_passive_income(one_hour + one_hour)  # +150 more
	assert_eq(economy.state.pending_passive_income, 300)


func test_passive_income_with_fractional_hours() -> void:
	var economy := GameEconomy.new()
	economy.state.farmhouse_level = 5  # 100/hour
	var start_time := 0
	var half_hour := 1_800_000  # 30 minutes

	economy.resolve_passive_income(start_time)
	var coins_added := economy.resolve_passive_income(half_hour)
	assert_eq(coins_added, 50, "30 minutes at 100/hour should be 50 coins")
