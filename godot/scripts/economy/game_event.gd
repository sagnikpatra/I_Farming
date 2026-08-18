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
class_name GameEvent
extends RefCounted

var message: String


func _init(p_message: String = "") -> void:
	message = p_message
