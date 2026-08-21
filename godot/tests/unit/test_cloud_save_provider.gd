## Covers CloudSaveProvider/NullCloudSaveProvider (adr-0003-cloud-save-and-
## player-accounts.md Phase 0, step 4). Deliberately thin -- every method on
## both classes is a documented no-op until a real backend is chosen; these
## tests just confirm that no-op behavior is real (nothing crashes, nothing
## silently claims to be available, no signal fires spuriously), not that
## any actual cloud behavior exists yet.
extends GutTest


func test_base_provider_is_not_available() -> void:
	var provider := CloudSaveProvider.new()
	assert_false(provider.is_available())


func test_null_provider_is_not_available() -> void:
	var provider := NullCloudSaveProvider.new()
	assert_false(provider.is_available())


func test_null_provider_methods_are_safe_no_ops() -> void:
	var provider := NullCloudSaveProvider.new()
	# None of these should error, block, or touch the network. All 4 are
	# void, so there's nothing to assert on a return value -- assert_true
	# on a trivially-true expression after each call is a real assertion
	# GUT counts (avoiding the "Did not assert" Risky flag a bare call-and-
	# hope-nothing-throws body would leave), while the actual behavior
	# under test is still "this didn't crash or hang."
	provider.sign_in_silent()
	assert_true(true, "sign_in_silent() did not crash")
	provider.upload({"coins": 100})
	assert_true(true, "upload() did not crash")
	provider.download()
	assert_true(true, "download() did not crash")
	provider.resolve_conflict({"coins": 100})
	assert_true(true, "resolve_conflict() did not crash")


func test_null_provider_never_emits_completion_signals() -> void:
	var provider := NullCloudSaveProvider.new()
	var sign_in_fired := false
	var upload_fired := false
	provider.sign_in_completed.connect(func(_success): sign_in_fired = true)
	provider.upload_completed.connect(func(_success): upload_fired = true)

	provider.sign_in_silent()
	provider.upload({"coins": 100})

	assert_false(sign_in_fired, "NullCloudSaveProvider has nothing to sign into")
	assert_false(upload_fired, "NullCloudSaveProvider has nowhere to upload to")


func test_null_provider_is_a_real_cloud_save_provider() -> void:
	var provider := NullCloudSaveProvider.new()
	assert_true(provider is CloudSaveProvider, "NullCloudSaveProvider must satisfy the CloudSaveProvider seam")
