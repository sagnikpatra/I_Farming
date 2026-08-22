## The real CloudSaveProvider backend (adr-0003-cloud-save-and-player-
## accounts.md's chosen shape) -- Google Play Games Services Snapshots,
## wrapping the godot-play-game-services plugin's PlayGamesSignInClient and
## PlayGamesSnapshotsClient. NullCloudSaveProvider stays the actual default
## everywhere save flows read from until Phase 1's real sign-in verification
## fully passes (blocked on the project owner's Play Console setup as of
## 2026-08-22) -- constructing this class does not, by itself, change any
## existing behavior.
##
## Scope is deliberately Phase 2 ("upload on app pause, no download path at
## all" -- the ADR's own "safest useful increment"): sign_in_silent() and
## upload() are real; download() and resolve_conflict() are intentionally
## left as CloudSaveProvider's inherited no-ops until Phase 4, when
## conflict handling (never auto-resolve -- surfaced to the player) is
## designed.
##
## Dependency-injected, not a singleton (coding-standards.md): callers
## instantiate and add PlayGamesSignInClient/PlayGamesSnapshotsClient to the
## scene tree themselves and hand them to this constructor, which is what
## keeps this class unit-testable without the real native plugin -- see
## tests/unit/test_pgs_snapshot_provider.gd.
class_name PgsSnapshotProvider
extends CloudSaveProvider

## Play Games snapshot file name. Must be 1-100 non-URL-reserved characters
## per PlayGamesSnapshotsClient.save_game()'s own contract -- this satisfies
## it and is stable across versions; changing it would orphan existing
## players' cloud saves.
const SAVE_FILE_NAME := "kisan_khet_save"
const SAVE_DESCRIPTION := "Kisan Khet cloud save"

var _sign_in_client: PlayGamesSignInClient
var _snapshots_client: PlayGamesSnapshotsClient


func _init(sign_in_client: PlayGamesSignInClient = null, snapshots_client: PlayGamesSnapshotsClient = null) -> void:
	_sign_in_client = sign_in_client
	_snapshots_client = snapshots_client

	if _sign_in_client:
		_sign_in_client.user_authenticated.connect(func(is_authenticated: bool) -> void:
			sign_in_completed.emit(is_authenticated)
		)
	if _snapshots_client:
		_snapshots_client.game_saved.connect(func(is_saved: bool, _name: String, _description: String) -> void:
			upload_completed.emit(is_saved)
		)


## False unless both clients were injected AND the native Android plugin is
## actually present (Engine.has_singleton) -- true only on a real Android
## device with the plugin loaded, never in editor/headless/GUT runs. Every
## method below gates on this, matching NullCloudSaveProvider's "safe no-op
## everywhere else" behavior rather than crashing on a null native call.
func is_available() -> bool:
	return _sign_in_client != null and _snapshots_client != null and Engine.has_singleton("GodotPlayGameServices")


## Fire-and-forget (ADR-0003: never `await` on a gameplay or startup path).
## Delegates to PlayGamesSignInClient.is_authenticated() -- per that
## client's own docs, Play Games already performs an automatic silent
## check at startup; this is the explicit re-check path, and its result
## arrives via sign_in_completed (wired in _init above), not a return value.
func sign_in_silent() -> void:
	if not is_available():
		return
	_sign_in_client.is_authenticated()


## Fire-and-forget. `payload` must already be the JSON-safe Dictionary
## SaveSerializer.to_dict() produces -- this class does no GameState
## knowledge of its own, matching the ADR's layering (SaveSerializer sits
## below CloudSaveProvider in the architecture diagram). Result arrives via
## upload_completed (wired in _init above).
func upload(payload: Dictionary) -> void:
	if not is_available():
		return
	var save_data := JSON.stringify(payload).to_utf8_buffer()
	_snapshots_client.save_game(SAVE_FILE_NAME, SAVE_DESCRIPTION, save_data)
