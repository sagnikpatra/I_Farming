## Covers mandi-trading.md's formula table: demand swing (shared with
## GameData, tested in test_game_data.gd), grade-A bonus, glut decay/accrual,
## price multiplier clamp, forecast, and combined sell value.
extends GutTest

const NOW_QUIET: int = 10_000_000

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000
	eco.buy_mandi()


func test_mandi_and_terminal_unlock_costs() -> void:
	assert_eq(GameData.MANDI_UNLOCK_COST, 3_000)
	assert_eq(GameData.MANDI_TERMINAL_COST, 25_000)
	assert_true(eco.state.has_mandi)
	assert_false(eco.state.has_mandi_terminal)
	eco.buy_mandi_terminal()
	assert_true(eco.state.has_mandi_terminal)


func test_selling_without_mandi_is_a_noop() -> void:
	var fresh := GameEconomy.new()
	fresh.state.inventory[CropType.Kind.WHEAT] = CropStock.new(10, 0)
	fresh.sell_to_mandi(CropType.Kind.WHEAT, NOW_QUIET)
	assert_true(fresh.state.inventory.has(CropType.Kind.WHEAT))  # unchanged, not sold


func test_selling_zero_stock_is_a_noop() -> void:
	var coins_before := eco.state.coins
	eco.sell_to_mandi(CropType.Kind.WHEAT, NOW_QUIET)
	assert_eq(eco.state.coins, coins_before)


func test_grade_a_bonus_only_for_protected_cultivation_crops() -> void:
	# Open-field crop: no grade bonus contribution (price multiplier bounded
	# only by demand+glut). Protected crop: +12%. Isolate the effect by
	# forcing glut to zero and reading the multiplier at a cycle where we
	# independently know the demand swing.
	var cycle_index: int = NOW_QUIET / GameData.MANDI_CYCLE_MS
	var wheat_demand := GameData.demand_modifier_percent(CropType.Kind.WHEAT, cycle_index)
	var capsicum_demand := GameData.demand_modifier_percent(CropType.Kind.CAPSICUM, cycle_index)

	var wheat_mult := eco.mandi_price_multiplier(CropType.Kind.WHEAT, NOW_QUIET)
	var capsicum_mult := eco.mandi_price_multiplier(CropType.Kind.CAPSICUM, NOW_QUIET)

	var expected_wheat := clampf(1.0 + wheat_demand / 100.0, GameData.MANDI_MIN_MULTIPLIER, GameData.MANDI_MAX_MULTIPLIER)
	var expected_capsicum := clampf(
		1.0 + capsicum_demand / 100.0 + GameData.MANDI_GRADE_A_BONUS_PERCENT / 100.0,
		GameData.MANDI_MIN_MULTIPLIER,
		GameData.MANDI_MAX_MULTIPLIER
	)
	assert_almost_eq(wheat_mult, expected_wheat, 0.0001)
	assert_almost_eq(capsicum_mult, expected_capsicum, 0.0001)


func test_glut_accrues_on_sale_and_decays_over_time() -> void:
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(100, 0)
	eco.sell_to_mandi(CropType.Kind.WHEAT, NOW_QUIET)
	var glut: MandiGlut = eco.state.mandi_glut[CropType.Kind.WHEAT]
	# 100 units * MANDI_GLUT_PER_UNIT (0.02) = 2.0 (no prior glut to decay-in).
	assert_almost_eq(glut.value, 2.0, 0.0001)

	# ~3 hours later, glut should have roughly halved (decay rate ln(2)/3 ~= 0.231).
	var three_hours_later := NOW_QUIET + 3 * 60 * 60 * 1000
	var decayed := eco.current_glut(CropType.Kind.WHEAT, three_hours_later)
	assert_almost_eq(decayed, 1.0, 0.05)


func test_glut_snaps_to_zero_below_threshold() -> void:
	eco.state.mandi_glut[CropType.Kind.WHEAT] = MandiGlut.new(0.0005, NOW_QUIET)
	# Even at the same instant (no elapsed decay), a stored value already
	# below 0.001 must read as exactly 0.0, not linger as residue.
	assert_eq(eco.current_glut(CropType.Kind.WHEAT, NOW_QUIET), 0.0)


func test_price_multiplier_always_clamped_to_band() -> void:
	# Force an extreme glut far beyond what demand+grade could ever offset,
	# and confirm the multiplier never drops below the floor.
	eco.state.mandi_glut[CropType.Kind.WHEAT] = MandiGlut.new(100.0, NOW_QUIET)
	var mult := eco.mandi_price_multiplier(CropType.Kind.WHEAT, NOW_QUIET)
	assert_eq(mult, GameData.MANDI_MIN_MULTIPLIER)


func test_forecast_peeks_next_cycle_demand() -> void:
	var next_cycle_index: int = NOW_QUIET / GameData.MANDI_CYCLE_MS + 1
	var expected := GameData.demand_modifier_percent(CropType.Kind.WHEAT, next_cycle_index)
	assert_eq(eco.mandi_forecast_percent(CropType.Kind.WHEAT, NOW_QUIET), expected)


func test_combined_sell_value_stacks_market_and_farmhouse_multipliers() -> void:
	eco.buy_farmhouse_upgrade()  # Level 1: +2% sell price
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(10, 0)
	var market_mult := eco.mandi_price_multiplier(CropType.Kind.WHEAT, NOW_QUIET)
	var farmhouse_mult := 1.02
	var expected_value: int = roundi(10 * 20 * market_mult * farmhouse_mult)

	var coins_before := eco.state.coins
	eco.sell_to_mandi(CropType.Kind.WHEAT, NOW_QUIET)
	assert_eq(eco.state.coins, coins_before + expected_value)
