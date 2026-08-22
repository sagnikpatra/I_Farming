## Covers GameEconomy's own orchestration logic that isn't already exercised
## by the formula-focused sibling test files (test_crop_economy,
## test_farmhouse, test_land_structures, test_mandi, test_plot_state,
## test_game_data): guard clauses on plant_seed/harvest_plot/sell_crop/
## sell_all, every buy_* method's cost-deduction and unlock-gating, the
## Agroforestry host/Sandalwood placement API, renew_film/renew_electricity,
## the village-board zone/decoration layout mutators, and has_events()/
## pop_event() actually getting populated by these calls.
extends GutTest

const NOW_QUIET: int = 10_000_000

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000


func _first_agro_plot() -> Plot:
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.AGROFORESTRY:
			return p
	return null


# --- plant_seed guard clauses not already covered by test_plot_state.gd ------

func test_plant_seed_sandalwood_is_a_noop_via_this_entry_point() -> void:
	# Sandalwood must be planted via plant_sandalwood(), not plant_seed().
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.SANDALWOOD, NOW_QUIET)
	assert_eq(plot.state.kind, PlotState.Kind.EMPTY)


func test_plant_seed_on_unknown_plot_id_is_a_noop() -> void:
	var coins_before := eco.state.coins
	eco.plant_seed(9999, CropType.Kind.WHEAT, NOW_QUIET)
	assert_eq(eco.state.coins, coins_before)


func test_plant_seed_blocked_on_insufficient_coins() -> void:
	eco.state.coins = 0
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	assert_eq(plot.state.kind, PlotState.Kind.EMPTY)
	assert_true(eco.has_events())


# --- harvest_plot --------------------------------------------------------------

func test_harvest_plot_on_unknown_plot_id_is_a_noop() -> void:
	eco.harvest_plot(9999, NOW_QUIET)
	assert_false(eco.has_events())


func test_harvest_plot_increments_total_harvests_and_clears_the_plot() -> void:
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	eco.resolve_growth_completions(NOW_QUIET + 200 * 1000)
	assert_eq(eco.state.total_harvests, 0)
	eco.harvest_plot(plot.id, NOW_QUIET + 200 * 1000)
	assert_eq(plot.state.kind, PlotState.Kind.EMPTY)
	assert_eq(eco.state.total_harvests, 1)


# --- sell_crop / sell_all guard clauses -----------------------------------------

func test_sell_crop_with_no_stock_entry_at_all_is_a_noop() -> void:
	var coins_before := eco.state.coins
	eco.sell_crop(CropType.Kind.SAFFRON, NOW_QUIET)
	assert_eq(eco.state.coins, coins_before)


func test_sell_all_with_empty_inventory_is_a_noop() -> void:
	var coins_before := eco.state.coins
	eco.sell_all(NOW_QUIET)
	assert_eq(eco.state.coins, coins_before)
	assert_false(eco.has_events())


func test_sell_all_sells_every_crop_and_clears_inventory() -> void:
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(5, 0)
	eco.state.inventory[CropType.Kind.PADDY] = CropStock.new(2, 1)
	var coins_before := eco.state.coins
	eco.sell_all(NOW_QUIET)
	assert_true(eco.state.inventory.is_empty())
	# Wheat: 5*20 = 100. Paddy: 2*80 + 1*80*0.5 = 160 + 40 = 200. Total 300.
	assert_eq(eco.state.coins, coins_before + 300)
	assert_true(eco.has_events())


# --- buy_farmhouse_upgrade -------------------------------------------------------

func test_buy_farmhouse_upgrade_at_max_level_is_a_silent_noop() -> void:
	eco.state.coins = 100_000_000
	eco.state.farmhouse_level = GameData.farmhouse_max_level()
	eco.buy_farmhouse_upgrade()
	assert_false(eco.has_events())
	assert_false(eco.dirty)


# --- buy_land_expansion ----------------------------------------------------------

func test_buy_land_expansion_blocked_on_insufficient_coins() -> void:
	eco.state.coins = 0
	var plot_count_before := eco.state.plots.size()
	eco.buy_land_expansion()
	assert_eq(eco.state.plots.size(), plot_count_before)
	assert_true(eco.has_events())


# --- buy_polyhouse / fan pad / drip irrigation / renew_film -----------------------

func test_buy_polyhouse_twice_is_a_noop_the_second_time() -> void:
	eco.buy_polyhouse()
	var plot_count_after_first := eco.state.plots.size()
	var coins_after_first := eco.state.coins
	eco.buy_polyhouse()
	assert_eq(eco.state.plots.size(), plot_count_after_first)
	assert_eq(eco.state.coins, coins_after_first)


func test_buy_polyhouse_blocked_on_insufficient_coins() -> void:
	eco.state.coins = 0
	eco.buy_polyhouse()
	assert_false(eco.state.has_polyhouse)
	assert_true(eco.has_events())


func test_buy_fan_pad_requires_polyhouse_first() -> void:
	eco.buy_fan_pad()  # No Polyhouse yet -- silent no-op, not even an event.
	assert_false(eco.state.has_fan_pad)
	assert_false(eco.has_events())


func test_buy_fan_pad_blocked_on_insufficient_coins() -> void:
	eco.buy_polyhouse()
	eco.state.coins = 0
	eco.buy_fan_pad()
	assert_false(eco.state.has_fan_pad)
	assert_true(eco.has_events())


func test_buy_fan_pad_twice_is_a_noop_the_second_time() -> void:
	eco.buy_polyhouse()
	eco.buy_fan_pad()
	var coins_after_first := eco.state.coins
	eco.buy_fan_pad()
	assert_eq(eco.state.coins, coins_after_first)


func test_buy_drip_irrigation_requires_polyhouse_first() -> void:
	eco.buy_drip_irrigation()
	assert_false(eco.state.has_drip_irrigation)
	assert_false(eco.has_events())


func test_buy_drip_irrigation_twice_is_a_noop_the_second_time() -> void:
	eco.buy_polyhouse()
	eco.buy_drip_irrigation()
	var coins_after_first := eco.state.coins
	eco.buy_drip_irrigation()
	assert_eq(eco.state.coins, coins_after_first)


func test_renew_film_requires_polyhouse_first() -> void:
	eco.renew_film(NOW_QUIET)
	assert_eq(eco.state.film_expires_at_epoch_ms, -1)
	assert_false(eco.has_events())


func test_renew_film_blocked_on_insufficient_coins() -> void:
	eco.buy_polyhouse()
	eco.state.coins = 0
	eco.renew_film(NOW_QUIET)
	assert_eq(eco.state.film_expires_at_epoch_ms, -1)
	assert_true(eco.has_events())


func test_renew_film_sets_expiry_and_activates_protection() -> void:
	eco.buy_polyhouse()
	eco.renew_film(NOW_QUIET)
	assert_eq(eco.state.film_expires_at_epoch_ms, NOW_QUIET + GameData.UV_FILM_DURATION_MS)
	assert_true(eco.is_film_active(NOW_QUIET))
	assert_false(eco.is_film_active(NOW_QUIET + GameData.UV_FILM_DURATION_MS))


# --- Agroforestry: buy_agroforestry / buy_security / hosts / sandalwood ----------

func test_buy_agroforestry_twice_is_a_noop_the_second_time() -> void:
	eco.buy_agroforestry()
	var plot_count_after_first := eco.state.plots.size()
	eco.buy_agroforestry()
	assert_eq(eco.state.plots.size(), plot_count_after_first)


func test_buy_agroforestry_blocked_on_insufficient_coins() -> void:
	eco.state.coins = 0
	eco.buy_agroforestry()
	assert_false(eco.state.has_agroforestry)
	assert_true(eco.has_events())


func test_buy_security_requires_agroforestry_first() -> void:
	eco.buy_security()
	assert_false(eco.state.has_security)
	assert_false(eco.has_events())


func test_buy_security_blocked_on_insufficient_coins() -> void:
	eco.buy_agroforestry()
	eco.state.coins = 0
	eco.buy_security()
	assert_false(eco.state.has_security)
	assert_true(eco.has_events())


func test_buy_security_twice_is_a_noop_the_second_time() -> void:
	eco.buy_agroforestry()
	eco.buy_security()
	var coins_after_first := eco.state.coins
	eco.buy_security()
	assert_eq(eco.state.coins, coins_after_first)


func test_plant_host_blocked_on_insufficient_coins() -> void:
	eco.buy_agroforestry()
	var plot := _first_agro_plot()
	eco.state.coins = 0
	eco.plant_host(plot.id, HostType.Kind.ACACIA)
	assert_eq(plot.host_type, HostType.NONE)
	assert_true(eco.has_events())


func test_plant_host_blocked_when_plot_already_has_a_host() -> void:
	eco.buy_agroforestry()
	var plot := _first_agro_plot()
	eco.plant_host(plot.id, HostType.Kind.NEEM)
	var coins_after_first := eco.state.coins
	eco.plant_host(plot.id, HostType.Kind.ACACIA)
	assert_eq(plot.host_type, HostType.Kind.NEEM)  # unchanged
	assert_eq(eco.state.coins, coins_after_first)


func test_plant_host_blocked_on_non_agroforestry_plot() -> void:
	var open_field_plot: Plot = eco.state.plots[0]
	eco.plant_host(open_field_plot.id, HostType.Kind.NEEM)
	assert_eq(open_field_plot.host_type, HostType.NONE)


func test_remove_host_on_a_plot_with_no_host_is_a_noop() -> void:
	eco.buy_agroforestry()
	var plot := _first_agro_plot()
	eco.remove_host(plot.id)
	assert_eq(plot.host_type, HostType.NONE)


func test_can_plant_sandalwood_false_on_unknown_plot() -> void:
	assert_false(eco.can_plant_sandalwood(9999))


func test_can_plant_sandalwood_false_on_non_agroforestry_plot() -> void:
	var open_field_plot: Plot = eco.state.plots[0]
	assert_false(eco.can_plant_sandalwood(open_field_plot.id))


func test_can_plant_sandalwood_false_when_tile_already_occupied_by_a_host() -> void:
	eco.buy_agroforestry()
	var plot := _first_agro_plot()
	eco.plant_host(plot.id, HostType.Kind.PIGEON_PEA)
	assert_false(eco.can_plant_sandalwood(plot.id))


func test_plant_sandalwood_blocked_without_an_adjacent_host() -> void:
	eco.buy_agroforestry()
	var plot := _first_agro_plot()
	eco.plant_sandalwood(plot.id, NOW_QUIET)
	assert_eq(plot.state.kind, PlotState.Kind.EMPTY)
	assert_true(eco.has_events())


func test_plant_sandalwood_blocked_on_insufficient_coins() -> void:
	eco.buy_agroforestry()
	var agro_plots: Array[Plot] = []
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.AGROFORESTRY:
			agro_plots.append(p)
	eco.plant_host(agro_plots[0].id, HostType.Kind.NEEM)  # agro_plots[1] is adjacent
	eco.state.coins = 0
	eco.pending_events.clear()
	eco.plant_sandalwood(agro_plots[1].id, NOW_QUIET)
	assert_eq(agro_plots[1].state.kind, PlotState.Kind.EMPTY)
	assert_true(eco.has_events())


# --- Tier 4: aquaculture / vertical farm / electricity ----------------------------

func test_buy_aquaculture_twice_is_a_noop_the_second_time() -> void:
	eco.buy_aquaculture()
	var plot_count_after_first := eco.state.plots.size()
	eco.buy_aquaculture()
	assert_eq(eco.state.plots.size(), plot_count_after_first)


func test_buy_aquaculture_blocked_on_insufficient_coins() -> void:
	eco.state.coins = 0
	eco.buy_aquaculture()
	assert_false(eco.state.has_aquaculture)
	assert_true(eco.has_events())


func test_buy_vertical_farm_twice_is_a_noop_the_second_time() -> void:
	eco.buy_vertical_farm()
	var plot_count_after_first := eco.state.plots.size()
	eco.buy_vertical_farm()
	assert_eq(eco.state.plots.size(), plot_count_after_first)


func test_buy_vertical_farm_blocked_on_insufficient_coins() -> void:
	eco.state.coins = 0
	eco.buy_vertical_farm()
	assert_false(eco.state.has_vertical_farm)
	assert_true(eco.has_events())


func test_renew_electricity_requires_vertical_farm_first() -> void:
	eco.renew_electricity(NOW_QUIET)
	assert_eq(eco.state.electricity_expires_at_epoch_ms, -1)
	assert_false(eco.has_events())


func test_renew_electricity_blocked_on_insufficient_coins() -> void:
	eco.buy_vertical_farm()
	eco.state.coins = 0
	eco.renew_electricity(NOW_QUIET)
	assert_eq(eco.state.electricity_expires_at_epoch_ms, -1)
	assert_true(eco.has_events())


func test_renew_electricity_sets_expiry() -> void:
	eco.buy_vertical_farm()
	eco.renew_electricity(NOW_QUIET)
	assert_eq(eco.state.electricity_expires_at_epoch_ms, NOW_QUIET + GameData.ELECTRICITY_DURATION_MS)
	assert_true(eco.is_electricity_active(NOW_QUIET))


# --- Mandi unlocks -----------------------------------------------------------------

func test_buy_mandi_twice_is_a_noop_the_second_time() -> void:
	eco.buy_mandi()
	var coins_after_first := eco.state.coins
	eco.buy_mandi()
	assert_eq(eco.state.coins, coins_after_first)


func test_buy_mandi_blocked_on_insufficient_coins() -> void:
	eco.state.coins = 0
	eco.buy_mandi()
	assert_false(eco.state.has_mandi)
	assert_true(eco.has_events())


func test_buy_mandi_terminal_requires_mandi_first() -> void:
	eco.buy_mandi_terminal()
	assert_false(eco.state.has_mandi_terminal)
	assert_false(eco.has_events())


func test_buy_mandi_terminal_blocked_on_insufficient_coins() -> void:
	eco.buy_mandi()
	eco.state.coins = 0
	eco.buy_mandi_terminal()
	assert_false(eco.state.has_mandi_terminal)
	assert_true(eco.has_events())


func test_buy_mandi_terminal_twice_is_a_noop_the_second_time() -> void:
	eco.buy_mandi()
	eco.buy_mandi_terminal()
	var coins_after_first := eco.state.coins
	eco.buy_mandi_terminal()
	assert_eq(eco.state.coins, coins_after_first)


# --- Premium Pass --------------------------------------------------------------------

func test_buy_premium_pass_blocked_outside_an_active_festival() -> void:
	# FESTIVAL_ACTIVE_DURATION_MS is 1h out of an 8h cycle -- pick a phase past it.
	var now_no_festival: int = GameData.FESTIVAL_ACTIVE_DURATION_MS + 1000
	eco.buy_premium_pass(now_no_festival)
	assert_false(eco.state.event_has_premium_pass)
	assert_true(eco.has_events())


func test_buy_premium_pass_blocked_on_insufficient_coins() -> void:
	var now_festival: int = 0  # Phase 0 -- festival active.
	eco.state.coins = 0
	eco.buy_premium_pass(now_festival)
	assert_false(eco.state.event_has_premium_pass)
	assert_true(eco.has_events())


func test_buy_premium_pass_twice_in_the_same_occurrence_is_a_silent_noop() -> void:
	var now_festival: int = 0
	eco.buy_premium_pass(now_festival)
	assert_true(eco.state.event_has_premium_pass)
	var coins_after_first := eco.state.coins
	eco.pending_events.clear()
	eco.buy_premium_pass(now_festival)
	assert_eq(eco.state.coins, coins_after_first)
	assert_false(eco.has_events())


## Balance fix regression guard (design/balance/balance-check-liveops-
## events-2026-08-22.md): the smallest tier's premium bonus must cover
## the pass cost, or the pass has negative expected value for anyone who
## buys it and only reaches the first tier that occurrence -- exactly
## the "trap purchase" this fix closed. A pure data-level invariant, not
## tied to any specific FESTIVAL_PREMIUM_PASS_COST/FESTIVAL_PREMIUM_BONUS
## value -- catches a future constant change reintroducing the same bug
## regardless of what the new numbers are.
func test_premium_pass_cost_never_exceeds_the_smallest_tiers_premium_bonus() -> void:
	assert_true(
		GameData.FESTIVAL_PREMIUM_PASS_COST <= GameData.FESTIVAL_PREMIUM_BONUS[0],
		"the pass must never cost more than the smallest tier's own premium bonus, or reaching only that tier is a real loss"
	)


## The same guarantee, proven end-to-end through a real festival sale
## registering real tier progress -- not just the data-level invariant
## above. Phase 0 = Makar Sankranti (target crop Paddy, see
## GameData._ensure_festivals()); FESTIVAL_TIER_THRESHOLDS[0] = 50 points
## at FESTIVAL_POINTS_PER_UNIT_SOLD = 2 -- exactly 25 units sold reaches
## Tier 1 and no further.
func test_premium_pass_reaching_only_tier_one_is_not_a_net_loss() -> void:
	var now_festival: int = 0
	eco.buy_premium_pass(now_festival)
	var coins_after_pass_purchase := eco.state.coins

	eco.state.inventory[CropType.Kind.PADDY] = CropStock.new(25, 0)
	eco.sell_crop(CropType.Kind.PADDY, now_festival)

	assert_eq(eco.state.event_claimed_tier, 1, "precondition: this test must actually land on Tier 1, not overshoot or undershoot it")
	var coins_gained_from_tier_reward: int = (
		eco.state.coins - coins_after_pass_purchase - (GameData.crop_def(CropType.Kind.PADDY).base_sell_price * 25)
	)
	assert_true(
		coins_gained_from_tier_reward >= GameData.FESTIVAL_PREMIUM_PASS_COST,
		"the tier-1 reward alone (free + premium bonus) must cover what the pass cost, real end-to-end"
	)


# --- Zone layout: move / rotate / flip -----------------------------------------------

func test_move_zone_creates_a_new_anchor_at_default_orientation() -> void:
	eco.move_zone("farmhouse", 2.0, 3.0)
	var anchor: ZoneAnchor = eco.state.zone_layout["farmhouse"]
	assert_almost_eq(anchor.tile_x, 2.0, 0.0001)
	assert_almost_eq(anchor.tile_y, 3.0, 0.0001)
	assert_eq(anchor.rotation_degrees, 0)
	assert_false(anchor.flipped_x)


func test_move_zone_preserves_existing_rotation_and_flip() -> void:
	eco.rotate_zone("mandi", 0.0, 0.0)
	eco.flip_zone("mandi", 0.0, 0.0)
	eco.move_zone("mandi", 5.0, 6.0)
	var anchor: ZoneAnchor = eco.state.zone_layout["mandi"]
	assert_almost_eq(anchor.tile_x, 5.0, 0.0001)
	assert_almost_eq(anchor.tile_y, 6.0, 0.0001)
	assert_eq(anchor.rotation_degrees, 90)
	assert_true(anchor.flipped_x)


func test_rotate_zone_with_no_existing_anchor_starts_from_the_given_default() -> void:
	eco.rotate_zone("mandi", 1.0, 2.0)
	var anchor: ZoneAnchor = eco.state.zone_layout["mandi"]
	assert_almost_eq(anchor.tile_x, 1.0, 0.0001)
	assert_eq(anchor.rotation_degrees, 90)


func test_rotate_zone_wraps_at_360() -> void:
	for _i in range(4):
		eco.rotate_zone("mandi", 0.0, 0.0)
	var anchor: ZoneAnchor = eco.state.zone_layout["mandi"]
	assert_eq(anchor.rotation_degrees, 0)


func test_flip_zone_toggles_flipped_x() -> void:
	eco.flip_zone("mandi", 0.0, 0.0)
	assert_true((eco.state.zone_layout["mandi"] as ZoneAnchor).flipped_x)
	eco.flip_zone("mandi", 0.0, 0.0)
	assert_false((eco.state.zone_layout["mandi"] as ZoneAnchor).flipped_x)


# --- Decorations ---------------------------------------------------------------------

func test_place_decoration_blocked_on_insufficient_coins() -> void:
	eco.state.coins = 0
	eco.place_decoration(DecorationType.Kind.STATUE, 1.0, 1.0)
	assert_true(eco.state.decorations.is_empty())
	assert_true(eco.has_events())


func test_place_decoration_deducts_cost_and_increments_next_id() -> void:
	var id_before := eco.state.next_decoration_id
	eco.place_decoration(DecorationType.Kind.POTTED_PLANT, 2.0, 3.0)
	assert_eq(eco.state.decorations.size(), 1)
	assert_eq(eco.state.decorations[0].id, id_before)
	assert_eq(eco.state.next_decoration_id, id_before + 1)
	assert_eq(eco.state.coins, 1_000_000 - GameData.decoration_type_def(DecorationType.Kind.POTTED_PLANT).cost)


func test_remove_decoration_keeps_only_non_matching_ids() -> void:
	eco.place_decoration(DecorationType.Kind.POTTED_PLANT, 0.0, 0.0)
	eco.place_decoration(DecorationType.Kind.BAMBOO, 1.0, 1.0)
	var first_id: int = eco.state.decorations[0].id
	eco.remove_decoration(first_id)
	assert_eq(eco.state.decorations.size(), 1)
	assert_ne(eco.state.decorations[0].id, first_id)


func test_move_decoration_only_affects_the_matching_id() -> void:
	eco.place_decoration(DecorationType.Kind.POTTED_PLANT, 0.0, 0.0)
	eco.place_decoration(DecorationType.Kind.BAMBOO, 1.0, 1.0)
	var target_id: int = eco.state.decorations[0].id
	eco.move_decoration(target_id, 9.0, 9.0)
	assert_almost_eq(eco.state.decorations[0].tile_x, 9.0, 0.0001)
	assert_almost_eq(eco.state.decorations[1].tile_x, 1.0, 0.0001)


func test_rotate_decoration_only_affects_the_matching_id_and_wraps_at_360() -> void:
	eco.place_decoration(DecorationType.Kind.POTTED_PLANT, 0.0, 0.0)
	var target_id: int = eco.state.decorations[0].id
	for _i in range(4):
		eco.rotate_decoration(target_id)
	assert_eq(eco.state.decorations[0].rotation_degrees, 0)


func test_flip_decoration_only_affects_the_matching_id() -> void:
	eco.place_decoration(DecorationType.Kind.POTTED_PLANT, 0.0, 0.0)
	eco.place_decoration(DecorationType.Kind.BAMBOO, 1.0, 1.0)
	var target_id: int = eco.state.decorations[0].id
	eco.flip_decoration(target_id)
	assert_true(eco.state.decorations[0].flipped_x)
	assert_false(eco.state.decorations[1].flipped_x)


# --- Event queue actually populated by orchestration calls ---------------------------

func test_has_events_and_pop_event_reflect_a_guard_blocked_call() -> void:
	assert_false(eco.has_events())
	eco.state.coins = 0
	eco.buy_mandi()
	assert_true(eco.has_events())
	var event := eco.pop_event()
	assert_string_contains(event.message, "Mandi")
	assert_false(eco.has_events())
