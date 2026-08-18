## FIXTURE DATA — a single 1x1-tile crop plot attached to a zone, as rendered
## by the village board. Built fresh every rebuild by VillageSnapshotMapper
## from the real economy's Plot/PlotState (see scripts/economy/plot.gd,
## plot_state.gd) -- this class itself carries no economy logic, purely
## render-facing data.
class_name PlotFixture
extends RefCounted

## Mirrors PlotState.Kind 1:1, plus GHOST for the one rendering-only case with
## no real economy Plot behind it: the "next available open-field slot"
## preview tile VillageSnapshotMapper adds while open_field_count < MAX_PLOTS.
enum Lifecycle { EMPTY, GROWING, READY_TO_HARVEST, GHOST }

var tile_col: int
var tile_row: int
## Short debug string (crop display name, "host", "next_expansion", etc.) --
## not consumed by any rendering logic, purely for diagnostics/node naming.
var label: String
var lifecycle: Lifecycle = Lifecycle.EMPTY
## Aquaculture tint -- true for every plot attached to the Aquaculture zone.
var is_water: bool = false
## Agroforestry: true when a host plant (see scripts/economy/host_type.gd)
## fills this cell. Plot.state.kind stays EMPTY forever for host cells (see
## game_economy.gd's plant_host()/remove_host()), so `lifecycle` is
## meaningless when this is true -- host-occupied rendering takes precedence.
var host_occupied: bool = false
## The real Plot.id this fixture renders, or -1 for a GHOST fixture with no
## backing Plot. Not consumed by anything yet -- carried through for future
## tap-to-plant UI.
var plot_id: int = -1

func _init(p_tile_col: int, p_tile_row: int, p_label: String = "plot") -> void:
	tile_col = p_tile_col
	tile_row = p_tile_row
	label = p_label
