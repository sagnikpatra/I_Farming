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


## Localization Phase 1 (docs/architecture/localization-pipeline.md):
## VillageBoard is the one place that actually calls
## TranslationServer.set_locale() -- see its _on_accessibility_settings_
## changed(). Forces the real signal path (mutate the real
## AccessibilitySettings instance the board loaded, same object identity
## every UI call site already relies on) rather than calling the engine
## API directly, so this guards the wiring itself, not just the API.
func test_changing_the_accessibility_locale_applies_it_to_translation_server() -> void:
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	TranslationServer.set_locale("en")

	# Defensively normalize first: AccessibilitySettings' setters
	# (set_locale() included) always save() to the real default
	# user://accessibility.tres, same as every other setter in that class
	# (see test_accessibility_settings.gd's own tests, which do the same) --
	# an earlier test in this run may have left locale="hi" persisted
	# there, which would make set_locale("hi") below a silent no-op (already
	# equal) rather than the real transition this test means to exercise.
	# Direct field assignment (not set_locale()) matches this file's own
	# "force the state directly" precedent for _last_time_of_day_phase above.
	board.get_accessibility_settings().locale = "en"

	board.get_accessibility_settings().set_locale("hi")

	assert_eq(TranslationServer.get_locale(), "hi")
	# Reset both directions -- TranslationServer is process-global state, AND
	# set_locale() above just save()d "hi" to the real default
	# user://accessibility.tres, which a LATER test's fresh VillageBoard
	# would otherwise silently inherit via its own _ready() (see
	# RealSavePaths' own doc comment for the full rationale -- this is the
	# same disk-persistence class of bug found repeatedly this session, this
	# time via a genuinely global singleton).
	TranslationServer.set_locale("en")
	RealSavePaths.wipe_all()


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


## design/gdd/festival-visiting-npcs.md's board-NPC stretch (2026-08-22):
## _sync_chanda_visitor_if_needed() spawn/despawn edge-detection. Forces
## `now=0`, same "control the state, not real-clock timing" approach as
## the day/night tests above -- a fresh GameState's Chanda cycle is
## awaiting decision at now=0 (see test_chanda_visit.gd's own
## test_awaiting_decision_true_for_a_fresh_active_visit()).
func test_a_chanda_visit_awaiting_decision_spawns_a_board_visitor() -> void:
	RealSavePaths.wipe_all()
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())

	board._sync_chanda_visitor_if_needed(0)

	assert_not_null(board._chanda_visitor_node, "an awaiting-decision visit must spawn the board NPC")
	assert_true(is_instance_valid(board._chanda_visitor_node))


func test_giving_chanda_despawns_the_board_visitor() -> void:
	RealSavePaths.wipe_all()
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	board._sync_chanda_visitor_if_needed(0)
	assert_not_null(board._chanda_visitor_node, "precondition: the visitor must actually be spawned first")

	board.get_economy().give_chanda(0)
	board._sync_chanda_visitor_if_needed(100)

	assert_null(board._chanda_visitor_node, "once resolved (given), the board NPC must despawn -- the visit is no longer awaiting a decision")


func test_declining_chanda_despawns_the_board_visitor() -> void:
	RealSavePaths.wipe_all()
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	board._sync_chanda_visitor_if_needed(0)

	board.get_economy().decline_chanda(0)
	board._sync_chanda_visitor_if_needed(100)

	assert_null(board._chanda_visitor_node, "Decline must despawn the board NPC too, not just Give")


func test_a_resolved_visit_does_not_spawn_a_visitor_on_the_next_cycle_start() -> void:
	# Sanity check that the spawn logic tracks the live awaiting-decision
	# flag correctly across a cycle boundary, not just "spawned once, never
	# despawns."
	RealSavePaths.wipe_all()
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	board._sync_chanda_visitor_if_needed(0)
	board.get_economy().give_chanda(0)
	board._sync_chanda_visitor_if_needed(100)
	assert_null(board._chanda_visitor_node, "precondition: despawned after Give")

	var next_cycle_start: int = GameData.CHANDA_CYCLE_MS
	board._sync_chanda_visitor_if_needed(next_cycle_start)

	assert_not_null(board._chanda_visitor_node, "the next cycle's fresh visit must spawn its own board NPC")
