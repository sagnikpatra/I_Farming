## Audio event/asset catalogue for the core gameplay loop pass. See
## design/audio/audio-core-gameplay-loop.md for the full sonic direction,
## sound-designer's event rationale, and the complete asset-naming list this
## file's paths are drawn from (once that doc is approved and written --
## pending as of this pass, see that doc's own "Implementation Status").
##
## NO REAL AUDIO ASSET FILES EXIST YET in this repo (zero .ogg files as of
## this pass). Every path below is therefore a plain STRING, never a
## preloaded AudioStream -- a preload() on a file that doesn't exist yet is a
## hard parse error that would break the whole project on load. AudioManager
## (audio_manager.gd) checks ResourceLoader.exists() before ever attempting
## to load one of these paths (see its _play_path_on()); until real files are
## dropped in at these exact paths, every play_*() call is a deliberate,
## permanent-until-assets-land silent no-op -- not a bug. Once real files
## land here with no filename changes, playback works with zero code changes.
##
## Static-only data holder (no instances expected) -- same "catalogue table"
## spirit as GameData's tunable-constant tables, referenced directly as
## `AudioCatalogue.EVENT_DEFS`/`AudioCatalogue.paths_for_event(...)` etc.
class_name AudioCatalogue
extends RefCounted

const BUS_AMBIENCE: String = "Ambience"
const BUS_SFX: String = "SFX"
const BUS_UI: String = "UI"

## Events that can legitimately overlap (plant/harvest/sell/purchase/
## plot-ready/button-tap/rotate-flip) get this polyphony.
const DEFAULT_MAX_POLYPHONY: int = 3
## Genuinely rare one-shots (structure-unlock, farmhouse-upgrade, festival-
## tier-reward... no, festival-tier-reward is DEFAULT -- see EVENT_DEFS
## below for the authoritative per-event value) get this polyphony instead.
const RARE_MAX_POLYPHONY: int = 1

const _SFX_DIR: String = "res://assets/audio/sfx/"
const _AMB_DIR: String = "res://assets/audio/ambience/"

## StringName event key -> {"paths": Array[String], "bus": String,
## "max_polyphony": int}. 26 entries total (SFX + UI), matching the
## core-gameplay-loop pass's full event list. Fully literal (not
## programmatically generated) so this stays a plain, auditable data table
## with no static-initializer-ordering risk.
const EVENT_DEFS: Dictionary = {
	# --- Economy (bus SFX, round-robin variants) -----------------------------
	&"economy_plant": {
		"paths": [
			"res://assets/audio/sfx/sfx_economy_plant_01.ogg",
			"res://assets/audio/sfx/sfx_economy_plant_02.ogg",
			"res://assets/audio/sfx/sfx_economy_plant_03.ogg",
		],
		"bus": BUS_SFX, "max_polyphony": DEFAULT_MAX_POLYPHONY,
	},
	&"economy_harvest": {
		"paths": [
			"res://assets/audio/sfx/sfx_economy_harvest_01.ogg",
			"res://assets/audio/sfx/sfx_economy_harvest_02.ogg",
			"res://assets/audio/sfx/sfx_economy_harvest_03.ogg",
		],
		"bus": BUS_SFX, "max_polyphony": DEFAULT_MAX_POLYPHONY,
	},
	&"economy_sell": {
		"paths": [
			"res://assets/audio/sfx/sfx_economy_sell_01.ogg",
			"res://assets/audio/sfx/sfx_economy_sell_02.ogg",
			"res://assets/audio/sfx/sfx_economy_sell_03.ogg",
		],
		"bus": BUS_SFX, "max_polyphony": DEFAULT_MAX_POLYPHONY,
	},
	&"economy_purchase_small": {
		"paths": [
			"res://assets/audio/sfx/sfx_economy_purchase_small_01.ogg",
			"res://assets/audio/sfx/sfx_economy_purchase_small_02.ogg",
		],
		"bus": BUS_SFX, "max_polyphony": DEFAULT_MAX_POLYPHONY,
	},

	# --- Progression -----------------------------------------------------------
	&"progression_structure_unlock": {
		"paths": ["res://assets/audio/sfx/sfx_progression_structure_unlock_01.ogg"],
		"bus": BUS_SFX, "max_polyphony": RARE_MAX_POLYPHONY,
	},
	&"progression_farmhouse_upgrade": {
		"paths": ["res://assets/audio/sfx/sfx_progression_farmhouse_upgrade_01.ogg"],
		"bus": BUS_SFX, "max_polyphony": RARE_MAX_POLYPHONY,
	},
	&"progression_plot_ready_chime": {
		"paths": [
			"res://assets/audio/sfx/sfx_progression_plot_ready_chime_01.ogg",
			"res://assets/audio/sfx/sfx_progression_plot_ready_chime_02.ogg",
		],
		"bus": BUS_SFX, "max_polyphony": DEFAULT_MAX_POLYPHONY,
	},
	&"progression_batch_resolve": {
		"paths": ["res://assets/audio/sfx/sfx_progression_batch_resolve_01.ogg"],
		"bus": BUS_SFX, "max_polyphony": RARE_MAX_POLYPHONY,
	},

	# --- LiveOps -----------------------------------------------------------------
	&"liveops_festival_tier_reward": {
		"paths": ["res://assets/audio/sfx/sfx_liveops_festival_tier_reward_01.ogg"],
		"bus": BUS_SFX, "max_polyphony": DEFAULT_MAX_POLYPHONY,
	},

	# --- UI (bus UI) ---------------------------------------------------------------
	&"ui_button_tap": {
		"paths": [
			"res://assets/audio/sfx/sfx_ui_button_tap_01.ogg",
			"res://assets/audio/sfx/sfx_ui_button_tap_02.ogg",
		],
		"bus": BUS_UI, "max_polyphony": DEFAULT_MAX_POLYPHONY,
	},
	&"ui_sheet_open": {
		"paths": ["res://assets/audio/sfx/sfx_ui_sheet_open_01.ogg"],
		"bus": BUS_UI, "max_polyphony": RARE_MAX_POLYPHONY,
	},
	&"ui_sheet_close": {
		"paths": ["res://assets/audio/sfx/sfx_ui_sheet_close_01.ogg"],
		"bus": BUS_UI, "max_polyphony": RARE_MAX_POLYPHONY,
	},
	&"ui_drag_pickup": {
		"paths": ["res://assets/audio/sfx/sfx_ui_drag_pickup_01.ogg"],
		"bus": BUS_UI, "max_polyphony": RARE_MAX_POLYPHONY,
	},
	&"ui_drag_drop_success": {
		"paths": ["res://assets/audio/sfx/sfx_ui_drag_drop_success_01.ogg"],
		"bus": BUS_UI, "max_polyphony": RARE_MAX_POLYPHONY,
	},
	&"ui_rotate_flip": {
		"paths": [
			"res://assets/audio/sfx/sfx_ui_rotate_flip_01.ogg",
			"res://assets/audio/sfx/sfx_ui_rotate_flip_02.ogg",
		],
		"bus": BUS_UI, "max_polyphony": DEFAULT_MAX_POLYPHONY,
	},
	# NOT WIRED to any real call site as of this pass -- see audio_manager.gd's
	# class doc / this pass's session notes: GameEvent.pending_events (the
	# only existing "an action was rejected" signal) carries no
	# success/rejection discriminant and is never drained by any UI code
	# today, so there is no single reliable hook to call play_sfx() from
	# without either a Foundation-layer change to GameEvent or fragile
	# message-string matching in Presentation code. Catalogued here (for the
	# asset-naming list/doc) but genuinely silent until that's resolved.
	&"ui_action_rejected": {
		"paths": ["res://assets/audio/sfx/sfx_ui_action_rejected_01.ogg"],
		"bus": BUS_UI, "max_polyphony": RARE_MAX_POLYPHONY,
	},
}

## Long-loop ambience layers (bus Ambience, max_polyphony 1 each -- see
## audio_manager.gd's _build_ambience_players()).
const AMBIENCE_BASE_LOOP_PATH: String = "res://assets/audio/ambience/amb_village_base_loop.ogg"
const AMBIENCE_MONSOON_LOOP_PATH: String = "res://assets/audio/ambience/amb_layer_monsoon_rain_loop.ogg"
const AMBIENCE_FESTIVAL_LOOP_PATH: String = "res://assets/audio/ambience/amb_layer_festival_percussion_loop.ogg"

## 11 equal-weight ambience-detail one-shots (birds/temple-bell/well-creak/
## cattle-bell), fed to AudioManager's 3-Timer detail scheduler. Along with
## the 3 loop paths above, totals 14 ambience files + 26 SFX/UI files = the
## 40 filenames documented in design/audio/audio-core-gameplay-loop.md.
const AMBIENCE_DETAIL_PATHS: Array[String] = [
	"res://assets/audio/ambience/amb_detail_bird_bulbul_01.ogg",
	"res://assets/audio/ambience/amb_detail_bird_bulbul_02.ogg",
	"res://assets/audio/ambience/amb_detail_bird_mynah_01.ogg",
	"res://assets/audio/ambience/amb_detail_bird_mynah_02.ogg",
	"res://assets/audio/ambience/amb_detail_bird_crow_01.ogg",
	"res://assets/audio/ambience/amb_detail_bird_crow_02.ogg",
	"res://assets/audio/ambience/amb_detail_temple_bell_01.ogg",
	"res://assets/audio/ambience/amb_detail_temple_bell_02.ogg",
	"res://assets/audio/ambience/amb_detail_well_creak_01.ogg",
	"res://assets/audio/ambience/amb_detail_cattle_bell_01.ogg",
	"res://assets/audio/ambience/amb_detail_cattle_bell_02.ogg",
]


## Path variants for `event_key`, or an empty Array if the key isn't
## catalogued -- callers (AudioManager.play_sfx()) silently no-op on empty.
static func paths_for_event(event_key: StringName) -> Array[String]:
	var def: Dictionary = EVENT_DEFS.get(event_key, {})
	var raw: Array = def.get("paths", [])
	var typed: Array[String] = []
	for path: String in raw:
		typed.append(path)
	return typed


static func bus_for_event(event_key: StringName) -> String:
	var def: Dictionary = EVENT_DEFS.get(event_key, {})
	return def.get("bus", BUS_SFX)


static func max_polyphony_for_event(event_key: StringName) -> int:
	var def: Dictionary = EVENT_DEFS.get(event_key, {})
	return def.get("max_polyphony", DEFAULT_MAX_POLYPHONY)
