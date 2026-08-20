## Central audio authority for the village board -- owns every
## AudioStreamPlayer the game uses (one per catalogued SFX/UI event, plus 3
## long-loop ambience-layer players and 3 reusable ambience-detail
## player+Timer pairs) and exposes a small play_sfx()-shaped API so every
## other script (board_interactor.gd, hud.gd, the *_tab.gd/*_picker.gd
## sheets, village_board.gd's own growth-tick handler) can trigger audio
## with one call, without knowing anything about voice limiting, variant
## selection, or bus routing.
##
## ARCHITECTURE: child of VillageBoard (godot/scenes/village_board/
## village_board.tscn), same "no autoload, single owner, public accessor"
## pattern already established for GameEconomy/AccessibilitySettings -- see
## village_board.gd's _ready()/get_economy()/get_accessibility_settings().
## Add `@onready var _audio_manager: AudioManager = $AudioManager` +
## `get_audio_manager()` there is the exact mirror of that precedent.
##
## NO REAL AUDIO ASSETS EXIST YET (zero .ogg files in this repo as of this
## pass) -- see audio_catalogue.gd's header comment for the full rationale
## and design/audio/audio-core-gameplay-loop.md for the asset list once that
## doc lands. Every play path funnels through _play_path_on(), which checks
## ResourceLoader.exists() before ever calling load(); a missing file is a
## deliberate, permanent-until-assets-land silent no-op, not a bug --
## covered directly by tests/unit/test_audio_manager.gd.
##
## VOICE LIMITING: one dedicated AudioStreamPlayer child per catalogued
## event, built in _ready() from AudioCatalogue.EVENT_DEFS, with
## max_polyphony/bus set per-event from that table. No hand-rolled
## pooling/dictionary bookkeeping.
##
## ROUND-ROBIN VARIANT SELECTION: pick_variant() is a pure, static, no-
## scene-tree-dependency function -- directly unit-tested.
class_name AudioManager
extends Node

const AMBIENCE_LAYER_ACTIVE_VOLUME_DB: float = 0.0
const AMBIENCE_LAYER_SILENT_VOLUME_DB: float = -80.0
const AMBIENCE_CROSSFADE_SECONDS: float = 3.0

const AMBIENCE_DETAIL_TIMER_COUNT: int = 3
const AMBIENCE_DETAIL_MIN_INTERVAL_SECONDS: float = 8.0
const AMBIENCE_DETAIL_MAX_INTERVAL_SECONDS: float = 150.0

## StringName event key -> AudioStreamPlayer (one per AudioCatalogue.EVENT_DEFS entry).
var _players_by_event: Dictionary = {}
## StringName event key -> last-picked variant index, for pick_variant()'s
## no-immediate-repeat guarantee.
var _last_variant_index_by_event: Dictionary = {}

var _amb_base_player: AudioStreamPlayer
var _amb_monsoon_player: AudioStreamPlayer
var _amb_festival_player: AudioStreamPlayer

var _detail_players: Array[AudioStreamPlayer] = []
var _detail_timers: Array[Timer] = []


func _ready() -> void:
	_build_event_players()
	_build_ambience_players()
	_build_ambience_detail_scheduler()


func _build_event_players() -> void:
	for event_key: StringName in AudioCatalogue.EVENT_DEFS.keys():
		var player := AudioStreamPlayer.new()
		player.name = "SFX_%s" % event_key
		player.bus = AudioCatalogue.bus_for_event(event_key)
		player.max_polyphony = AudioCatalogue.max_polyphony_for_event(event_key)
		add_child(player)
		_players_by_event[event_key] = player


# ---------------------------------------------------------------------------
# SFX/UI one-shot playback
# ---------------------------------------------------------------------------

## Plays the next round-robin variant for `event_key` on its dedicated
## player, or silently no-ops if `event_key` isn't catalogued or its picked
## variant's asset file doesn't exist yet. Callers never need to check
## ResourceLoader.exists() themselves -- see class doc.
func play_sfx(event_key: StringName) -> void:
	var paths := AudioCatalogue.paths_for_event(event_key)
	if paths.is_empty():
		return
	var player: AudioStreamPlayer = _players_by_event.get(event_key)
	if player == null:
		return
	var last_index: int = _last_variant_index_by_event.get(event_key, -1)
	var chosen_index := pick_variant(paths, last_index)
	_last_variant_index_by_event[event_key] = chosen_index
	_play_path_on(player, paths[chosen_index])


## Named wrapper matching this pass's batch-resolve hazard fix (see
## village_board.gd's growth-tick handler) -- equivalent to
## play_sfx(&"progression_batch_resolve"), kept as its own method since
## that's the exact call spelled out for this one high-stakes case.
func play_batch_resolve_chime() -> void:
	play_sfx(&"progression_batch_resolve")


## Pure, unit-testable round-robin-ish variant picker: returns a random
## index into `paths` that is never equal to `last_index` (no immediate
## repeat), except when `paths.size() <= 1`, where the only possible index
## (0) is always returned regardless of `last_index` -- repeating the same
## single variant is unavoidable there, not a bug (and importantly, does
## NOT infinite-loop trying to avoid itself). No scene-tree dependency --
## directly covered by tests/unit/test_audio_manager.gd.
static func pick_variant(paths: Array[String], last_index: int) -> int:
	if paths.size() <= 1:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chosen := rng.randi_range(0, paths.size() - 1)
	while chosen == last_index:
		chosen = rng.randi_range(0, paths.size() - 1)
	return chosen


## Single point every play path in this file funnels through -- see class
## doc's "NO REAL AUDIO ASSETS EXIST YET" section. ResourceLoader.exists()
## is checked before ever calling load(); a missing file is a silent no-op
## (no error, no crash), not a bug, until real assets are dropped in at the
## documented paths with no filename changes needed.
func _play_path_on(player: AudioStreamPlayer, path: String) -> void:
	if player == null:
		return
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	player.stream = stream
	player.play()


# ---------------------------------------------------------------------------
# Ambience: base loop (always on) + Monsoon/Festival adaptive layers
# (crossfaded in/out) + a small detail-sound scheduler
# ---------------------------------------------------------------------------

func _build_ambience_players() -> void:
	_amb_base_player = _make_ambience_player("AmbBase")
	_amb_monsoon_player = _make_ambience_player("AmbMonsoon")
	_amb_festival_player = _make_ambience_player("AmbFestival")

	# Base starts audible on VillageBoard _ready() (this node's own _ready(),
	# since it's a direct child); Monsoon/Festival layers start PLAYING but
	# silent (-80dB) so set_monsoon_active()/set_festival_active() only ever
	# need to crossfade an already-looping player's volume, never start/stop
	# playback mid-game.
	_start_ambience_loop(_amb_base_player, AudioCatalogue.AMBIENCE_BASE_LOOP_PATH, AMBIENCE_LAYER_ACTIVE_VOLUME_DB)
	_start_ambience_loop(_amb_monsoon_player, AudioCatalogue.AMBIENCE_MONSOON_LOOP_PATH, AMBIENCE_LAYER_SILENT_VOLUME_DB)
	_start_ambience_loop(_amb_festival_player, AudioCatalogue.AMBIENCE_FESTIVAL_LOOP_PATH, AMBIENCE_LAYER_SILENT_VOLUME_DB)


func _make_ambience_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = AudioCatalogue.BUS_AMBIENCE
	player.max_polyphony = 1
	add_child(player)
	return player


## Loads+plays `path` on `player` if it exists, looping by self-restarting
## on `finished` -- deliberately NOT relying on any AudioStream's own
## loop/loop_mode property (that API's exact shape shifted across recent
## Godot versions and this project's pinned 4.7.1 is past this assistant's
## training cutoff, see docs/engine-reference/godot/VERSION.md) so this
## works correctly regardless of which stream-loop API 4.7.1 actually uses.
## No-ops (including no signal connection) if `path` doesn't exist yet --
## see class doc.
func _start_ambience_loop(player: AudioStreamPlayer, path: String, initial_volume_db: float) -> void:
	player.volume_db = initial_volume_db
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	player.stream = stream
	player.finished.connect(player.play)
	player.play()


## True while `active`, the given adaptive layer's player is crossfaded up
## to full volume over AMBIENCE_CROSSFADE_SECONDS; while false, crossfaded
## back down to silent -- never an instant cut. Safe to call even if the
## underlying asset doesn't exist yet (the player is still a valid node,
## just silently never actually produced sound in the first place).
func set_monsoon_active(active: bool) -> void:
	_crossfade_ambience_layer(_amb_monsoon_player, active)


func set_festival_active(active: bool) -> void:
	_crossfade_ambience_layer(_amb_festival_player, active)


func _crossfade_ambience_layer(player: AudioStreamPlayer, active: bool) -> void:
	if player == null:
		return
	var target_db := AMBIENCE_LAYER_ACTIVE_VOLUME_DB if active else AMBIENCE_LAYER_SILENT_VOLUME_DB
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, AMBIENCE_CROSSFADE_SECONDS)


## 3 reusable one-shot Timer+player pairs (NOT one Timer per each of the 11
## detail sound variants) -- each pair independently re-arms itself with a
## fresh random interval after every playback, so up to 3 detail sounds can
## legitimately overlap at once.
func _build_ambience_detail_scheduler() -> void:
	for i in range(AMBIENCE_DETAIL_TIMER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "AmbDetailPlayer%d" % i
		player.bus = AudioCatalogue.BUS_AMBIENCE
		player.max_polyphony = 1
		add_child(player)
		_detail_players.append(player)

		var timer := Timer.new()
		timer.name = "AmbDetailTimer%d" % i
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(_on_ambience_detail_timer_timeout.bind(player, timer))
		_detail_timers.append(timer)
		_rearm_detail_timer(timer)


func _rearm_detail_timer(timer: Timer) -> void:
	timer.start(randf_range(AMBIENCE_DETAIL_MIN_INTERVAL_SECONDS, AMBIENCE_DETAIL_MAX_INTERVAL_SECONDS))


func _on_ambience_detail_timer_timeout(player: AudioStreamPlayer, timer: Timer) -> void:
	_play_random_ambience_detail(player)
	_rearm_detail_timer(timer)


## Equal-weight random pick across all 11 detail paths -- a future weighting
## scheme (e.g. birds more common than temple bells) is an explicitly
## deferred refinement, not required this pass.
func _play_random_ambience_detail(player: AudioStreamPlayer) -> void:
	var paths := AudioCatalogue.AMBIENCE_DETAIL_PATHS
	if paths.is_empty():
		return
	var path: String = paths[randi() % paths.size()]
	_play_path_on(player, path)
