extends Node
## ADR-0003 Phase 1 spike probe -- TEMPORARY, not the final implementation.
##
## Verifies that manually initializing the GodotPlayGameServices plugin and
## observing its automatic silent sign-in check neither hangs nor crashes
## app startup, per the ADR's Phase 1 step 6 verification criteria. This is
## deliberately minimal and bypasses the plugin's PlayGamesSignInClient
## wrapper -- it exists only to prove the call is safe on real hardware
## before the project owner completes Play Console setup.
##
## Remove this probe once Phase 1 sign-in is verified against a real
## Game Services ID, in favor of the ADR's actual chosen shape: a
## PgsSnapshotProvider implementing the CloudSaveProvider interface
## (see godot/scripts/economy/cloud_save_provider.gd), built in Phase 2+.

func _ready() -> void:
	# Fire-and-forget, no await -- must never block the startup path
	# (ADR-0003 Implementation Guidelines).
	if not Engine.has_singleton("GodotPlayGameServices"):
		print("[Phase1Probe] GodotPlayGameServices native singleton not present -- non-Android platform or plugin not loaded, skipping.")
		return

	var result: GodotPlayGameServices.PlayGamesPluginError = GodotPlayGameServices.initialize()
	if result != GodotPlayGameServices.PlayGamesPluginError.OK:
		print("[Phase1Probe] initialize() failed: %s" % result)
		return

	print("[Phase1Probe] initialize() called -- watching for the automatic silent sign-in check.")

	if GodotPlayGameServices.android_plugin:
		GodotPlayGameServices.android_plugin.userAuthenticated.connect(func(is_authenticated: bool) -> void:
			print("[Phase1Probe] userAuthenticated signal received -- is_authenticated=%s" % is_authenticated)
		)
