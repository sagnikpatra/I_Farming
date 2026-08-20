## Covers EventsTab's pure logic -- build_view_data() (Monsoon/festival
## active flags, event-pass points/tier/progress via the same
## event_state_preview() the real economy uses, never mutating state) and
## format_duration() -- extracted specifically so they're unit-testable
## independent of the scene tree (see events_tab.gd's header comment). Node
## construction/layout/styling is explicitly NOT covered here, per this
## project's testing standards.
##
## Deterministic `now` values only (no system time, no random seeds) -- same
## discipline test_mandi.gd's NOW_QUIET establishes. Monsoon cycle is 6h with
## a 90m active window; Festival cycle is 8h with a 60m active window --
## `now = 0` lands inside both active windows, `now = 3h` sits past both.
extends GutTest

const NOW_BOTH_ACTIVE: int = 0
const NOW_BOTH_QUIET: int = 3 * 60 * 60 * 1000

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000


func test_view_data_reports_monsoon_and_festival_active_at_cycle_start() -> void:
	var data := EventsTab.build_view_data(eco, NOW_BOTH_ACTIVE)
	assert_true(data["monsoon_active"])
	assert_true(data["festival_active"])


func test_view_data_reports_both_inactive_mid_cycle() -> void:
	var data := EventsTab.build_view_data(eco, NOW_BOTH_QUIET)
	assert_false(data["monsoon_active"])
	assert_false(data["festival_active"])


func test_view_data_fresh_state_has_zero_points_and_first_tier_threshold() -> void:
	var data := EventsTab.build_view_data(eco, NOW_BOTH_ACTIVE)
	assert_eq(data["event_points"], 0)
	assert_eq(data["event_tier"], 0)
	assert_eq(data["next_threshold"], GameData.FESTIVAL_TIER_THRESHOLDS[0])
	assert_eq(data["progress"], 0.0)
	assert_false(data["has_premium"])


func test_view_data_progress_is_fraction_of_next_threshold() -> void:
	eco.state.event_occurrence_index = NOW_BOTH_ACTIVE / GameData.FESTIVAL_CYCLE_MS
	eco.state.event_points = GameData.FESTIVAL_TIER_THRESHOLDS[0] / 2
	var data := EventsTab.build_view_data(eco, NOW_BOTH_ACTIVE)
	assert_almost_eq(data["progress"], 0.5, 0.05)


func test_view_data_all_tiers_reached_has_no_next_threshold() -> void:
	eco.state.event_occurrence_index = NOW_BOTH_ACTIVE / GameData.FESTIVAL_CYCLE_MS
	eco.state.event_claimed_tier = GameData.FESTIVAL_TIER_THRESHOLDS.size()
	var data := EventsTab.build_view_data(eco, NOW_BOTH_ACTIVE)
	assert_null(data["next_threshold"])
	assert_eq(data["progress"], 1.0)


func test_view_data_reflects_premium_pass_purchase() -> void:
	eco.buy_premium_pass(NOW_BOTH_ACTIVE)
	var data := EventsTab.build_view_data(eco, NOW_BOTH_ACTIVE)
	assert_true(data["has_premium"])


func test_format_duration_omits_hours_when_zero() -> void:
	assert_eq(EventsTab.format_duration(5 * 60_000), "5m")


func test_format_duration_includes_hours_when_nonzero() -> void:
	assert_eq(EventsTab.format_duration((1 * 60 + 30) * 60_000), "1h 30m")
