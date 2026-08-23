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


## design/gdd/real-time-day-night.md's "smooth crossfade between phases"
## future stretch, decided and built 2026-08-22. Deliberately does NOT
## try to assert on the tween's actual frame-by-frame animation progress
## (a "Feel"/timing quality this project's own coding-standards.md
## explicitly excludes from automation) -- only the LOGIC decision of
## which code path ran (instant snap vs. a crossfade that hasn't
## processed a frame yet), which is a legitimate, deterministic thing to
## test.
func test_the_first_application_snaps_instantly_to_the_correct_preset() -> void:
	RealSavePaths.wipe_all()
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	# _ready() already called _apply_time_of_day_if_needed() once with the
	# real current time; recompute the same call board.gd itself makes so
	# this test isn't guessing at the real system's timezone/season.
	var tz: Dictionary = Time.get_time_zone_from_system()
	var hour := TimeOfDay.local_hour(0, int(tz.get("bias", 0)))
	var phase := TimeOfDay.phase_for_hour(hour)
	var month := TimeOfDay.local_month(0, int(tz.get("bias", 0)))
	var season := TimeOfDay.season_for_month(month)
	var expected_preset := TimeOfDay.preset_for_phase_and_season(phase, season)
	board._last_time_of_day_phase = -1  # precondition: "never applied," matching _ready()'s own starting state

	board._apply_time_of_day_if_needed(0)

	assert_eq(board._world_environment.environment.background_color, expected_preset["sky_color"], "the very first application must land on the correct color immediately, not mid-crossfade from the scene's authored default")


func test_a_real_phase_transition_does_not_snap_instantly() -> void:
	RealSavePaths.wipe_all()
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	board._apply_time_of_day_if_needed(0)  # establishes whatever phase now=0 really maps to as "previous"
	var color_before_transition := board._world_environment.environment.background_color

	# Force the next call to be treated as a real transition (not the
	# first-ever application) by making _last_time_of_day_phase disagree
	# with what phase_for_hour(now=0) will recompute to the exact same
	# value again -- isolates "instant snap vs. crossfade," not a guess at
	# the real system's timezone.
	board._last_time_of_day_phase = (board._last_time_of_day_phase + 1) % 4

	board._apply_time_of_day_if_needed(0)

	assert_eq(board._world_environment.environment.background_color, color_before_transition, "a real transition must start a crossfade, not snap the color instantly -- the tween hasn't processed a frame yet within this same synchronous call")


## design/art/ui-visual-direction-2026-08.md's on-device "COC-quality" review
## (2026-08-23): LOCKED_ZONE_PLACEHOLDER_COLOR's glassy box alone doesn't
## read as "locked" -- each zone's own plinth_color shows through the
## translucent overlay, so a row of locked zones looked like an arbitrary
## set of pastel boxes rather than one consistent state. Same SC 1.4.1 Use
## of Color gap class the plot lifecycle badges elsewhere in this file
## (_build_ready_badge_decal() etc.) already guard against -- this locks in
## the equivalent fix at the zone level: a locked zone's rendered node tree
## must include the LockBadge decal.
func test_a_locked_zone_renders_a_lock_badge() -> void:
	RealSavePaths.wipe_all()  # fresh economy -- Polyhouse must actually start locked, not inherit an unlock from an earlier test's save
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())

	var polyhouse_node: Node3D = board._zone_nodes_by_id[VillageSnapshotMapper.ZONE_ID_POLYHOUSE]
	assert_true(polyhouse_node.has_node("LockBadge"), "a locked zone must render the LockBadge decal so it reads as locked, not as an unstyled box")


## Opposite-direction sanity check for the same fix -- an unlocked zone must
## never carry the badge (it would misleadingly suggest a built, working
## zone is still locked), and buying Polyhouse must remove the badge a
## fresh board started with, not just skip adding a new one.
func test_an_unlocked_zone_does_not_render_a_lock_badge() -> void:
	RealSavePaths.wipe_all()
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())

	var farmhouse_node: Node3D = board._zone_nodes_by_id[VillageSnapshotMapper.ZONE_ID_FARMHOUSE]
	assert_false(farmhouse_node.has_node("LockBadge"), "Farmhouse is always unlocked and must never render the LockBadge decal")

	var economy := board.get_economy()
	economy.state.coins = 1_000_000
	economy.buy_polyhouse()
	board.persist_and_rebuild_if_dirty()

	# rebuild() always tears down and reconstructs every zone node fresh --
	# re-fetch rather than reuse the old (now-freed) reference, same
	# precedent as the lamp tests above.
	var new_polyhouse_node: Node3D = board._zone_nodes_by_id[VillageSnapshotMapper.ZONE_ID_POLYHOUSE]
	assert_false(new_polyhouse_node.has_node("LockBadge"), "unlocking Polyhouse must remove the badge a fresh board started with")


## User report (2026-08-23): "When building is upgraded then building
## should show that worker is building it." play_construction_effect() is
## the resulting API -- farmhouse_tab.gd/polyhouse_tab.gd/agroforestry_tab.gd/
## niche_farming_tab.gd's two handlers all call it right after their own
## mutating GameEconomy call succeeds (see each file's own `if _economy.dirty`
## block). Covered here at the VillageBoard level rather than in each tab's
## own test file, matching those files' own established precedent of
## testing only pure build_view_data() logic, not button-press/scene-tree
## wiring (see test_polyhouse_tab.gd's header comment).
func test_play_construction_effect_spawns_a_villager_at_the_zones_center() -> void:
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())

	board.play_construction_effect(VillageSnapshotMapper.ZONE_ID_FARMHOUSE)

	var farmhouse_zone: ZoneFixture = board._zones_by_id[VillageSnapshotMapper.ZONE_ID_FARMHOUSE]
	var expected_position := board._zone_center_world(farmhouse_zone)
	var found_effect := false
	for child in board.get_node("ActorLayer").get_children():
		if child is ConstructionEffect:
			found_effect = true
			assert_eq(child.position, expected_position, "the effect must spawn at the zone's center, same spot _zone_center_world() computes")
	assert_true(found_effect, "play_construction_effect() must actually add a ConstructionEffect under ActorLayer")


## Defensive guard: called with a zone_id that isn't currently rendered
## (a bad id, or a real call site racing a rebuild) -- must not crash, and
## must not add a stray effect node with a garbage position.
func test_play_construction_effect_is_a_safe_no_op_for_an_unknown_zone_id() -> void:
	var board: VillageBoard = add_child_autofree(VillageBoardScene.instantiate())
	var actor_layer := board.get_node("ActorLayer")
	var children_before := actor_layer.get_child_count()

	board.play_construction_effect("not_a_real_zone")

	assert_eq(actor_layer.get_child_count(), children_before, "an unknown zone_id must not spawn anything")
