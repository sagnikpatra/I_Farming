## A single plot's lifecycle state. Port of GameModels.kt's `PlotState` sealed
## class (`Empty | Growing | ReadyToHarvest`).
##
## ARCHITECTURE NOTE (PlotState variant-pattern translation, per ADR-0002 and
## technical-preferences.md's GDScript naming conventions section):
##
## GDScript has no sealed-class equivalent. Two options were considered:
##   (a) a base class + one Resource subclass per variant (PlotStateEmpty,
##       PlotStateGrowing, PlotStateReadyToHarvest), closest structurally to
##       Kotlin's sealed class; or
##   (b) a single tagged Resource: one `kind` enum discriminant plus every
##       variant's payload fields declared side by side, only the fields
##       matching the current `kind` considered meaningful.
##
## This file implements (b), approved by the user (see EPIC-M2 architecture
## proposal). Reasoning: Godot's Resource (de)serialization of polymorphic
## subclass instances inside typed Arrays is a known source of friction
## (script-class resolution on load, harder .tres diffing) for comparatively
## little benefit at only 3 variants. A single tagged class serializes
## trivially and `match state.kind:` reads as cleanly as Kotlin's `when` here.
##
## The trade-off -- losing the compile-time guarantee that e.g.
## `weather_damaged` is only meaningful when `kind == READY_TO_HARVEST` -- is
## mitigated two ways: (1) construction is routed exclusively through the
## three static factories below, never bare `PlotState.new()` + manual field
## assignment from economy code; (2) every transition is covered explicitly
## in tests/unit/test_plot_state.gd, per ADR-0002's own risk mitigation.
class_name PlotState
extends Resource

enum Kind {
	EMPTY,
	GROWING,
	READY_TO_HARVEST,
}

@export var kind: Kind = Kind.EMPTY

## GROWING/READY_TO_HARVEST only. CropType.Kind ordinal; -1 when EMPTY.
@export var crop: int = -1
## GROWING only.
@export var planted_at_epoch_ms: int = 0
## GROWING only. Grow duration actually applied at planting time -- captures
## any Fan & Pad / Farmhouse / Monsoon speed bonus in effect *then*. Buying a
## speed upgrade mid-grow does not retroactively speed up this plot.
@export var effective_grow_seconds: int = 0
## READY_TO_HARVEST only. True if a random weather/pest event (or Polyhouse
## spoilage, checked separately at harvest time) clipped this yield.
@export var weather_damaged: bool = false
## READY_TO_HARVEST only.
@export var ready_at_epoch_ms: int = 0


static func new_empty() -> PlotState:
	var state := PlotState.new()
	state.kind = Kind.EMPTY
	return state


static func new_growing(crop_ordinal: int, planted_at_epoch_ms: int, effective_grow_seconds: int) -> PlotState:
	var state := PlotState.new()
	state.kind = Kind.GROWING
	state.crop = crop_ordinal
	state.planted_at_epoch_ms = planted_at_epoch_ms
	state.effective_grow_seconds = effective_grow_seconds
	return state


static func new_ready(crop_ordinal: int, weather_damaged: bool, ready_at_epoch_ms: int) -> PlotState:
	var state := PlotState.new()
	state.kind = Kind.READY_TO_HARVEST
	state.crop = crop_ordinal
	state.weather_damaged = weather_damaged
	state.ready_at_epoch_ms = ready_at_epoch_ms
	return state
