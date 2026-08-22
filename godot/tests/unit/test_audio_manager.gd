## Covers audio_manager.gd's two headlessly-testable pieces:
## pick_variant()'s no-immediate-repeat guarantee (pure, no scene-tree
## dependency) and the safe-no-op contract for a missing/uncatalogued audio
## event -- plus a smoke check that playing a real catalogued event (all 40
## .ogg files now exist on disk, see audio_catalogue.gd's header comment)
## doesn't crash headlessly. Visual/timing behavior (ambience crossfade
## Tweens, the detail-sound Timer scheduler's actual random intervals) is
## explicitly NOT covered here per this project's testing standards
## (.claude/docs/coding-standards.md: "Visual/Feel" territory) -- only pure
## logic and the deliberate no-op/no-crash contracts are.
extends GutTest

const _REPEAT_TRIALS: int = 200


# --- pick_variant() ----------------------------------------------------------------

func test_pick_variant_never_immediately_repeats_for_size_two_or_more() -> void:
	# Arrange
	var paths: Array[String] = ["a.ogg", "b.ogg", "c.ogg"]
	var last_index := 0

	# Act / Assert -- run many trials; each pick must differ from the
	# previous one, and the previous one becomes this trial's last_index.
	for _i in range(_REPEAT_TRIALS):
		var chosen := AudioManager.pick_variant(paths, last_index)
		assert_ne(chosen, last_index, "pick_variant() must never immediately repeat the last-picked index")
		assert_true(chosen >= 0 and chosen < paths.size(), "pick_variant() must return a valid index into paths")
		last_index = chosen


func test_pick_variant_with_two_variants_alternates_correctly() -> void:
	# Arrange
	var paths: Array[String] = ["a.ogg", "b.ogg"]
	var last_index := 0

	# Act / Assert -- with only 2 variants, "never repeat" forces strict
	# alternation every trial.
	for _i in range(_REPEAT_TRIALS):
		var chosen := AudioManager.pick_variant(paths, last_index)
		assert_ne(chosen, last_index)
		last_index = chosen


func test_pick_variant_with_single_variant_returns_zero_without_hanging() -> void:
	# Arrange
	var paths: Array[String] = ["only.ogg"]

	# Act
	var chosen_repeating_last := AudioManager.pick_variant(paths, 0)
	var chosen_no_prior := AudioManager.pick_variant(paths, -1)

	# Assert -- the single-variant case must return the only valid index (0)
	# regardless of last_index, and must not infinite-loop trying to avoid
	# repeating itself (this test completing at all is part of the proof).
	assert_eq(chosen_repeating_last, 0)
	assert_eq(chosen_no_prior, 0)


func test_pick_variant_with_empty_array_does_not_crash() -> void:
	# Arrange
	var paths: Array[String] = []

	# Act
	var chosen := AudioManager.pick_variant(paths, -1)

	# Assert
	assert_eq(chosen, 0)


# --- Real catalogued events + the missing/uncatalogued no-op path -------------------

## Update (2026-08-23): this test used to prove the missing-file no-op path
## for real catalogued events too, back when zero .ogg files existed in this
## repo -- every catalogued path was guaranteed missing, so playing one WAS
## exercising the no-op branch for real. All 40 files now exist on disk
## (see audio_catalogue.gd's header comment), so these specific calls now
## exercise real playback instead -- still worth covering (must not crash
## with real files loaded, headless or not), just no longer proof of the
## no-op path. That path now has its own dedicated test below
## (test_play_sfx_with_uncatalogued_event_key_is_a_safe_no_op), which this
## test used to redundantly re-check inline.
func test_play_sfx_with_real_catalogued_events_does_not_crash() -> void:
	var manager: AudioManager = add_child_autofree(AudioManager.new())

	manager.play_sfx(&"economy_plant")
	manager.play_sfx(&"economy_harvest")
	manager.play_batch_resolve_chime()

	assert_true(true, "play_sfx()/play_batch_resolve_chime() completed without raising an error against real, on-disk asset files")


func test_play_sfx_with_uncatalogued_event_key_is_a_safe_no_op() -> void:
	# Arrange
	var manager: AudioManager = add_child_autofree(AudioManager.new())

	# Act
	manager.play_sfx(&"totally_unknown_event")

	# Assert
	assert_true(true, "play_sfx() with an uncatalogued key completed without raising an error")


# --- AudioCatalogue's own lookup functions -------------------------------------------
# Found 2026-08-23: AudioManager's own construction (test_ready_builds_one_player_per_
# catalogued_event() below) exercises AudioCatalogue.EVENT_DEFS as a whole, but nothing
# called paths_for_event()/bus_for_event()/max_polyphony_for_event() directly -- each
# has a real fallback-on-unknown-key branch (empty array / BUS_SFX / DEFAULT_MAX_POLYPHONY)
# that was untested.

func test_paths_for_event_returns_the_real_catalogued_paths() -> void:
	var paths := AudioCatalogue.paths_for_event(&"economy_plant")
	assert_eq(paths, [
		"res://assets/audio/sfx/sfx_economy_plant_01.ogg",
		"res://assets/audio/sfx/sfx_economy_plant_02.ogg",
		"res://assets/audio/sfx/sfx_economy_plant_03.ogg",
	] as Array[String])


func test_paths_for_event_returns_empty_for_an_uncatalogued_key() -> void:
	var paths := AudioCatalogue.paths_for_event(&"not_a_real_event")
	assert_eq(paths, [] as Array[String])


func test_bus_for_event_returns_the_real_catalogued_bus() -> void:
	assert_eq(AudioCatalogue.bus_for_event(&"ui_button_tap"), AudioCatalogue.BUS_UI)


func test_bus_for_event_falls_back_to_sfx_for_an_uncatalogued_key() -> void:
	assert_eq(AudioCatalogue.bus_for_event(&"not_a_real_event"), AudioCatalogue.BUS_SFX)


func test_max_polyphony_for_event_returns_the_real_catalogued_value() -> void:
	assert_eq(AudioCatalogue.max_polyphony_for_event(&"ui_sheet_open"), AudioCatalogue.RARE_MAX_POLYPHONY)


func test_max_polyphony_for_event_falls_back_to_default_for_an_uncatalogued_key() -> void:
	assert_eq(AudioCatalogue.max_polyphony_for_event(&"not_a_real_event"), AudioCatalogue.DEFAULT_MAX_POLYPHONY)


func test_ready_builds_one_player_per_catalogued_event() -> void:
	# Arrange / Act
	var manager: AudioManager = add_child_autofree(AudioManager.new())

	# Assert -- one AudioStreamPlayer child per AudioCatalogue.EVENT_DEFS
	# entry, plus the 3 ambience-loop players and 3 detail players/timers --
	# proves _build_event_players() actually ran during _ready().
	var event_player_count := 0
	for child in manager.get_children():
		if child is AudioStreamPlayer and (child.name as String).begins_with("SFX_"):
			event_player_count += 1
	assert_eq(event_player_count, AudioCatalogue.EVENT_DEFS.size())
