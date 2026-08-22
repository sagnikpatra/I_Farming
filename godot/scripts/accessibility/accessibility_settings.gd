## Player-facing accessibility preferences -- text scale + colorblind-safe
## palette. Added to close the BLOCKING §0 finding in
## production/qa/accessibility/village-board-and-management-sheets-audit-
## 2026-08-21.md ("no accessibility settings screen exists at all").
##
## ARCHITECTURE: a plain Resource (not an autoload) persisted to its own
## small user:// file, loaded/saved via the same static-method-on-a-
## standalone-class pattern SaveSystem already uses for GameState --
## deliberately kept separate from GameState/save.tres rather than folded
## into the economy save schema, since these are player preferences, not
## game progress, and don't belong in a save-integrity/tamper-audit surface
## (see production/security/security-audit-2026-08-21.md's SEC-001).
## VillageBoard owns the loaded instance (mirrors its existing "sole
## authority" pattern for GameEconomy, see village_board.gd's _ready()) and
## exposes it via get_accessibility_settings() for HUD/AccessibilitySheet to
## read and mutate; `changed` lets VillageBoard re-render live when the
## colorblind-safe palette is toggled without a scene relaunch.
class_name AccessibilitySettings
extends Resource

const SAVE_PATH: String = "user://accessibility.tres"

## Allowed values only -- kept to a small, deliberately-bounded set (rather
## than a free float) to limit how much untested layout-break risk any one
## toggle can introduce across the many hardcoded-font-size sheets flagged
## as still-open in the audit's §5 (HIGH, not blocking).
const TEXT_SCALE_STEPS: Array[float] = [1.0, 1.15, 1.3]

@export var text_scale: float = 1.0
@export var colorblind_safe: bool = false

## Audio pass (design/audio/audio-core-gameplay-loop.md): per-bus linear
## volume [0.0, 1.0], pushed live to AudioServer by VillageBoard's
## _on_accessibility_settings_changed() via
## AudioServer.set_bus_volume_linear() -- unlike text_scale, this applies
## live with no rebuild risk, see that method's own doc comment.
@export var master_volume: float = 1.0
@export var ambience_volume: float = 1.0
@export var sfx_volume: float = 1.0
@export var ui_volume: float = 1.0
@export var audio_muted: bool = false

## Localization Phase 1 (docs/architecture/localization-pipeline.md):
## which locale's `.translation` resource (built from
## godot/locales/ui_strings.csv) TranslationServer applies. A player
## preference, same rationale as every other field in this file -- not
## game progress, so it stays out of GameState/save.tres. Bounded to a
## known-supported set (same "small deliberately-bounded set" philosophy
## TEXT_SCALE_STEPS already uses above) rather than accepting any locale
## string TranslationServer happens to recognize -- this project only
## ships real translated strings for these two.
const SUPPORTED_LOCALES: Array[String] = ["en", "hi"]
@export var locale: String = "en"

## Not named `changed` -- Resource already declares a native `changed`
## signal (fired by ResourceSaver/the editor's own property-change
## tracking); redeclaring it here is a compile error ("Member 'changed'
## redefined"), caught by the GUT suite the first time this file was run.
signal settings_changed


## Loads from disk, or returns fresh defaults if no prefs file exists yet or
## it's corrupt/unreadable -- same fallback shape as SaveSystem.load_state().
static func load_or_default(path: String = SAVE_PATH) -> AccessibilitySettings:
	if not FileAccess.file_exists(path):
		return AccessibilitySettings.new()
	var loaded: Resource = ResourceLoader.load(path, "AccessibilitySettings", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not (loaded is AccessibilitySettings):
		push_warning("AccessibilitySettings: prefs file at %s failed to load -- using defaults." % path)
		return AccessibilitySettings.new()
	return loaded


## Saves to disk. Returns true on success.
func save(path: String = SAVE_PATH) -> bool:
	var err: Error = ResourceSaver.save(self, path)
	if err != OK:
		push_warning("AccessibilitySettings: failed to save to %s (error %d)." % [path, err])
		return false
	return true


## Advances text_scale to the next step in TEXT_SCALE_STEPS, wrapping back to
## the first. Persists and emits `settings_changed`.
func cycle_text_scale() -> void:
	var idx := TEXT_SCALE_STEPS.find(text_scale)
	var next_idx := (idx + 1) % TEXT_SCALE_STEPS.size() if idx != -1 else 0
	text_scale = TEXT_SCALE_STEPS[next_idx]
	save()
	settings_changed.emit()


## Toggles colorblind_safe. Persists and emits `settings_changed`.
func toggle_colorblind_safe() -> void:
	colorblind_safe = not colorblind_safe
	save()
	settings_changed.emit()


# --- Audio pass: per-bus volume + mute -----------------------------------------

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	save()
	settings_changed.emit()


func set_ambience_volume(value: float) -> void:
	ambience_volume = clampf(value, 0.0, 1.0)
	save()
	settings_changed.emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	save()
	settings_changed.emit()


func set_ui_volume(value: float) -> void:
	ui_volume = clampf(value, 0.0, 1.0)
	save()
	settings_changed.emit()


## Toggles audio_muted. Persists and emits `settings_changed`.
func toggle_audio_muted() -> void:
	audio_muted = not audio_muted
	save()
	settings_changed.emit()


# --- Localization Phase 1 --------------------------------------------------

## Silently no-ops for an unsupported code rather than storing garbage --
## same "the UI can only ever offer a valid choice" guarantee
## cycle_text_scale()'s bounded TEXT_SCALE_STEPS gives, applied here since
## this setter (unlike that one) takes a free string, not an index cycle.
func set_locale(new_locale: String) -> void:
	if not SUPPORTED_LOCALES.has(new_locale) or new_locale == locale:
		return
	locale = new_locale
	save()
	settings_changed.emit()
