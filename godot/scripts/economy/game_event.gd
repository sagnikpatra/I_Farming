## One-off notification the player-facing layer should show and then dismiss
## (snackbars, toasts, dev-console print lines). Port of GameViewModel.kt's
## `GameEvent` sealed class -- currently only the `Info(message)` case exists
## in the Kotlin source, so this is a plain message holder rather than another
## tagged-variant type.
##
## Not a Resource: events are transient (drained from GameEconomy.pending_events
## as they're produced) and are never part of GameState's persisted save data.
##
## BUGFIX (per EPIC-M2 brief, item b): the Kotlin original held events in a
## single `MutableStateFlow<GameEvent?>`, so three messages produced in one
## resolution pass (e.g. weather damage + theft + flood all firing inside one
## resolve_growth_completions() call) silently overwrote down to just the
## last one. GameEconomy.pending_events is a real Array/queue instead -- see
## game_economy.gd and tests/unit/test_event_queue_bugfix.gd.
##
## Localization/toast pass (docs/architecture/localization-pipeline.md's
## Related section; the toast drain itself is hud.gd's, see
## _drain_pending_events()): this queue went undrained by any real UI for a
## long time -- `is_rejection` was added once a drain finally landed, so a
## rejected action's message can trigger the already-catalogued
## `ui_action_rejected` SFX (audio_catalogue.gd) while a neutral/positive
## event doesn't. Additive (defaults false) -- every pre-existing
## GameEvent.new(message) call site with only one argument keeps compiling
## and keeps its prior (non-rejection) behavior unchanged.
class_name GameEvent
extends RefCounted

var message: String
var is_rejection: bool


func _init(p_message: String = "", p_is_rejection: bool = false) -> void:
	message = p_message
	is_rejection = p_is_rejection
