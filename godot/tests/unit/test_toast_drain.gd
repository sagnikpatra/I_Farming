## GameEvent snackbar/toast drain (docs/architecture/localization-pipeline.md's
## Related section) -- covers two layers: (1) GameEconomy's real
## `is_rejection` classification on actual blocked/successful actions (not
## a synthetic message), and (2) hud.gd's drain actually moving those real
## events into its toast queue and showing the right text. Node
## construction/layout/styling itself stays untested here, per test_hud.gd's
## own stated policy for this file's sibling -- only the LOGIC (does the
## right text end up in the toast, is the queue behavior correct) is
## covered, not pixel positions/colors.
extends GutTest

const VillageBoardScene := preload("res://scenes/village_board/village_board.tscn")
const HudScene := preload("res://scenes/ui/hud.tscn")


# ---------------------------------------------------------------------------
# GameEconomy: real is_rejection classification
# ---------------------------------------------------------------------------

func test_a_blocked_purchase_is_classified_as_a_rejection() -> void:
	var economy := GameEconomy.new(GameState.new())
	economy.state.coins = 0

	economy.buy_polyhouse()  # a fresh GameState() -- has_polyhouse is always false here

	assert_true(economy.has_events())
	var event := economy.pop_event()
	assert_true(event.is_rejection, "an unaffordable purchase must be classified as a rejection")


func test_a_successful_purchase_is_not_classified_as_a_rejection() -> void:
	var economy := GameEconomy.new(GameState.new())
	economy.state.coins = 1_000_000

	economy.buy_polyhouse()

	assert_true(economy.has_events())
	var event := economy.pop_event()
	assert_false(event.is_rejection, "a successful purchase must not be classified as a rejection")


func test_a_blocked_grow_skip_is_classified_as_a_rejection() -> void:
	var economy := GameEconomy.new(GameState.new())
	var now: int = 1787356800000
	economy.state.gems = 0
	var plot_id := economy.state.plots[0].id
	economy.plant_seed(plot_id, CropType.Kind.WHEAT, now)

	economy.skip_grow_time(plot_id, now)

	var event := economy.pop_event()
	assert_true(event.is_rejection, "insufficient gems for a grow-skip must be classified as a rejection")


## Declining a chanda visit is a legitimate, cost-free choice, not a
## blocked action -- must NOT play the rejection SFX if it ever reaches the
## toast drain.
func test_declining_a_chanda_visit_is_not_classified_as_a_rejection() -> void:
	var economy := GameEconomy.new(GameState.new())
	var now: int = 1  # inside the first chanda cycle's active window
	economy.decline_chanda(now)

	assert_true(economy.has_events())
	var event := economy.pop_event()
	assert_false(event.is_rejection)


# ---------------------------------------------------------------------------
# hud.gd: the real drain, wired the way main.tscn actually wires it
# (a parent with a child literally named "VillageBoard" -- see hud.gd's
# @onready get_node("../VillageBoard")).
# ---------------------------------------------------------------------------

## Defensively normalize first: VillageBoardScene.instantiate() loads the
## real, persisted user://save.tres (same disk-persistence test-isolation
## bug class found repeatedly earlier this session -- see
## test_growing_info_card.gd's own "Defensively normalize first" comment).
## Every test below relies on buy_polyhouse()/buy_agroforestry() actually
## reaching their rejection branch, which silently no-ops instead if an
## earlier test's real purchase left has_polyhouse/has_agroforestry=true on
## disk -- reset both explicitly rather than trusting a fresh load.
func _build_wired_hud() -> Hud:
	var parent: Node = add_child_autofree(Node.new())
	var board: VillageBoard = VillageBoardScene.instantiate()
	board.name = "VillageBoard"
	parent.add_child(board)
	board.get_economy().state.has_polyhouse = false
	board.get_economy().state.has_agroforestry = false
	var hud: Hud = HudScene.instantiate()
	parent.add_child(hud)
	return hud


func test_drain_shows_a_real_rejection_events_message_in_the_toast() -> void:
	var hud := _build_wired_hud()
	var economy := hud._village_board.get_economy()
	economy.state.coins = 0

	economy.buy_polyhouse()  # real rejection: "Need ₹%d to build a Polyhouse."
	hud._refresh()

	assert_true(hud._toast_panel.visible)
	assert_true(hud._toast_label.text.begins_with("Need"), "the toast must show the real rejection message, not a placeholder")


func test_drain_queues_multiple_events_instead_of_dropping_them() -> void:
	var hud := _build_wired_hud()
	var economy := hud._village_board.get_economy()
	economy.state.coins = 0

	economy.buy_polyhouse()
	economy.buy_agroforestry()
	hud._refresh()

	# One is showing now, the other must still be waiting -- never silently
	# dropped, matching GameEvent's own BUGFIX comment (multiple events
	# produced in one pass must not overwrite down to just the last one).
	assert_true(hud._toast_panel.visible)
	assert_eq(hud._toast_queue.size(), 1, "the second event must be queued, not lost")


func test_finishing_the_toast_timer_advances_to_the_next_queued_event() -> void:
	var hud := _build_wired_hud()
	var economy := hud._village_board.get_economy()
	economy.state.coins = 0
	economy.buy_polyhouse()
	economy.buy_agroforestry()
	hud._refresh()
	var first_message := hud._toast_label.text

	hud._on_toast_timer_timeout()

	assert_eq(hud._toast_queue.size(), 0)
	assert_true(hud._toast_panel.visible, "a second queued event must show immediately, not leave the toast empty")
	assert_ne(hud._toast_label.text, first_message, "the toast must have actually advanced to the next event's text")


func test_toast_hides_once_the_queue_is_fully_drained() -> void:
	var hud := _build_wired_hud()
	var economy := hud._village_board.get_economy()
	economy.state.coins = 0
	economy.buy_polyhouse()
	hud._refresh()

	hud._on_toast_timer_timeout()

	assert_false(hud._toast_panel.visible, "nothing left queued -- the toast must hide, not show a stale message")
