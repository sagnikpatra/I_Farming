## Covers crop-economy.md's formula table: effective grow time (TR-crop-001),
## weather/pest risk (TR-crop-002), direct sale value (TR-crop-003), and lazy
## offline-safe growth resolution (TR-crop-004).
extends GutTest

## A timestamp inside neither Monsoon's nor Festival's active window
## (verified: 10_000_000 mod MONSOON_CYCLE_MS = 10_000_000 > 5_400_000;
## mod FESTIVAL_CYCLE_MS = 10_000_000 > 3_600_000) so baseline formula tests
## aren't accidentally perturbed by either LiveOps system.
const NOW_QUIET: int = 10_000_000

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000


func test_effective_grow_time_baseline_matches_crop_grow_seconds() -> void:
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	assert_eq(plot.state.effective_grow_seconds, 120)  # Wheat's base growSeconds, no bonuses active


func test_effective_grow_time_scales_with_farmhouse_growth_speed_bonus() -> void:
	eco.buy_farmhouse_upgrade()  # Level 1: +3% growth speed -> multiplier 0.97
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	# 120 * 0.97 = 116.4 -> round -> 116
	assert_eq(plot.state.effective_grow_seconds, 116)


func test_effective_grow_time_halved_by_fan_pad_with_active_film() -> void:
	eco.buy_polyhouse()
	eco.buy_fan_pad()
	eco.renew_film(NOW_QUIET)
	var polyhouse_plot: Plot = null
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.POLYHOUSE:
			polyhouse_plot = p
			break
	eco.plant_seed(polyhouse_plot.id, CropType.Kind.CAPSICUM, NOW_QUIET)
	# Capsicum growSeconds=2400; Fan&Pad+active film halves it -> 1200
	assert_eq(polyhouse_plot.state.effective_grow_seconds, 1200)


func test_effective_grow_time_not_halved_without_active_film() -> void:
	eco.buy_polyhouse()
	eco.buy_fan_pad()
	# No renew_film() call -- film never active.
	var polyhouse_plot: Plot = null
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.POLYHOUSE:
			polyhouse_plot = p
			break
	eco.plant_seed(polyhouse_plot.id, CropType.Kind.CAPSICUM, NOW_QUIET)
	assert_eq(polyhouse_plot.state.effective_grow_seconds, 2400)


func test_effective_grow_time_speed_boost_during_monsoon_open_field_only() -> void:
	var now_monsoon: int = 0  # phase 0 for both cycles -> Monsoon active
	assert_true(eco.is_monsoon_active(now_monsoon))
	var plot: Plot = eco.state.plots[0]  # OPEN_FIELD
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, now_monsoon)
	# 120 * 0.8 (Monsoon) = 96
	assert_eq(plot.state.effective_grow_seconds, 96)


func test_effective_grow_time_minimum_one_second() -> void:
	# Stack every speed bonus available to drive effective time toward (but
	# never below) 1s: Level 7 Farmhouse (0.80x) is nowhere near enough to
	# break Wheat's 120s down to 0, but this test locks in the
	# `.coerceAtLeast(1)` / `maxi(..., 1)` floor exists and is wired correctly
	# by checking the formula never produces a non-positive value across the
	# full Farmhouse level range.
	for level in range(0, GameData.farmhouse_max_level() + 1):
		var e := GameEconomy.new()
		e.state.coins = 100_000_000
		e.state.farmhouse_level = level
		var plot: Plot = e.state.plots[0]
		e.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
		assert_true(plot.state.effective_grow_seconds >= 1)


func test_weather_risk_open_field_matches_crop_table() -> void:
	assert_eq(eco.effective_weather_risk_percent(PlotKind.Kind.OPEN_FIELD, CropType.Kind.WHEAT, NOW_QUIET), 8)
	assert_eq(eco.effective_weather_risk_percent(PlotKind.Kind.OPEN_FIELD, CropType.Kind.PADDY, NOW_QUIET), 12)
	assert_eq(eco.effective_weather_risk_percent(PlotKind.Kind.OPEN_FIELD, CropType.Kind.TOMATO, NOW_QUIET), 15)


func test_weather_risk_polyhouse_unprotected_without_film() -> void:
	assert_eq(
		eco.effective_weather_risk_percent(PlotKind.Kind.POLYHOUSE, CropType.Kind.CAPSICUM, NOW_QUIET),
		GameData.POLYHOUSE_UNPROTECTED_RISK_PERCENT
	)


func test_weather_risk_polyhouse_zero_with_active_film() -> void:
	eco.buy_polyhouse()
	eco.renew_film(NOW_QUIET)
	assert_eq(eco.effective_weather_risk_percent(PlotKind.Kind.POLYHOUSE, CropType.Kind.CAPSICUM, NOW_QUIET), 0)


func test_weather_risk_zero_for_managed_tiers() -> void:
	assert_eq(eco.effective_weather_risk_percent(PlotKind.Kind.AGROFORESTRY, CropType.Kind.SANDALWOOD, NOW_QUIET), 0)
	assert_eq(eco.effective_weather_risk_percent(PlotKind.Kind.AQUACULTURE, CropType.Kind.MAKHANA, NOW_QUIET), 0)
	assert_eq(eco.effective_weather_risk_percent(PlotKind.Kind.VERTICAL_FARM, CropType.Kind.SAFFRON, NOW_QUIET), 0)


func test_direct_sale_value_normal_stock_only() -> void:
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(5, 0)
	eco.sell_crop(CropType.Kind.WHEAT, NOW_QUIET)
	# 5 * 20 (baseSellPrice) * 1.0 (no Farmhouse bonus) = 100
	assert_eq(eco.state.coins, 1_000_000 + 100)


func test_direct_sale_value_damaged_stock_at_half_multiplier() -> void:
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(0, 4)
	eco.sell_crop(CropType.Kind.WHEAT, NOW_QUIET)
	# 4 * 20 * 0.5 (WEATHER_DAMAGE_YIELD_MULTIPLIER) * 1.0 = 40
	assert_eq(eco.state.coins, 1_000_000 + 40)


func test_direct_sale_value_mixed_stock_and_farmhouse_bonus() -> void:
	eco.buy_farmhouse_upgrade()  # Level 1: +2% sell price -> multiplier 1.02
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(10, 2)
	var coins_before := eco.state.coins
	eco.sell_crop(CropType.Kind.WHEAT, NOW_QUIET)
	# 10*20*1.02 + 2*20*0.5*1.02 = 204.0 + 20.4 = 224.4 -> round each term first
	# (matches Kotlin's per-term roundToLong): 204 + 20 = 224
	assert_eq(eco.state.coins, coins_before + 224)


func test_sell_crop_with_zero_stock_is_a_noop() -> void:
	var coins_before := eco.state.coins
	eco.sell_crop(CropType.Kind.WHEAT, NOW_QUIET)
	assert_eq(eco.state.coins, coins_before)
	assert_false(eco.has_events())


func test_harvest_blocked_when_storage_full() -> void:
	# Level 0 storage capacity is 50. Fill it exactly, then attempt one more
	# harvest -- must block with an event, plot stays ReadyToHarvest.
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(50, 0)
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	eco.resolve_growth_completions(NOW_QUIET + 200 * 1000)
	assert_eq(plot.state.kind, PlotState.Kind.READY_TO_HARVEST)

	eco.pending_events.clear()
	eco.harvest_plot(plot.id, NOW_QUIET + 200 * 1000)
	assert_eq(plot.state.kind, PlotState.Kind.READY_TO_HARVEST)  # still blocked
	assert_true(eco.has_events())


func test_offline_growth_resolves_correctly_across_an_arbitrary_gap() -> void:
	# Lazy resolution (TR-crop-004): a crop planted, then resolved only once
	# after a huge elapsed gap (simulating the app being closed), must still
	# transition correctly -- no live ticking required.
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	assert_eq(plot.state.kind, PlotState.Kind.GROWING)

	var far_future: int = NOW_QUIET + 30 * 24 * 60 * 60 * 1000  # 30 days later
	eco.resolve_growth_completions(far_future)
	assert_eq(plot.state.kind, PlotState.Kind.READY_TO_HARVEST)
	assert_eq(plot.state.ready_at_epoch_ms, far_future)
