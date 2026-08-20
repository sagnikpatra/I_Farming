## Covers PolyhouseTab's pure logic -- build_view_data() (build-gate state,
## subsidy cost/progress, upgrade chip active flags) -- extracted
## specifically so it's unit-testable independent of the scene tree (see
## polyhouse_tab.gd's header comment). Node construction/layout/styling is
## explicitly NOT covered here, per this project's testing standards
## (.claude/docs/coding-standards.md: "Visual/Feel" stories get screenshot
## evidence, not automated tests).
extends GutTest

const NOW: int = 10_000_000

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000


func test_view_data_before_built_reports_not_built() -> void:
	var data := PolyhouseTab.build_view_data(eco, NOW)
	assert_false(data["has_polyhouse"])


func test_view_data_cost_is_base_cost_before_subsidy_unlocked() -> void:
	var data := PolyhouseTab.build_view_data(eco, NOW)
	assert_false(data["subsidy_unlocked"])
	assert_eq(data["cost"], GameData.polyhouse_cost(false))


func test_view_data_cost_is_subsidy_cost_once_unlocked() -> void:
	eco.state.total_harvests = GameData.SUBSIDY_QUEST_TARGET
	var data := PolyhouseTab.build_view_data(eco, NOW)
	assert_true(data["subsidy_unlocked"])
	assert_eq(data["cost"], GameData.polyhouse_cost(true))


func test_view_data_subsidy_progress_is_fraction_of_target() -> void:
	# Half of SUBSIDY_QUEST_TARGET (25) harvests -> 0.5, rounding down.
	eco.state.total_harvests = GameData.SUBSIDY_QUEST_TARGET / 2
	var data := PolyhouseTab.build_view_data(eco, NOW)
	assert_almost_eq(data["subsidy_progress"], 0.5, 0.05)


func test_view_data_subsidy_progress_clamps_to_one_past_target() -> void:
	eco.state.total_harvests = GameData.SUBSIDY_QUEST_TARGET * 3
	var data := PolyhouseTab.build_view_data(eco, NOW)
	assert_eq(data["subsidy_progress"], 1.0)


func test_view_data_after_built_reports_built_and_upgrade_flags() -> void:
	eco.buy_polyhouse()
	var data := PolyhouseTab.build_view_data(eco, NOW)
	assert_true(data["has_polyhouse"])
	assert_false(data["has_fan_pad"])
	assert_false(data["has_drip_irrigation"])
	assert_false(data["film_active"])


func test_view_data_reflects_purchased_upgrades() -> void:
	eco.buy_polyhouse()
	eco.buy_fan_pad()
	eco.buy_drip_irrigation()
	eco.renew_film(NOW)
	var data := PolyhouseTab.build_view_data(eco, NOW)
	assert_true(data["has_fan_pad"])
	assert_true(data["has_drip_irrigation"])
	assert_true(data["film_active"])


func test_view_data_film_active_false_once_expired() -> void:
	eco.buy_polyhouse()
	eco.renew_film(NOW)
	var after_expiry := NOW + GameData.UV_FILM_DURATION_MS + 1
	var data := PolyhouseTab.build_view_data(eco, after_expiry)
	assert_false(data["film_active"])
