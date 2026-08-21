## Covers GameEconomy's Chanda Visit system (design/gdd/festival-visiting-npcs.md)
## -- the independent companion LiveOps cycle to the Festival Event Pass.
## Mirrors test_game_economy.gd's own Premium Pass test shape (before_each,
## NOW_QUIET-style phase constants) since this is the same kind of
## cycle/occurrence system.
extends GutTest

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000


# --- is_chanda_visit_active() / phase math --------------------------------------

func test_chanda_visit_active_within_the_active_window() -> void:
	assert_true(eco.is_chanda_visit_active(0))
	assert_true(eco.is_chanda_visit_active(GameData.CHANDA_ACTIVE_DURATION_MS - 1))


func test_chanda_visit_inactive_past_the_active_window() -> void:
	var now_no_visit: int = GameData.CHANDA_ACTIVE_DURATION_MS + 1000
	assert_false(eco.is_chanda_visit_active(now_no_visit))


func test_chanda_visit_active_again_on_the_next_cycle() -> void:
	var next_cycle_start: int = GameData.CHANDA_CYCLE_MS
	assert_true(eco.is_chanda_visit_active(next_cycle_start))


# --- Festival rotation -----------------------------------------------------------

func test_chanda_festival_rotates_through_all_four_in_a_fixed_order() -> void:
	var seen_names: Array[String] = []
	for cycle_index in range(4):
		var now: int = cycle_index * GameData.CHANDA_CYCLE_MS
		seen_names.append(eco.current_chanda_festival(now).display_name)
	assert_eq(seen_names, ["Durga Puja", "Eid", "Christmas", "Baisakhi"])


func test_chanda_festival_rotation_repeats_after_a_full_cycle() -> void:
	var first := eco.current_chanda_festival(0).display_name
	var fifth := eco.current_chanda_festival(4 * GameData.CHANDA_CYCLE_MS).display_name
	assert_eq(first, fifth)


# --- chanda_visit_awaiting_decision() ---------------------------------------------

func test_awaiting_decision_false_when_no_visit_is_active() -> void:
	var now_no_visit: int = GameData.CHANDA_ACTIVE_DURATION_MS + 1000
	assert_false(eco.chanda_visit_awaiting_decision(now_no_visit))


func test_awaiting_decision_true_for_a_fresh_active_visit() -> void:
	assert_true(eco.chanda_visit_awaiting_decision(0))


func test_awaiting_decision_false_once_already_resolved_this_cycle() -> void:
	eco.decline_chanda(0)
	assert_false(eco.chanda_visit_awaiting_decision(100))


func test_awaiting_decision_true_again_next_cycle_after_a_prior_resolution() -> void:
	eco.decline_chanda(0)
	var next_cycle_start: int = GameData.CHANDA_CYCLE_MS
	assert_true(eco.chanda_visit_awaiting_decision(next_cycle_start))


# --- chanda_ask_amount() ----------------------------------------------------------

func test_ask_amount_scales_with_farmhouse_level() -> void:
	eco.state.farmhouse_level = 0
	var ask_level_0 := eco.chanda_ask_amount()
	eco.state.farmhouse_level = 3
	var ask_level_3 := eco.chanda_ask_amount()
	assert_eq(ask_level_0, GameData.CHANDA_BASE_ASK)
	assert_eq(ask_level_3, GameData.CHANDA_BASE_ASK + 3 * GameData.CHANDA_ASK_PER_LEVEL)
	assert_gt(ask_level_3, ask_level_0)


# --- give_chanda() -----------------------------------------------------------------

func test_give_chanda_deducts_the_ask_and_marks_resolved() -> void:
	var coins_before := eco.state.coins
	eco.give_chanda(0)
	assert_eq(eco.state.coins, coins_before - eco.chanda_ask_amount())
	assert_eq(eco.state.chanda_last_resolved_cycle_index, 0)
	assert_true(eco.has_events())


func test_give_chanda_starts_the_blessing_timer() -> void:
	eco.give_chanda(0)
	assert_eq(eco.state.chanda_blessing_active_until, GameData.CHANDA_BLESSING_DURATION_MS)


func test_give_chanda_blocked_when_unaffordable() -> void:
	eco.state.coins = 0
	eco.give_chanda(0)
	assert_eq(eco.state.coins, 0)
	assert_eq(eco.state.chanda_last_resolved_cycle_index, -1)
	assert_true(eco.has_events())


func test_give_chanda_noop_when_no_visit_is_active() -> void:
	var now_no_visit: int = GameData.CHANDA_ACTIVE_DURATION_MS + 1000
	var coins_before := eco.state.coins
	eco.give_chanda(now_no_visit)
	assert_eq(eco.state.coins, coins_before)
	assert_eq(eco.state.chanda_last_resolved_cycle_index, -1)


func test_give_chanda_twice_in_the_same_occurrence_is_a_silent_noop() -> void:
	eco.give_chanda(0)
	var coins_after_first := eco.state.coins
	eco.pending_events.clear()
	eco.give_chanda(100)
	assert_eq(eco.state.coins, coins_after_first)
	assert_false(eco.has_events())


func test_give_chanda_a_second_time_next_cycle_resets_rather_than_stacks_the_blessing() -> void:
	eco.give_chanda(0)
	var first_active_until: int = eco.state.chanda_blessing_active_until
	var next_cycle_start: int = GameData.CHANDA_CYCLE_MS
	eco.give_chanda(next_cycle_start)
	var second_active_until: int = eco.state.chanda_blessing_active_until
	# Reset forward from the second give, not extended/stacked from the first.
	assert_eq(second_active_until, next_cycle_start + GameData.CHANDA_BLESSING_DURATION_MS)
	assert_ne(second_active_until, first_active_until)


# --- decline_chanda() ---------------------------------------------------------------

func test_decline_chanda_costs_nothing_and_grants_no_blessing() -> void:
	var coins_before := eco.state.coins
	eco.decline_chanda(0)
	assert_eq(eco.state.coins, coins_before)
	assert_eq(eco.state.chanda_blessing_active_until, 0)
	assert_true(eco.has_events())


func test_decline_chanda_still_marks_the_occurrence_resolved() -> void:
	eco.decline_chanda(0)
	assert_eq(eco.state.chanda_last_resolved_cycle_index, 0)


func test_decline_chanda_noop_when_no_visit_is_active() -> void:
	var now_no_visit: int = GameData.CHANDA_ACTIVE_DURATION_MS + 1000
	eco.decline_chanda(now_no_visit)
	assert_eq(eco.state.chanda_last_resolved_cycle_index, -1)


# --- Blessing composes with the sell-price multiplier -------------------------------

func test_blessing_increases_sell_proceeds_while_active() -> void:
	eco.state.inventory.clear()
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(10, 0)
	var crop_def := GameData.crop_def(CropType.Kind.WHEAT)
	var expected_base: int = roundi(10 * crop_def.base_sell_price * 1.0)

	eco.give_chanda(0)
	# Sell just after giving, well within the blessing window.
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(10, 0)
	var coins_before := eco.state.coins
	eco.sell_crop(CropType.Kind.WHEAT, 100)
	var proceeds: int = eco.state.coins - coins_before

	var expected_blessed: int = roundi(10 * crop_def.base_sell_price * GameData.CHANDA_BLESSING_MULTIPLIER)
	assert_eq(proceeds, expected_blessed)
	assert_gt(proceeds, expected_base)


func test_blessing_no_longer_applies_once_it_expires() -> void:
	eco.give_chanda(0)
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(10, 0)
	var crop_def := GameData.crop_def(CropType.Kind.WHEAT)
	var coins_before := eco.state.coins
	var now_after_expiry: int = GameData.CHANDA_BLESSING_DURATION_MS + 1000
	eco.sell_crop(CropType.Kind.WHEAT, now_after_expiry)
	var proceeds: int = eco.state.coins - coins_before
	assert_eq(proceeds, roundi(10 * crop_def.base_sell_price * 1.0))
