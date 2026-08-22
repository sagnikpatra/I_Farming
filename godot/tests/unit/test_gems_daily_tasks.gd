## Covers GameEconomy's Gems & Daily Tasks system (design/gdd/gems-daily-
## tasks.md) -- the project's first real-calendar-day-anchored LiveOps
## system. Mirrors this file's sibling test files' before_each/NOW_QUIET
## shape.
extends GutTest

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000


## Forces today's task set directly (bypassing the RNG pick) so hook-point
## tests don't need to predict what the seeded selection would produce --
## day_key is still computed via the real _current_local_day_key(now), so
## _with_fresh_daily_tasks() correctly treats this as "already fresh" and
## won't overwrite it.
func _set_todays_tasks(now: int, kinds: Array[int]) -> void:
	eco.state.daily_task_day_key = eco._current_local_day_key(now)
	eco.state.daily_task_kinds = kinds
	eco.state.daily_task_progress = {}
	eco.state.daily_task_claimed = {}
	eco.state.daily_task_bonus_claimed = false


# --- local_day_key() -- pure function, explicit inputs only --------------------

func test_local_day_key_stable_within_the_same_local_day() -> void:
	# 2026-08-22 00:00:00 UTC and 2026-08-22 23:00:00 UTC, timezone offset 0.
	var midnight_ms: int = 1787356800000  # 2026-08-22T00:00:00Z (unix seconds * 1000)
	var late_same_day_ms: int = midnight_ms + 23 * 60 * 60 * 1000
	var key_a := GameEconomy.local_day_key(midnight_ms, 0)
	var key_b := GameEconomy.local_day_key(late_same_day_ms, 0)
	assert_eq(key_a, key_b)


func test_local_day_key_changes_across_a_real_day_boundary() -> void:
	var midnight_ms: int = 1787356800000  # 2026-08-22T00:00:00Z
	var next_day_ms: int = midnight_ms + 24 * 60 * 60 * 1000
	var key_a := GameEconomy.local_day_key(midnight_ms, 0)
	var key_b := GameEconomy.local_day_key(next_day_ms, 0)
	assert_ne(key_a, key_b)


func test_local_day_key_shifts_with_timezone_offset() -> void:
	# 23:30 UTC on 2026-08-22 is still 2026-08-22 at UTC, but already
	# 2026-08-23 at UTC+1 (60 min offset).
	var late_utc_ms: int = 1787356800000 + 23 * 60 * 60 * 1000 + 30 * 60 * 1000
	var key_utc := GameEconomy.local_day_key(late_utc_ms, 0)
	var key_utc_plus_1 := GameEconomy.local_day_key(late_utc_ms, 60)
	assert_ne(key_utc, key_utc_plus_1)


# --- Task selection (_pick_daily_task_kinds) ------------------------------------

func test_pick_daily_task_kinds_returns_exactly_3_distinct_kinds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260822
	var kinds := GameEconomy._pick_daily_task_kinds(rng)
	assert_eq(kinds.size(), GameData.DAILY_TASKS_PER_DAY)
	var unique: Dictionary = {}
	for k in kinds:
		unique[k] = true
	assert_eq(unique.size(), kinds.size())


func test_pick_daily_task_kinds_is_deterministic_for_the_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 20260822
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 20260822
	assert_eq(GameEconomy._pick_daily_task_kinds(rng_a), GameEconomy._pick_daily_task_kinds(rng_b))


# --- Day rollover -----------------------------------------------------------------

func test_fresh_daily_tasks_generates_3_kinds_on_first_call() -> void:
	eco._with_fresh_daily_tasks(1787356800000)
	assert_eq(eco.state.daily_task_kinds.size(), GameData.DAILY_TASKS_PER_DAY)
	assert_ne(eco.state.daily_task_day_key, -1)


func test_fresh_daily_tasks_does_not_regenerate_within_the_same_day() -> void:
	eco._with_fresh_daily_tasks(1787356800000)
	var kinds_before := eco.state.daily_task_kinds.duplicate()
	eco._with_fresh_daily_tasks(1787356800000 + 60_000)
	assert_eq(eco.state.daily_task_kinds, kinds_before)


func test_daily_tasks_state_preview_does_not_mutate_real_state() -> void:
	assert_eq(eco.state.daily_task_day_key, -1)
	eco.daily_tasks_state_preview(1787356800000)
	assert_eq(eco.state.daily_task_day_key, -1)


# --- Hook points: progress increments correctly, and only for today's kinds ----

func test_harvest_bumps_the_harvest_task_when_its_todays_pick() -> void:
	var now: int = 1787356800000
	_set_todays_tasks(now, [DailyTaskKind.Kind.HARVEST])
	var plot: Plot = eco.state.plots[0]
	plot.state = PlotState.new_ready(CropType.Kind.WHEAT, false, now)
	eco.harvest_plot(plot.id, now)
	assert_eq(eco.state.daily_task_progress.get(DailyTaskKind.Kind.HARVEST, 0), 1)


func test_harvest_does_not_bump_a_task_kind_not_among_todays_picks() -> void:
	var now: int = 1787356800000
	_set_todays_tasks(now, [DailyTaskKind.Kind.PLANT, DailyTaskKind.Kind.SELL, DailyTaskKind.Kind.WORKER])
	var plot: Plot = eco.state.plots[0]
	plot.state = PlotState.new_ready(CropType.Kind.WHEAT, false, now)
	eco.harvest_plot(plot.id, now)
	assert_false(eco.state.daily_task_progress.has(DailyTaskKind.Kind.HARVEST))


func test_plant_seed_bumps_the_plant_task() -> void:
	var now: int = 1787356800000
	_set_todays_tasks(now, [DailyTaskKind.Kind.PLANT])
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, now)
	assert_eq(eco.state.daily_task_progress.get(DailyTaskKind.Kind.PLANT, 0), 1)


func test_sell_crop_bumps_both_sell_and_earn_tasks() -> void:
	var now: int = 1787356800000
	_set_todays_tasks(now, [DailyTaskKind.Kind.SELL, DailyTaskKind.Kind.EARN])
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(10, 0)
	eco.sell_crop(CropType.Kind.WHEAT, now)
	assert_eq(eco.state.daily_task_progress.get(DailyTaskKind.Kind.SELL, 0), 1)
	assert_gt(eco.state.daily_task_progress.get(DailyTaskKind.Kind.EARN, 0), 0)


func test_worker_cycle_bumps_the_worker_task() -> void:
	var now: int = 1787356800000
	_set_todays_tasks(now, [DailyTaskKind.Kind.WORKER])
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")
	var plot: Plot = eco.state.plots[0]
	assert_eq(plot.kind, PlotKind.Kind.OPEN_FIELD)
	plot.state = PlotState.new_ready(CropType.Kind.WHEAT, false, now)
	eco.resolve_worker_actions(now)
	assert_eq(eco.state.daily_task_progress.get(DailyTaskKind.Kind.WORKER, 0), 1)


# --- Gem rewards -------------------------------------------------------------------

func test_task_auto_awards_gems_exactly_when_target_is_reached() -> void:
	var now: int = 1787356800000
	var task_def := GameData.daily_task_def_for_kind(DailyTaskKind.Kind.PLANT)
	# 3 picks, only PLANT gets completed -- keeps the all-3-bonus from
	# firing so this test isolates PLANT's own reward.
	_set_todays_tasks(now, [DailyTaskKind.Kind.PLANT, DailyTaskKind.Kind.HARVEST, DailyTaskKind.Kind.SELL])
	var gems_before := eco.state.gems
	for i in range(task_def.target):
		eco.plant_seed(eco.state.plots[0].id, CropType.Kind.WHEAT, now)
		# plots[0] is now Growing after the first plant -- keep re-emptying it
		# so plant_seed() succeeds every iteration (only successful plants
		# should count).
		eco.state.plots[0].state = PlotState.new_empty()
	assert_eq(eco.state.gems, gems_before + task_def.gem_reward)
	assert_true(eco.state.daily_task_claimed.get(DailyTaskKind.Kind.PLANT, false))
	assert_false(eco.state.daily_task_bonus_claimed)


func test_task_does_not_double_award_gems_past_its_target() -> void:
	var now: int = 1787356800000
	var task_def := GameData.daily_task_def_for_kind(DailyTaskKind.Kind.PLANT)
	_set_todays_tasks(now, [DailyTaskKind.Kind.PLANT, DailyTaskKind.Kind.HARVEST, DailyTaskKind.Kind.SELL])
	for i in range(task_def.target + 3):
		eco.plant_seed(eco.state.plots[0].id, CropType.Kind.WHEAT, now)
		eco.state.plots[0].state = PlotState.new_empty()
	assert_eq(eco.state.gems, task_def.gem_reward)


func test_all_three_tasks_complete_awards_the_bonus_once() -> void:
	var now: int = 1787356800000
	_set_todays_tasks(now, [DailyTaskKind.Kind.HARVEST, DailyTaskKind.Kind.PLANT, DailyTaskKind.Kind.SELL])
	var harvest_target := GameData.daily_task_def_for_kind(DailyTaskKind.Kind.HARVEST).target
	var plant_target := GameData.daily_task_def_for_kind(DailyTaskKind.Kind.PLANT).target
	var sell_target := GameData.daily_task_def_for_kind(DailyTaskKind.Kind.SELL).target

	for i in range(harvest_target):
		var plot: Plot = eco.state.plots[0]
		plot.state = PlotState.new_ready(CropType.Kind.WHEAT, false, now)
		eco.harvest_plot(plot.id, now)
	for i in range(plant_target):
		eco.plant_seed(eco.state.plots[1].id, CropType.Kind.WHEAT, now)
		eco.state.plots[1].state = PlotState.new_empty()
	for i in range(sell_target):
		eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(1, 0)
		eco.sell_crop(CropType.Kind.WHEAT, now)

	assert_true(eco.state.daily_task_bonus_claimed)
	var expected_gems: int = (
		GameData.daily_task_def_for_kind(DailyTaskKind.Kind.HARVEST).gem_reward
		+ GameData.daily_task_def_for_kind(DailyTaskKind.Kind.PLANT).gem_reward
		+ GameData.daily_task_def_for_kind(DailyTaskKind.Kind.SELL).gem_reward
		+ GameData.DAILY_TASK_ALL_BONUS_GEMS
	)
	assert_eq(eco.state.gems, expected_gems)


# --- reroll_daily_tasks() -----------------------------------------------------------

func test_reroll_succeeds_and_costs_gems_when_no_progress_made() -> void:
	var now: int = 1787356800000
	_set_todays_tasks(now, [DailyTaskKind.Kind.HARVEST, DailyTaskKind.Kind.PLANT, DailyTaskKind.Kind.SELL])
	eco.state.gems = GameData.DAILY_TASK_REROLL_COST
	eco.reroll_daily_tasks(now)
	assert_eq(eco.state.gems, 0)
	assert_eq(eco.state.daily_task_kinds.size(), GameData.DAILY_TASKS_PER_DAY)


func test_reroll_still_allowed_with_partial_but_incomplete_progress() -> void:
	# PLANT's target is 5 -- one successful plant is partial progress, not
	# completion, so reroll must still be allowed (only a *complete,
	# paid-out* task blocks reroll -- see the GDD's Detailed Rules §3).
	var now: int = 1787356800000
	_set_todays_tasks(now, [DailyTaskKind.Kind.PLANT, DailyTaskKind.Kind.HARVEST, DailyTaskKind.Kind.SELL])
	eco.state.gems = GameData.DAILY_TASK_REROLL_COST
	eco.plant_seed(eco.state.plots[0].id, CropType.Kind.WHEAT, now)
	assert_false(eco.state.daily_task_claimed.get(DailyTaskKind.Kind.PLANT, false))
	eco.reroll_daily_tasks(now)
	assert_eq(eco.state.gems, 0)


func test_reroll_blocked_once_a_task_is_fully_complete() -> void:
	var now: int = 1787356800000
	var task_def := GameData.daily_task_def_for_kind(DailyTaskKind.Kind.PLANT)
	_set_todays_tasks(now, [DailyTaskKind.Kind.PLANT, DailyTaskKind.Kind.HARVEST, DailyTaskKind.Kind.SELL])
	eco.state.gems = GameData.DAILY_TASK_REROLL_COST + task_def.gem_reward
	for i in range(task_def.target):
		eco.plant_seed(eco.state.plots[0].id, CropType.Kind.WHEAT, now)
		eco.state.plots[0].state = PlotState.new_empty()
	assert_true(eco.state.daily_task_claimed.get(DailyTaskKind.Kind.PLANT, false))
	var gems_before := eco.state.gems
	var kinds_before := eco.state.daily_task_kinds.duplicate()
	eco.reroll_daily_tasks(now)
	assert_eq(eco.state.gems, gems_before)
	assert_eq(eco.state.daily_task_kinds, kinds_before)


func test_reroll_blocked_on_insufficient_gems() -> void:
	var now: int = 1787356800000
	_set_todays_tasks(now, [DailyTaskKind.Kind.HARVEST])
	eco.state.gems = GameData.DAILY_TASK_REROLL_COST - 1
	eco.reroll_daily_tasks(now)
	assert_eq(eco.state.gems, GameData.DAILY_TASK_REROLL_COST - 1)


# --- skip_grow_time() -- feature-scoping-2026-08-22.md item 2's second gems sink ------

const ONE_DAY_MS: int = 86_400_000


func test_skip_grow_time_succeeds_and_costs_gems() -> void:
	var now: int = 1787356800000
	eco.state.gems = GameData.GROW_SKIP_COST_GEMS
	var plot_id := eco.state.plots[0].id
	eco.plant_seed(plot_id, CropType.Kind.WHEAT, now)

	eco.skip_grow_time(plot_id, now)

	assert_eq(eco.state.gems, 0)
	assert_true(eco.state.grow_skip_used_today)


func test_skip_grow_time_rewinds_planted_at_so_the_plot_resolves_ready_immediately() -> void:
	# The real end-to-end proof: skip_grow_time() must not itself flip the
	# plot to READY_TO_HARVEST (that stays resolve_growth_completions()'s
	# job, unchanged) -- it must rewind planted_at_epoch_ms far enough that
	# the very next resolve call, at the SAME now, already treats it as
	# complete.
	#
	# This is the only test in the file that actually calls
	# resolve_growth_completions() and asserts the resulting plot kind, so
	# it's the only one exposed to resolve_growth_completions()'s own
	# monsoon-flood roll for OPEN_FIELD plots (an intentionally unseeded
	# RNG -- real gameplay randomness, not something a test should pin a
	# seed to). The fixed `now` above falls within the monsoon window,
	# which made this genuinely flaky (found via a real, reproducible
	# failure this session). has_polyhouse mirrors the game's own escape
	# hatch ("Polyhouse owners are immune") rather than fighting the RNG --
	# this test is about skip_grow_time()'s clock rewind, not monsoon risk.
	var now: int = 1787356800000
	eco.state.has_polyhouse = true
	eco.state.gems = GameData.GROW_SKIP_COST_GEMS
	var plot_id := eco.state.plots[0].id
	eco.plant_seed(plot_id, CropType.Kind.WHEAT, now)
	assert_eq(eco.state.plots[0].state.kind, PlotState.Kind.GROWING)

	eco.skip_grow_time(plot_id, now)
	assert_eq(eco.state.plots[0].state.kind, PlotState.Kind.GROWING, "skip_grow_time() itself must not resolve the plot -- only rewind its clock")

	eco.resolve_growth_completions(now)
	assert_eq(eco.state.plots[0].state.kind, PlotState.Kind.READY_TO_HARVEST)


func test_skip_grow_time_blocked_on_insufficient_gems() -> void:
	var now: int = 1787356800000
	eco.state.gems = GameData.GROW_SKIP_COST_GEMS - 1
	var plot_id := eco.state.plots[0].id
	eco.plant_seed(plot_id, CropType.Kind.WHEAT, now)

	eco.skip_grow_time(plot_id, now)

	assert_eq(eco.state.gems, GameData.GROW_SKIP_COST_GEMS - 1)
	assert_false(eco.state.grow_skip_used_today)
	assert_eq(eco.state.plots[0].state.planted_at_epoch_ms, now)


func test_skip_grow_time_blocked_after_first_use_same_day() -> void:
	var now: int = 1787356800000
	eco.state.gems = GameData.GROW_SKIP_COST_GEMS * 2
	var plot_id := eco.state.plots[0].id
	eco.plant_seed(plot_id, CropType.Kind.WHEAT, now)
	eco.skip_grow_time(plot_id, now)
	var gems_after_first_skip := eco.state.gems

	# Plant again on the same (now-empty, since it wasn't resolved) plot's
	# neighbor to have a second real GROWING target for the blocked attempt.
	var second_plot_id := eco.state.plots[1].id
	eco.plant_seed(second_plot_id, CropType.Kind.WHEAT, now)
	eco.skip_grow_time(second_plot_id, now)

	assert_eq(eco.state.gems, gems_after_first_skip, "second skip attempt same day must not spend gems")
	assert_eq(eco.state.plots[1].state.planted_at_epoch_ms, now, "second plot's clock must be untouched -- the cap blocked the skip")


func test_skip_grow_time_resets_on_a_new_calendar_day() -> void:
	var day_one: int = 1787356800000
	var day_two: int = day_one + ONE_DAY_MS
	eco.state.gems = GameData.GROW_SKIP_COST_GEMS * 2
	var plot_id := eco.state.plots[0].id
	eco.plant_seed(plot_id, CropType.Kind.WHEAT, day_one)
	eco.skip_grow_time(plot_id, day_one)

	var second_plot_id := eco.state.plots[1].id
	eco.plant_seed(second_plot_id, CropType.Kind.WHEAT, day_two)
	eco.skip_grow_time(second_plot_id, day_two)

	assert_eq(eco.state.gems, 0, "a fresh day must allow a second skip, spending gems again")
	assert_ne(eco.state.plots[1].state.planted_at_epoch_ms, day_two, "day two's skip must have actually rewound the clock")


func test_skip_grow_time_does_nothing_for_a_non_growing_plot() -> void:
	var now: int = 1787356800000
	eco.state.gems = GameData.GROW_SKIP_COST_GEMS
	var plot_id := eco.state.plots[0].id
	assert_eq(eco.state.plots[0].state.kind, PlotState.Kind.EMPTY)

	eco.skip_grow_time(plot_id, now)

	assert_eq(eco.state.gems, GameData.GROW_SKIP_COST_GEMS, "nothing growing there -- gems must not be spent")
	assert_false(eco.state.grow_skip_used_today)


func test_can_skip_grow_time_reflects_insufficient_gems() -> void:
	var now: int = 1787356800000
	eco.state.gems = GameData.GROW_SKIP_COST_GEMS - 1
	assert_false(eco.can_skip_grow_time(now))


func test_can_skip_grow_time_reflects_the_daily_cap_without_mutating_state() -> void:
	var now: int = 1787356800000
	eco.state.gems = GameData.GROW_SKIP_COST_GEMS * 2
	var plot_id := eco.state.plots[0].id
	eco.plant_seed(plot_id, CropType.Kind.WHEAT, now)
	assert_true(eco.can_skip_grow_time(now))

	eco.skip_grow_time(plot_id, now)

	assert_false(eco.can_skip_grow_time(now))
	# The read-only check itself must never have consumed the cap on its
	# own -- confirmed by the fact skip_grow_time() above still worked
	# once, which would have failed if an earlier can_skip_grow_time()
	# call in this test had already marked it used.
	assert_true(eco.state.grow_skip_used_today, "skip_grow_time() above is what set this, not can_skip_grow_time()'s own reads")
