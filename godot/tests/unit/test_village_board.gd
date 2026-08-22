## First dedicated test coverage for village_board.gd -- a long-standing,
## explicitly documented project gap (technical-preferences.md's Testing
## section: "village-board interaction -- currently untested by
## automation"). Deliberately narrow, not an attempt at comprehensive
## coverage of this large class: this file exists specifically to close
## the one on-device-verification gap design/gdd/real-time-day-night.md's
## villager lamp-lighting stretch goal flagged as unconfirmed -- whether a
## rebuild() triggered by something unrelated to a day/night transition
## (a purchase, a drag-commit) correctly leaves an already-lit Night lamp
## lit, rather than silently darkening it. That was a real bug this
## session found and fixed (rebuild()'s own unconditional final call to
## _apply_night_lamps_to_current_state()); this test guards the fix.
extends GutTest

const VillageBoardScene := preload("res://scenes/village_board/village_board.tscn")


func test_a_rebuild_unrelated_to_day_night_keeps_night_lamps_lit() -> void:
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())

	# Simulate "it's currently Night" directly -- the real system clock at
	# test-run time won't reliably be Night, so this is forced rather than
	# waited for, same "control the state, not real-clock timing" approach
	# test_villager_roamer.gd already established for should_enter_idle_pause.
	board._last_time_of_day_phase = TimeOfDay.Phase.NIGHT
	board._apply_night_lamps_to_current_state()
	var farmhouse_node: Node3D = board._zone_nodes_by_id[VillageSnapshotMapper.ZONE_ID_FARMHOUSE]
	var lamp := farmhouse_node.get_node("NightLamp") as Light3D
	assert_almost_eq(lamp.light_energy, VillageBoard.NIGHT_LAMP_ENERGY, 0.001, "precondition: the lamp must actually be lit before the unrelated rebuild -- otherwise this test would prove nothing")

	# An unrelated economy action -- a real purchase, not a day/night
	# transition -- triggers rebuild() via persist_and_rebuild_if_dirty().
	# This is the exact real-game trigger the bug this test guards against
	# was found from: rebuild() tears down and reconstructs every zone
	# (including a freshly-off lamp) far more often than an actual phase
	# change.
	var economy := board.get_economy()
	economy.state.coins = 1_000_000
	economy.buy_polyhouse()
	board.persist_and_rebuild_if_dirty()

	# rebuild() always tears down and reconstructs every zone node fresh --
	# re-fetch rather than reuse the old (now-freed) reference.
	var new_farmhouse_node: Node3D = board._zone_nodes_by_id[VillageSnapshotMapper.ZONE_ID_FARMHOUSE]
	var new_lamp := new_farmhouse_node.get_node("NightLamp") as Light3D
	assert_almost_eq(new_lamp.light_energy, VillageBoard.NIGHT_LAMP_ENERGY, 0.001, "an unrelated rebuild() must not silently darken a lamp that should still be lit -- the exact bug this session found and fixed")


func test_lamps_are_off_when_phase_is_explicitly_not_night() -> void:
	# Opposite-direction sanity check for the same rebuild() path -- kept
	# deliberately independent of the real system clock (this project's
	# own "no time-dependent assertions" testing rule) by forcing the
	# phase explicitly rather than relying on whatever _ready() happened
	# to compute from the real current time.
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	board._last_time_of_day_phase = TimeOfDay.Phase.DAY
	board._apply_night_lamps_to_current_state()

	var economy := board.get_economy()
	economy.state.coins = 1_000_000
	economy.buy_polyhouse()
	board.persist_and_rebuild_if_dirty()

	var farmhouse_node: Node3D = board._zone_nodes_by_id[VillageSnapshotMapper.ZONE_ID_FARMHOUSE]
	var lamp := farmhouse_node.get_node("NightLamp") as Light3D
	assert_almost_eq(lamp.light_energy, 0.0, 0.001, "an unrelated rebuild() during Day must not accidentally light a lamp that should stay off")
