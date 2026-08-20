## Covers NicheFarmingTab's pure logic -- build_view_data() (build-gate state
## for both zones, electricity active flag + remaining time) and
## format_hours_minutes() -- extracted specifically so they're unit-testable
## independent of the scene tree (see niche_farming_tab.gd's header
## comment). Node construction/layout/styling is explicitly NOT covered
## here, per this project's testing standards.
extends GutTest

const NOW: int = 10_000_000

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000


func test_view_data_before_either_built_reports_not_built() -> void:
	var data := NicheFarmingTab.build_view_data(eco, NOW)
	assert_false(data["has_aquaculture"])
	assert_false(data["has_vertical_farm"])
	assert_eq(data["aquaculture_cost"], GameData.AQUACULTURE_UNLOCK_COST)
	assert_eq(data["vertical_farm_cost"], GameData.VERTICAL_FARM_UNLOCK_COST)


func test_view_data_aquaculture_built_independent_of_vertical_farm() -> void:
	eco.buy_aquaculture()
	var data := NicheFarmingTab.build_view_data(eco, NOW)
	assert_true(data["has_aquaculture"])
	assert_false(data["has_vertical_farm"])


func test_view_data_vertical_farm_built_reports_electricity_inactive() -> void:
	eco.buy_vertical_farm()
	var data := NicheFarmingTab.build_view_data(eco, NOW)
	assert_true(data["has_vertical_farm"])
	assert_false(data["electricity_active"])
	assert_eq(data["electricity_remaining_ms"], 0)


func test_view_data_electricity_active_after_paying() -> void:
	eco.buy_vertical_farm()
	eco.renew_electricity(NOW)
	var data := NicheFarmingTab.build_view_data(eco, NOW)
	assert_true(data["electricity_active"])
	assert_eq(data["electricity_remaining_ms"], GameData.ELECTRICITY_DURATION_MS)


func test_view_data_electricity_inactive_once_expired() -> void:
	eco.buy_vertical_farm()
	eco.renew_electricity(NOW)
	var after_expiry := NOW + GameData.ELECTRICITY_DURATION_MS + 1
	var data := NicheFarmingTab.build_view_data(eco, after_expiry)
	assert_false(data["electricity_active"])


func test_format_hours_minutes_omits_hours_when_zero() -> void:
	assert_eq(NicheFarmingTab.format_hours_minutes(5 * 60_000), "5m")


func test_format_hours_minutes_includes_hours_when_nonzero() -> void:
	assert_eq(NicheFarmingTab.format_hours_minutes((2 * 60 + 15) * 60_000), "2h 15m")


func test_format_hours_minutes_zero_ms_reads_as_zero_minutes() -> void:
	assert_eq(NicheFarmingTab.format_hours_minutes(0), "0m")
