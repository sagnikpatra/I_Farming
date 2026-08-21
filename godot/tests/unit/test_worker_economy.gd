## Covers design/gdd/worker-economy.md (EPIC-M7): worker assignment,
## eligibility, and the lazy harvest-and-replant automation cycle,
## including every edge case confirmed 2026-08-21 in that document's §5.
extends GutTest

## Same "quiet" timestamp test_crop_economy.gd uses -- outside both
## Monsoon's and Festival's active windows, so baseline tests aren't
## accidentally perturbed by either LiveOps system.
const NOW_QUIET: int = 10_000_000

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000


# --- Assignment ---------------------------------------------------------------

func test_assign_worker_records_the_assignment() -> void:
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")

	assert_true(eco.has_worker_assigned(PlotKind.Kind.OPEN_FIELD))
	assert_eq(eco.get_worker_assignment(PlotKind.Kind.OPEN_FIELD).character_key, "ranger")


func test_assign_worker_rejects_agroforestry() -> void:
	# Sandalwood planting goes through plant_host()/plant_sandalwood()'s
	# adjacency puzzle, not plant_seed() -- no "replant the same crop" to
	# automate there. See game_economy.gd's _WORKER_ELIGIBLE_PLOT_KINDS.
	eco.assign_worker(PlotKind.Kind.AGROFORESTRY, "ranger")

	assert_false(eco.has_worker_assigned(PlotKind.Kind.AGROFORESTRY))


func test_assign_worker_rejects_a_not_yet_unlocked_zone() -> void:
	# Found while writing this feature's own test suite (see
	# game_economy.gd's assign_worker() comment): the first version had no
	# zone-unlock check at all -- Polyhouse would have accepted an
	# assignment before the player ever built one.
	eco.assign_worker(PlotKind.Kind.POLYHOUSE, "ranger")

	assert_false(eco.has_worker_assigned(PlotKind.Kind.POLYHOUSE))


func test_assign_worker_accepts_a_zone_once_unlocked() -> void:
	eco.buy_polyhouse()

	eco.assign_worker(PlotKind.Kind.POLYHOUSE, "ranger")

	assert_true(eco.has_worker_assigned(PlotKind.Kind.POLYHOUSE))


func test_assign_worker_accepts_open_field_with_no_unlock_needed() -> void:
	# OPEN_FIELD has no has_* flag -- available from the start of the game.
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")

	assert_true(eco.has_worker_assigned(PlotKind.Kind.OPEN_FIELD))


func test_is_plot_kind_worker_eligible_matches_the_confirmed_scope() -> void:
	assert_true(eco.is_plot_kind_worker_eligible(PlotKind.Kind.OPEN_FIELD))
	assert_true(eco.is_plot_kind_worker_eligible(PlotKind.Kind.POLYHOUSE))
	assert_true(eco.is_plot_kind_worker_eligible(PlotKind.Kind.AQUACULTURE))
	assert_true(eco.is_plot_kind_worker_eligible(PlotKind.Kind.VERTICAL_FARM))
	assert_false(eco.is_plot_kind_worker_eligible(PlotKind.Kind.AGROFORESTRY))


func test_assign_worker_replaces_an_existing_assignment() -> void:
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")

	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "knight")

	assert_eq(eco.get_worker_assignment(PlotKind.Kind.OPEN_FIELD).character_key, "knight")


func test_unassign_worker_removes_the_assignment() -> void:
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")

	eco.unassign_worker(PlotKind.Kind.OPEN_FIELD)

	assert_false(eco.has_worker_assigned(PlotKind.Kind.OPEN_FIELD))


func test_unassign_worker_on_an_unassigned_plot_kind_is_a_safe_no_op() -> void:
	eco.unassign_worker(PlotKind.Kind.OPEN_FIELD)

	assert_false(eco.has_worker_assigned(PlotKind.Kind.OPEN_FIELD))


# --- Automation: happy path ----------------------------------------------------

func test_resolve_worker_actions_harvests_and_replants_a_ready_plot() -> void:
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	eco.resolve_growth_completions(NOW_QUIET + 200 * 1000)
	assert_eq(plot.state.kind, PlotState.Kind.READY_TO_HARVEST)
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")

	eco.resolve_worker_actions(NOW_QUIET + 200 * 1000)

	assert_eq(plot.state.kind, PlotState.Kind.GROWING, "should have replanted the same crop")
	assert_eq(plot.state.crop, CropType.Kind.WHEAT)
	var stock: CropStock = eco.state.inventory.get(CropType.Kind.WHEAT)
	assert_not_null(stock)
	assert_eq(stock.total, 1, "the harvested unit should be in inventory")


func test_resolve_worker_actions_charges_the_wage() -> void:
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	eco.resolve_growth_completions(NOW_QUIET + 200 * 1000)
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")
	var coins_before_cycle := eco.state.coins

	eco.resolve_worker_actions(NOW_QUIET + 200 * 1000)

	# Wheat: base_sell_price=20 -> wage = round(20*0.15) = 3. Replant costs
	# Wheat's seed_cost=10. Net change = -3 (wage) - 10 (replant) = -13.
	assert_eq(eco.state.coins, coins_before_cycle - 3 - 10)


func test_worker_wage_formula_matches_fifteen_percent_min_one() -> void:
	# design/gdd/worker-economy.md §4: 15% of base_sell_price, min ₹1.
	# Wheat's base_sell_price=20 -> round(20*0.15) = round(3.0) = 3, well
	# above the ₹1 floor -- this test only covers the formula's normal
	# case; the floor itself would need a crop worth ~₹0-6 to exercise,
	# and none of this game's crops are priced that low.
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	eco.resolve_growth_completions(NOW_QUIET + 200 * 1000)
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")
	var coins_before_cycle := eco.state.coins

	eco.resolve_worker_actions(NOW_QUIET + 200 * 1000)

	var coins_after_wage_only := coins_before_cycle - 3  # before the replant's seed_cost
	assert_true(eco.state.coins <= coins_after_wage_only, "wage alone should already account for at least ₹3 of the change")


func test_resolve_worker_actions_ignores_unassigned_plot_kinds() -> void:
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	eco.resolve_growth_completions(NOW_QUIET + 200 * 1000)
	assert_eq(plot.state.kind, PlotState.Kind.READY_TO_HARVEST)
	# Deliberately no assign_worker() call.

	eco.resolve_worker_actions(NOW_QUIET + 200 * 1000)

	assert_eq(plot.state.kind, PlotState.Kind.READY_TO_HARVEST, "no worker assigned -- nothing should be automated")


func test_resolve_worker_actions_processes_every_ready_plot_in_the_assigned_zone() -> void:
	var plot_a: Plot = eco.state.plots[0]
	var plot_b: Plot = eco.state.plots[1]
	eco.plant_seed(plot_a.id, CropType.Kind.WHEAT, NOW_QUIET)
	eco.plant_seed(plot_b.id, CropType.Kind.WHEAT, NOW_QUIET)
	eco.resolve_growth_completions(NOW_QUIET + 200 * 1000)
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")

	eco.resolve_worker_actions(NOW_QUIET + 200 * 1000)

	assert_eq(plot_a.state.kind, PlotState.Kind.GROWING)
	assert_eq(plot_b.state.kind, PlotState.Kind.GROWING)
	assert_eq(eco.state.inventory.get(CropType.Kind.WHEAT).total, 2)


# --- Automation: confirmed edge cases (design/gdd/worker-economy.md §5) --------

func test_resolve_worker_actions_skips_when_inventory_full_no_wage_charged() -> void:
	# Level 0 storage capacity is 50 (same fixture value test_crop_economy.gd
	# uses) -- fill it exactly, matching that file's own pattern.
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(50, 0)
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	eco.resolve_growth_completions(NOW_QUIET + 200 * 1000)
	assert_eq(plot.state.kind, PlotState.Kind.READY_TO_HARVEST)
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")
	var coins_before := eco.state.coins

	eco.resolve_worker_actions(NOW_QUIET + 200 * 1000)

	assert_eq(plot.state.kind, PlotState.Kind.READY_TO_HARVEST, "should skip, not harvest, while inventory is full")
	assert_eq(eco.state.coins, coins_before, "no wage should be charged when no work was done")


func test_resolve_worker_actions_harvests_but_leaves_plot_empty_when_cant_afford_replant() -> void:
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)  # costs seed_cost=10 while coins are still high
	eco.resolve_growth_completions(NOW_QUIET + 200 * 1000)
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")
	# Wage will be 3; leaves 2 coins after the harvest, less than Wheat's
	# seed_cost=10 -- can't afford the replant.
	eco.state.coins = 5

	eco.resolve_worker_actions(NOW_QUIET + 200 * 1000)

	assert_eq(plot.state.kind, PlotState.Kind.EMPTY, "should harvest but not replant")
	assert_eq(eco.state.inventory.get(CropType.Kind.WHEAT).total, 1, "the harvest itself should still have happened")
	assert_eq(eco.state.coins, 2, "wage (3) should still be charged even though the replant was skipped")


func test_resolve_worker_actions_charges_half_wage_on_a_damaged_spoiled_harvest() -> void:
	# Balance fix regression (2026-08-21 /balance-check pass, design/gdd/
	# worker-economy.md §4/§7): a worker's wage must scale down the same way
	# sell_crop()'s realized value does for a damaged harvest -- previously
	# it always charged the undamaged rate even when the crop itself sold
	# for half, effectively doubling the worker's real cut on any damaged
	# cycle (a direct contradiction of §5's "only charge for value actually
	# delivered" principle). Uses Polyhouse spoilage (deterministic --
	# harvest past the grace window) rather than the Open-Field weather
	# roll, which is unseeded/flaky per test standards -- see
	# test_land_structures.gd's identical substitution for the same reason.
	eco.buy_polyhouse()
	var polyhouse_plot: Plot = null
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.POLYHOUSE:
			polyhouse_plot = p
			break
	eco.plant_seed(polyhouse_plot.id, CropType.Kind.CAPSICUM, NOW_QUIET)
	eco.resolve_growth_completions(NOW_QUIET + polyhouse_plot.state.effective_grow_seconds * 1000)
	assert_eq(polyhouse_plot.state.kind, PlotState.Kind.READY_TO_HARVEST)
	var ready_at: int = polyhouse_plot.state.ready_at_epoch_ms
	eco.assign_worker(PlotKind.Kind.POLYHOUSE, "ranger")
	var coins_before := eco.state.coins

	# Base grace is 4h (no Drip Irrigation bought) -- 5h past ready arrives spoiled.
	eco.resolve_worker_actions(ready_at + 5 * 60 * 60 * 1000)

	var stock: CropStock = eco.state.inventory[CropType.Kind.CAPSICUM]
	assert_eq(stock.damaged, 1, "sanity check -- this harvest must actually be damaged for the test to mean anything")
	# Capsicum base_sell_price=650, seed_cost=150. Damaged wage =
	# round(650 * 0.5 * 0.15) = round(48.75) = 49 -- half of the undamaged
	# round(650 * 0.15) = 98, not the undamaged rate.
	assert_eq(coins_before - eco.state.coins, 49 + 150, "wage on a damaged harvest should be ~half the undamaged rate")


func test_resolve_worker_actions_pauses_saffron_replant_when_electricity_has_lapsed() -> void:
	eco.buy_vertical_farm()
	eco.renew_electricity(NOW_QUIET)
	var vertical_farm_plot: Plot = null
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.VERTICAL_FARM:
			vertical_farm_plot = p
			break
	assert_not_null(vertical_farm_plot)

	eco.plant_seed(vertical_farm_plot.id, CropType.Kind.SAFFRON, NOW_QUIET)
	var ready_at: int = NOW_QUIET + vertical_farm_plot.state.effective_grow_seconds * 1000
	eco.resolve_growth_completions(ready_at)
	assert_eq(vertical_farm_plot.state.kind, PlotState.Kind.READY_TO_HARVEST)
	eco.assign_worker(PlotKind.Kind.VERTICAL_FARM, "ranger")

	# Electricity renews for GameData.ELECTRICITY_DURATION_MS (2 days) --
	# comfortably longer than Saffron's own grow time, so it's still active
	# at ready_at. Resolve the worker cycle well past electricity's actual
	# expiry instead, so it has genuinely lapsed by the time the worker
	# would replant.
	var electricity_lapsed_at: int = NOW_QUIET + GameData.ELECTRICITY_DURATION_MS + 1

	eco.resolve_worker_actions(electricity_lapsed_at)

	assert_eq(vertical_farm_plot.state.kind, PlotState.Kind.EMPTY, "should harvest but not start a new Saffron cycle without power")
	assert_eq(eco.state.inventory.get(CropType.Kind.SAFFRON).total, 1, "the harvest itself is unaffected by an already-lapsed credit")
