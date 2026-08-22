## Covers PgsSnapshotProvider (adr-0003-cloud-save-and-player-accounts.md
## Phase 2, step 7 -- "upload on app pause, no download path at all"). This
## is the real CloudSaveProvider implementation the ADR's architecture
## diagram names as the chosen backend; NullCloudSaveProvider (Phase 0)
## stays the default until Phase 1's sign-in verification fully passes.
##
## Tests never touch the real Android plugin -- there is no native
## GodotPlayGameServices singleton in this headless test environment, so
## every call that would reach it is a safe no-op by construction (same
## guard PlayGamesSignInClient/PlayGamesSnapshotsClient themselves use
## internally). The plugin's own client Node classes are instantiated
## directly rather than faked: a Node's _ready() -- where those classes
## wire up their native signal forwarding -- never runs unless the node
## enters a SceneTree, so a bare `PlayGamesSignInClient.new()` here is
## inert and safe, and its signals can be emitted manually to simulate the
## plugin firing them. Wrapped in autofree() (GUT's free-at-teardown
## helper, not add_child_autofree()) so these orphaned-by-design Nodes
## don't leak between tests -- they're deliberately never added to a tree.
extends GutTest


func test_provider_is_a_real_cloud_save_provider() -> void:
	var provider := PgsSnapshotProvider.new()
	assert_true(provider is CloudSaveProvider, "PgsSnapshotProvider must satisfy the CloudSaveProvider seam")


func test_provider_is_not_available_without_the_native_plugin() -> void:
	# Headless test environment: Engine.has_singleton("GodotPlayGameServices")
	# is always false here, regardless of what clients are injected.
	var provider := PgsSnapshotProvider.new(autofree(PlayGamesSignInClient.new()), autofree(PlayGamesSnapshotsClient.new()))
	assert_false(provider.is_available())


func test_provider_is_not_available_with_no_clients_injected() -> void:
	var provider := PgsSnapshotProvider.new()
	assert_false(provider.is_available())


func test_sign_in_silent_is_safe_when_unavailable() -> void:
	var provider := PgsSnapshotProvider.new(autofree(PlayGamesSignInClient.new()), autofree(PlayGamesSnapshotsClient.new()))
	provider.sign_in_silent()
	assert_true(true, "sign_in_silent() did not crash or hang without the native plugin")


func test_upload_is_safe_when_unavailable() -> void:
	var provider := PgsSnapshotProvider.new(autofree(PlayGamesSignInClient.new()), autofree(PlayGamesSnapshotsClient.new()))
	provider.upload({"coins": 100})
	assert_true(true, "upload() did not crash or hang without the native plugin")


func test_sign_in_completed_forwards_the_plugins_user_authenticated_signal() -> void:
	var sign_in_client: PlayGamesSignInClient = autofree(PlayGamesSignInClient.new())
	var provider := PgsSnapshotProvider.new(sign_in_client, autofree(PlayGamesSnapshotsClient.new()))
	var received: Array = []
	provider.sign_in_completed.connect(func(success: bool) -> void: received.append(success))

	sign_in_client.user_authenticated.emit(true)

	assert_eq(received, [true], "sign_in_completed must forward the plugin's real sign-in outcome")


func test_upload_completed_forwards_the_plugins_game_saved_signal() -> void:
	var snapshots_client: PlayGamesSnapshotsClient = autofree(PlayGamesSnapshotsClient.new())
	var provider := PgsSnapshotProvider.new(autofree(PlayGamesSignInClient.new()), snapshots_client)
	var received: Array = []
	provider.upload_completed.connect(func(success: bool) -> void: received.append(success))

	snapshots_client.game_saved.emit(true, "kisan_khet_save", "Kisan Khet cloud save")

	assert_eq(received, [true], "upload_completed must forward the plugin's real save outcome")


func test_upload_completed_forwards_a_failed_save_too() -> void:
	var snapshots_client: PlayGamesSnapshotsClient = autofree(PlayGamesSnapshotsClient.new())
	var provider := PgsSnapshotProvider.new(autofree(PlayGamesSignInClient.new()), snapshots_client)
	var received: Array = []
	provider.upload_completed.connect(func(success: bool) -> void: received.append(success))

	snapshots_client.game_saved.emit(false, "kisan_khet_save", "Kisan Khet cloud save")

	assert_eq(received, [false], "a failed save must forward false, not be swallowed")


func test_download_and_resolve_conflict_remain_unimplemented_phase_2_scope() -> void:
	# ADR-0003 Phase 2 is upload-only by design ("no download path at
	# all") -- these stay the inherited CloudSaveProvider no-ops until
	# Phase 4. Confirmed explicitly so a reader doesn't assume a "real"
	# provider must implement everything.
	var provider := PgsSnapshotProvider.new(autofree(PlayGamesSignInClient.new()), autofree(PlayGamesSnapshotsClient.new()))
	provider.download()
	provider.resolve_conflict({"coins": 100})
	assert_true(true, "download()/resolve_conflict() are safe Phase-4-deferred no-ops")
