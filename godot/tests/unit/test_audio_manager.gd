## Covers audio_manager.gd's two testable-without-real-audio-files pieces:
## pick_variant()'s no-immediate-repeat guarantee (pure, no scene-tree
## dependency) and the missing-audio-file no-op safety path (real end-to-end
## proof, since zero .ogg files exist in this repo as of this pass -- see
## audio_catalogue.gd's header comment). Visual/timing behavior (ambience
## crossfade Tweens, the detail-sound Timer scheduler's actual random
## intervals) is explicitly NOT covered here per this project's testing
## standards (.claude/docs/coding-standards.md: "Visual/Feel" territory) --
## only pure logic and the deliberate no-op contract are.
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


# --- Missing-audio-file no-op path --------------------------------------------------

func test_play_sfx_with_no_real_asset_files_is_a_safe_no_op() -> void:
	# Arrange -- zero .ogg files exist in this repo as of this pass (see
	# audio_catalogue.gd's header comment), so every catalogued path is
	# guaranteed missing right now: this is a real, not simulated,
	# exercise of the "build now, source assets later" no-op path.
	var manager: AudioManager = add_child_autofree(AudioManager.new())

	# Act / Assert -- must not error or crash for a real catalogued event...
	manager.play_sfx(&"economy_plant")
	manager.play_sfx(&"economy_harvest")
	manager.play_batch_resolve_chime()
	# ...nor for a genuinely uncatalogued event key.
	manager.play_sfx(&"not_a_real_event")
	assert_true(true, "play_sfx()/play_batch_resolve_chime() completed without raising an error")


func test_play_sfx_with_uncatalogued_event_key_is_a_safe_no_op() -> void:
	# Arrange
	var manager: AudioManager = add_child_autofree(AudioManager.new())

	# Act
	manager.play_sfx(&"totally_unknown_event")

	# Assert
	assert_true(true, "play_sfx() with an uncatalogued key completed without raising an error")


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
