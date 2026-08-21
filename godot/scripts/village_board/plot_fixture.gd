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
## Which PlotKind this plot belongs to -- set by VillageSnapshotMapper from
## the zone/plot context it was built in (the real Plot.kind for a real plot;
## the owning zone's implied kind for a GHOST tile, e.g. OPEN_FIELD).
## Meaningless (left at the default) for fixtures that don't carry it
## explicitly, but every real builder function sets it. Read by
## board_interactor.gd (via village_board.gd's PickArea meta) to decide which
## crops GameData.crops_for_plot_kind() should offer in the seed picker.
var kind: PlotKind.Kind = PlotKind.Kind.OPEN_FIELD
## Crop growth-stage geometry pass: the real Plot.state.crop this fixture was
## built from -- CropType.Kind ordinal, or -1 for a plot with no planted crop
## (EMPTY, GHOST, or an Agroforestry host-occupied cell, mirroring
## PlotState.crop's own "-1 when EMPTY" convention, see plot_state.gd). Read
## by village_board.gd's _build_plot() via VillageFixtureData.
## crop_stage_model_path() to pick a real staged crop model (Wheat/Tomato/
## Capsicum) instead of the flat dirt-mesh+tint fallback, when one exists for
## this crop.
var crop: int = -1

func _init(p_tile_col: int, p_tile_row: int, p_label: String = "plot") -> void:
	tile_col = p_tile_col
	tile_row = p_tile_row
	label = p_label
