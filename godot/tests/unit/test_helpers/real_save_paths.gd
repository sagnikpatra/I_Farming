## Wipes every REAL persisted user:// file this project's production code
## writes to, so a test can start (and leave) a genuinely clean disk state
## regardless of what any other test in the same run did.
##
## WHY THIS EXISTS: this exact class of bug -- a test that loads/writes one
## of these real files, contaminating a LATER test's fresh load -- was found
## and fixed 6 separate times in one 2026-08-22 session, escalating from a
## single field (gems, a daily-cap flag) to a genuinely global singleton
## (AccessibilitySettings.locale persisting to disk, then getting applied to
## the process-wide TranslationServer by any later VillageBoard._ready()).
## Each occurrence was fixed locally in the test file that hit it (see
## test_growing_info_card.gd/test_gems_daily_tasks.gd/test_village_board.gd/
## test_toast_drain.gd/test_localization.gd's own "Defensively normalize
## first" comments for the individual accounts) -- this consolidates the
## pattern into one place so the NEXT new test file gets it for free instead
## of relearning the same lesson a 7th time.
##
## Every real path SaveSystem/AccessibilitySettings write to, by their own
## public SAVE_PATH constants -- not hand-typed strings, so this file can
## never silently drift out of sync with what those classes actually use.
class_name RealSavePaths
extends RefCounted

const REAL_PATHS: Array[String] = [
	SaveSystem.SAVE_PATH,
	AccessibilitySettings.SAVE_PATH,
]


## Call from before_each()/after_each() (both -- a test that fails partway
## still needs the AFTER cleanup, and a leftover file from a previous run's
## crash still needs the BEFORE cleanup) in any test that instantiates a
## real VillageBoardScene, calls SaveSystem.save_state()/load_state(), or
## calls any AccessibilitySettings setter without an explicit test-only path.
static func wipe_all() -> void:
	for path: String in REAL_PATHS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
