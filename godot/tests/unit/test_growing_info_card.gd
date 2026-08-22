## Covers GrowingInfoCard's grow-time-skip button (feature-scoping-2026-
## 08-22.md item 2's second gems sink) -- verifies the actual node tree
## the card builds, not just that the code compiles. Complements the
## economy-layer tests in test_gems_daily_tasks.gd, which cover
## skip_grow_time()/can_skip_grow_time() directly; this file covers the
## one thing those can't reach: does GrowingInfoCard actually build a
## Skip button with the right text/enabled state, and does pressing the
## real Button node (not calling the economy method directly) produce
## the same real end-to-end result a live tap would.
##
## Written specifically to close the on-device visual-confirmation gap
## gems-second-sink.md's Acceptance Criteria flagged as still open --
## repeated real-device friction (screen lock, imprecise tap-targeting
## on the isometric board) meant that gap couldn't be closed live; this
## is the more reliable alternative that actually can run right now.
extends GutTest

const GrowingInfoCardScene := preload("res://scenes/ui/growing_info_card.tscn")
const VillageBoardScene := preload("res://scenes/village_board/village_board.tscn")
const BottomSheetScene := preload("res://scenes/ui/bottom_sheet.tscn")


func _find_button_with_text(node: Node, substring: String) -> Button:
	if node is Button and (node as Button).text.contains(substring):
		return node
	for child in node.get_children():
		var found := _find_button_with_text(child, substring)
		if found:
			return found
	return null


## Defensively normalize first: every test here drives a VillageBoard's
## own SaveSystem-loaded economy, and this class of test genuinely writes
## to that same persisted user://save.tres (test_pressing_the_real_
## skip_button_... presses a real button that calls
## persist_and_rebuild_if_dirty()) -- without this reset, a PRIOR test's
## real write could leave grow_skip_used_today=true on disk, making a
## LATER "fresh" test flaky depending on run order. Same class of bug
## already caught once this session for worker assignments (see
## test_village_snapshot_mapper.gd's own "Defensively normalize first"
## comment) -- test-standards.md's "tests must not depend on execution
## order" rule, applied here too.
func _reset_grow_skip_cap(economy: GameEconomy) -> void:
	economy.state.grow_skip_day_key = -1
	economy.state.grow_skip_used_today = false


## Same "prior persisted save could leave real state behind" risk as
## _reset_grow_skip_cap() above, for the specific plot each test plants
## into -- plant_seed() silently no-ops on a non-EMPTY plot, so a
## leftover GROWING/READY_TO_HARVEST plot from an earlier test's real
## write would otherwise make that test's own "GROWING plot" precondition
## silently false.
func _reset_plot_to_empty(economy: GameEconomy, plot_id: int) -> void:
	for plot: Plot in economy.state.plots:
		if plot.id == plot_id:
			plot.state = PlotState.new_empty()
			return


func test_card_shows_no_skip_button_without_full_context() -> void:
	# configure()'s economy/village_board/bottom_sheet default to null --
	# must not attempt to build the button at all in that shape.
	var card: GrowingInfoCard = add_child_autofree(GrowingInfoCardScene.instantiate())
	card.configure(-1, CropType.Kind.WHEAT)
	assert_null(_find_button_with_text(card, "Skip"))


func test_card_shows_an_enabled_skip_button_with_full_context() -> void:
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	var economy := board.get_economy()
	_reset_grow_skip_cap(economy)
	var plot_id := economy.state.plots[0].id
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	_reset_plot_to_empty(economy, plot_id)
	economy.plant_seed(plot_id, CropType.Kind.WHEAT, now)
	# Set gems AFTER plant_seed() -- plant_seed() bumps the PLANT daily task
	# (game_economy.gd's _bump_daily_task_progress()), which can itself award
	# gems depending on which 3 tasks today's real day_key happened to pick.
	# Assigning here, last, keeps the test's intended gems value the one
	# that's actually in effect when the button gets built, regardless of
	# that real-calendar-dependent side effect. Found via a real, reproducible
	# test failure this session (see test-standards.md's "must not depend on
	# execution order" -- this was really "must not depend on the calendar").
	economy.state.gems = GameData.GROW_SKIP_COST_GEMS
	var sheet: BottomSheet = add_child_autofree(BottomSheetScene.instantiate())

	var card: GrowingInfoCard = add_child_autofree(GrowingInfoCardScene.instantiate())
	card.configure(plot_id, CropType.Kind.WHEAT, economy, board, sheet)

	var button := _find_button_with_text(card, "Skip")
	assert_not_null(button, "GrowingInfoCard must build a Skip button when given full context and enough gems")
	assert_false(button.disabled, "enough gems, plot growing, cap not used -- button must be enabled")
	assert_true(button.text.contains(str(GameData.GROW_SKIP_COST_GEMS)), "button text must show the real gem cost, not a hardcoded placeholder")


func test_skip_button_is_disabled_with_insufficient_gems() -> void:
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	var economy := board.get_economy()
	_reset_grow_skip_cap(economy)
	var plot_id := economy.state.plots[0].id
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	_reset_plot_to_empty(economy, plot_id)
	economy.plant_seed(plot_id, CropType.Kind.WHEAT, now)
	# Set gems AFTER plant_seed() -- see the same-shaped comment in
	# test_card_shows_an_enabled_skip_button_with_full_context() above.
	economy.state.gems = GameData.GROW_SKIP_COST_GEMS - 1
	var sheet: BottomSheet = add_child_autofree(BottomSheetScene.instantiate())

	var card: GrowingInfoCard = add_child_autofree(GrowingInfoCardScene.instantiate())
	card.configure(plot_id, CropType.Kind.WHEAT, economy, board, sheet)

	var button := _find_button_with_text(card, "Skip")
	assert_not_null(button, "the button must still exist, just disabled -- not hidden entirely")
	assert_true(button.disabled)


func test_skip_button_is_disabled_after_the_daily_cap_is_used() -> void:
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	var economy := board.get_economy()
	_reset_grow_skip_cap(economy)
	var plot_id := economy.state.plots[0].id
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	_reset_plot_to_empty(economy, plot_id)
	economy.plant_seed(plot_id, CropType.Kind.WHEAT, now)
	# Set gems AFTER both plant_seed() calls -- see the same-shaped comment in
	# test_card_shows_an_enabled_skip_button_with_full_context() above.
	economy.state.gems = GameData.GROW_SKIP_COST_GEMS * 2
	economy.skip_grow_time(plot_id, now)  # uses today's one skip
	var second_plot_id := economy.state.plots[1].id
	_reset_plot_to_empty(economy, second_plot_id)
	economy.plant_seed(second_plot_id, CropType.Kind.WHEAT, now)
	var sheet: BottomSheet = add_child_autofree(BottomSheetScene.instantiate())

	var card: GrowingInfoCard = add_child_autofree(GrowingInfoCardScene.instantiate())
	card.configure(second_plot_id, CropType.Kind.WHEAT, economy, board, sheet)

	var button := _find_button_with_text(card, "Skip")
	assert_not_null(button)
	assert_true(button.disabled, "today's cap is already used -- must be disabled even with plenty of gems left")


func test_pressing_the_real_skip_button_spends_gems_and_resolves_the_plot() -> void:
	# The real end-to-end proof, driven through the actual Button node a
	# live tap would activate -- not calling skip_grow_time() directly
	# like test_gems_daily_tasks.gd already does.
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	var economy := board.get_economy()
	_reset_grow_skip_cap(economy)
	var plot_id := economy.state.plots[0].id
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	_reset_plot_to_empty(economy, plot_id)
	economy.plant_seed(plot_id, CropType.Kind.WHEAT, now)
	# Set gems AFTER plant_seed() -- plant_seed() bumps the PLANT daily task
	# (game_economy.gd's _bump_daily_task_progress()), which can itself award
	# gems depending on which 3 tasks today's real day_key happened to pick.
	# Assigning here, last, keeps the test's intended gems value the one
	# that's actually in effect when the button gets pressed, regardless of
	# that real-calendar-dependent side effect. Found via a real, reproducible
	# test failure this session (see test-standards.md's "must not depend on
	# execution order" -- this was really "must not depend on the calendar").
	economy.state.gems = GameData.GROW_SKIP_COST_GEMS
	var sheet: BottomSheet = add_child_autofree(BottomSheetScene.instantiate())

	var card: GrowingInfoCard = GrowingInfoCardScene.instantiate()
	card.configure(plot_id, CropType.Kind.WHEAT, economy, board, sheet)
	sheet.open(card)
	var button := _find_button_with_text(card, "Skip")
	assert_not_null(button, "precondition: the button must exist before this test can press it")

	button.pressed.emit()

	assert_eq(economy.state.gems, 0, "the real button press must spend gems through skip_grow_time(), not a stub")
	var plot: Plot = null
	for p: Plot in economy.state.plots:
		if p.id == plot_id:
			plot = p
	assert_eq(plot.state.kind, PlotState.Kind.READY_TO_HARVEST, "the real button press must resolve the plot, matching _on_skip_pressed()'s own immediate resolve_growth_completions() call")
	assert_eq(sheet.get_state(), BottomSheet.State.CLOSED, "a successful skip must close the sheet, matching _on_skip_pressed()'s own behavior")
