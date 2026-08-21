## Interface for cloud save backends (adr-0003-cloud-save-and-player-
## accounts.md). This is the seam the ADR's Migration Plan calls "swap
## backends here" -- concrete implementations (a future PgsSnapshotProvider,
## or an HttpCloudProvider if this project ever moves to Supabase per that
## ADR's own migration path) plug in behind this same interface without any
## other code needing to change. Phase 0 (this file + NullCloudProvider)
## ships with no backend chosen yet -- the interface exists so
## SaveSerializer's JSON-safe output already has somewhere real to go once
## a Phase 1 spike picks one.
##
## Base class, not an abstract/pure-virtual one -- GDScript has no formal
## interface keyword. Every method here is a documented no-op by design (see
## NullCloudProvider below, which doesn't even need to override anything);
## a real provider overrides what it actually implements.
class_name CloudSaveProvider
extends RefCounted

signal sign_in_completed(success: bool)
signal upload_completed(success: bool)
signal download_completed(success: bool, payload: Dictionary)
signal conflict_detected(local: Dictionary, remote: Dictionary)


## False for the base class and NullCloudProvider -- callers must check
## this before relying on any of the methods below actually doing
## anything network-related.
func is_available() -> bool:
	return false


## Fire-and-forget by design (the ADR's own Risk table: "never `await` on a
## gameplay or startup path"). Base implementation never signals
## sign_in_completed -- there is nothing to sign into.
func sign_in_silent() -> void:
	pass


func upload(_payload: Dictionary) -> void:
	pass


func download() -> void:
	pass


func resolve_conflict(_chosen: Dictionary) -> void:
	pass
