## Covers the two persistence-related bugfixes documented in game_economy.gd's
## class doc and game_event.gd's header comment:
##   (a) `dirty` is only set true by mutations that actually change state --
##       resolve_growth_completions() must NOT mark dirty on a call where no
##       plot transitions, so a 1Hz autosave loop isn't forced to write to
##       disk every second regardless of whether anything actually changed
##       (the Kotlin original's unconditional-persist bug).
##   (b) `pending_events` is a real FIFO queue -- multiple events produced
##       before the UI drains them must all survive, not silently overwrite
##       down to just the last one (the Kotlin original's single-slot
##       `MutableStateFlow<GameEvent?>` bug).
extends GutTest

const NOW_QUIET: int = 10_000_000

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000


# --- Bugfix (a): dirty flag -----------------------------------------------------

func test_dirty_starts_false_on_a_fresh_economy() -> void:
	assert_false(eco.dirty)


func test_dirty_set_true_by_a_successful_mutation() -> void:
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	assert_true(eco.dirty)


func test_dirty_not_set_by_a_guard_blocked_mutation() -> void:
	# Insufficient funds -- plant_seed pushes an event and returns before
	# _mark_dirty() ever runs.
	eco.state.coins = 0
	eco.plant_seed(eco.state.plots[0].id, CropType.Kind.WHEAT, NOW_QUIET)
	assert_false(eco.dirty)


func test_resolve_growth_completions_does_not_mark_dirty_when_nothing_is_growing() -> void:
	# No plots are Growing at all -- the common "just ticked, nothing to do"
	# case a 1Hz loop hits most of the time.
	assert_false(eco.dirty)
	eco.resolve_growth_completions(NOW_QUIET)
	assert_false(eco.dirty)


func test_resolve_growth_completions_does_not_mark_dirty_before_grow_time_elapses() -> void:
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)  # Wheat: 120s grow time.
	eco.dirty = false  # plant_seed already marked it -- reset to isolate this call.
	eco.resolve_growth_completions(NOW_QUIET + 60 * 1000)  # Only 60s elapsed.
	assert_eq(plot.state.kind, PlotState.Kind.GROWING)
	assert_false(eco.dirty)


func test_resolve_growth_completions_marks_dirty_only_when_a_plot_actually_transitions() -> void:
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	eco.dirty = false
	eco.resolve_growth_completions(NOW_QUIET + 121 * 1000)  # Elapsed.
	assert_eq(plot.state.kind, PlotState.Kind.READY_TO_HARVEST)
	assert_true(eco.dirty)


func test_resolve_growth_completions_called_twice_only_marks_dirty_on_the_transitioning_call() -> void:
	# Regression shape for the original bug: call resolve_growth_completions
	# repeatedly (as a 1Hz loop would) and confirm dirty only flips true on
	# the one call where a plot actually finishes growing.
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	eco.dirty = false

	eco.resolve_growth_completions(NOW_QUIET + 30 * 1000)
	assert_false(eco.dirty, "no transition yet -- must stay clean")

	eco.resolve_growth_completions(NOW_QUIET + 121 * 1000)
	assert_true(eco.dirty, "plot transitioned -- must become dirty")


# --- Bugfix (b): pending_events FIFO queue --------------------------------------

func test_has_events_false_on_a_fresh_economy() -> void:
	assert_false(eco.has_events())


func test_pop_event_on_an_empty_queue_returns_null() -> void:
	assert_null(eco.pop_event())


func test_multiple_events_pushed_before_draining_all_survive() -> void:
	# Two independently-triggered guard failures, each pushing one event
	# before either is drained -- the Kotlin original's single-slot
	# MutableStateFlow would have silently discarded the first one here.
	eco.state.coins = 0
	eco.buy_farmhouse_upgrade()  # Pushes "Need ₹2000 to upgrade to Kutcha House."
	eco.buy_land_expansion()  # Pushes "Need ₹150 to expand your land."

	var first := eco.pop_event()
	var second := eco.pop_event()
	assert_not_null(first)
	assert_not_null(second)
	assert_ne(first.message, second.message)
	assert_string_contains(first.message, "upgrade")
	assert_string_contains(second.message, "expand")


func test_pending_events_pop_in_fifo_order_across_three_pushes() -> void:
	eco.state.coins = 0
	eco.buy_farmhouse_upgrade()
	eco.buy_land_expansion()
	eco.buy_polyhouse()

	var messages: Array[String] = []
	while eco.has_events():
		messages.append(eco.pop_event().message)

	assert_eq(messages.size(), 3)
	# FIFO: farmhouse's message must come out before land expansion's, which
	# must come out before polyhouse's -- push order preserved end to end.
	assert_string_contains(messages[0], "upgrade")
	assert_string_contains(messages[1], "expand")
	assert_string_contains(messages[2], "Polyhouse")


func test_pop_event_removes_the_event_from_the_queue() -> void:
	eco.state.coins = 0
	eco.buy_farmhouse_upgrade()
	assert_true(eco.has_events())
	eco.pop_event()
	assert_false(eco.has_events())
