## GameState <-> plain Dictionary conversion, for the JSON transport layer
## adr-0003-cloud-save-and-player-accounts.md's Phase 0 requires (SEC-003 in
## production/security/security-audit-2026-08-21.md accepted Godot's
## ResourceLoader.load() risk *explicitly conditional on cloud sync never
## being added* -- this is that trigger. A `.tres` fetched from a network
## and loaded via ResourceLoader is a real remote-code-execution vector;
## this class's whole purpose is to never let that happen. to_dict()'s
## output is plain int/float/bool/String/Array/Dictionary data only --
## JSON-safe, no Godot Resource types, no ResourceLoader anywhere in
## from_dict()'s path.
##
## from_dict() trusts nothing: every enum ordinal is bounds-checked against
## its real source enum (the SEC-001 defect class -- an out-of-range
## ordinal previously caused a real repeating crash from local data alone;
## a network payload is a strictly less trusted input than that), every
## expected key/type is checked before use, and any single problem anywhere
## in the payload fails the whole parse (returns null) rather than
## constructing a partially-valid GameState.
##
## Local saves are unaffected by any of this -- SaveSystem's `.tres` path
## (a file this same client wrote) is untouched; this class exists
## alongside it for the day cloud sync actually ships, not as a replacement.
class_name SaveSerializer
extends RefCounted

## The authoritative "what does THIS client understand" version. Refuse to
## parse a Dictionary claiming a newer schema than this -- see from_dict()'s
## first check. Keep in sync by hand with GameState.schema_version's
## default (that field is what a *freshly created* state claims; this
## constant is what this build of the game actually knows how to read).
const CURRENT_SCHEMA_VERSION: int = 1


## Plain, JSON-safe Dictionary form of `state`. Never returns null -- a
## real GameState always has a valid representation.
static func to_dict(state: GameState) -> Dictionary:
	return {
		"schema_version": state.schema_version,
		"coins": state.coins,
		"plots": _plots_to_array(state.plots),
		"inventory": _int_keyed_resource_dict_to_dict(state.inventory, _crop_stock_to_dict),
		"last_weather_event": state.last_weather_event,
		"total_harvests": state.total_harvests,
		"has_polyhouse": state.has_polyhouse,
		"has_fan_pad": state.has_fan_pad,
		"has_drip_irrigation": state.has_drip_irrigation,
		"film_expires_at_epoch_ms": state.film_expires_at_epoch_ms,
		"has_agroforestry": state.has_agroforestry,
		"has_security": state.has_security,
		"has_aquaculture": state.has_aquaculture,
		"has_vertical_farm": state.has_vertical_farm,
		"electricity_expires_at_epoch_ms": state.electricity_expires_at_epoch_ms,
		"farmhouse_level": state.farmhouse_level,
		"has_mandi": state.has_mandi,
		"has_mandi_terminal": state.has_mandi_terminal,
		"mandi_glut": _int_keyed_resource_dict_to_dict(state.mandi_glut, _mandi_glut_to_dict),
		"event_occurrence_index": state.event_occurrence_index,
		"event_points": state.event_points,
		"event_has_premium_pass": state.event_has_premium_pass,
		"event_claimed_tier": state.event_claimed_tier,
		"chanda_last_resolved_cycle_index": state.chanda_last_resolved_cycle_index,
		"chanda_blessing_active_until": state.chanda_blessing_active_until,
		"gems": state.gems,
		"daily_task_day_key": state.daily_task_day_key,
		"daily_task_kinds": state.daily_task_kinds.duplicate(),
		"daily_task_progress": _int_keyed_int_dict_to_dict(state.daily_task_progress),
		"daily_task_claimed": _int_keyed_bool_dict_to_dict(state.daily_task_claimed),
		"daily_task_bonus_claimed": state.daily_task_bonus_claimed,
		"grow_skip_day_key": state.grow_skip_day_key,
		"grow_skip_used_today": state.grow_skip_used_today,
		"zone_layout": _zone_layout_to_dict(state.zone_layout),
		"decorations": _decorations_to_array(state.decorations),
		"next_decoration_id": state.next_decoration_id,
		"worker_assignments": _int_keyed_resource_dict_to_dict(state.worker_assignments, _worker_assignment_to_dict),
	}


## Parses `data` into a real GameState, or returns null if anything in it
## is invalid -- a missing/wrong-type key, an out-of-range enum ordinal, a
## newer schema_version than this client understands, anything. Never
## partially constructs a GameState on bad input.
static func from_dict(data: Dictionary) -> GameState:
	if not validate(data):
		return null

	var state := GameState.new()
	state.plots.clear()  # GameState._init() seeds starting plots -- replaced below with the real saved ones.
	state.schema_version = int(data["schema_version"])
	state.coins = int(data["coins"])
	for plot_data: Dictionary in data["plots"]:
		state.plots.append(_plot_from_dict(plot_data))
	state.inventory = _int_keyed_resource_dict_from_dict(data["inventory"], _crop_stock_from_dict)
	state.last_weather_event = String(data["last_weather_event"])
	state.total_harvests = int(data["total_harvests"])
	state.has_polyhouse = bool(data["has_polyhouse"])
	state.has_fan_pad = bool(data["has_fan_pad"])
	state.has_drip_irrigation = bool(data["has_drip_irrigation"])
	state.film_expires_at_epoch_ms = int(data["film_expires_at_epoch_ms"])
	state.has_agroforestry = bool(data["has_agroforestry"])
	state.has_security = bool(data["has_security"])
	state.has_aquaculture = bool(data["has_aquaculture"])
	state.has_vertical_farm = bool(data["has_vertical_farm"])
	state.electricity_expires_at_epoch_ms = int(data["electricity_expires_at_epoch_ms"])
	state.farmhouse_level = int(data["farmhouse_level"])
	state.has_mandi = bool(data["has_mandi"])
	state.has_mandi_terminal = bool(data["has_mandi_terminal"])
	state.mandi_glut = _int_keyed_resource_dict_from_dict(data["mandi_glut"], _mandi_glut_from_dict)
	state.event_occurrence_index = int(data["event_occurrence_index"])
	state.event_points = int(data["event_points"])
	state.event_has_premium_pass = bool(data["event_has_premium_pass"])
	state.event_claimed_tier = int(data["event_claimed_tier"])
	state.chanda_last_resolved_cycle_index = int(data["chanda_last_resolved_cycle_index"])
	state.chanda_blessing_active_until = int(data["chanda_blessing_active_until"])
	state.gems = int(data["gems"])
	state.daily_task_day_key = int(data["daily_task_day_key"])
	var kinds: Array[int] = []
	for k in data["daily_task_kinds"]:
		kinds.append(int(k))
	state.daily_task_kinds = kinds
	state.daily_task_progress = _int_keyed_int_dict_from_dict(data["daily_task_progress"])
	state.daily_task_claimed = _int_keyed_bool_dict_from_dict(data["daily_task_claimed"])
	state.daily_task_bonus_claimed = bool(data["daily_task_bonus_claimed"])
	state.grow_skip_day_key = int(data["grow_skip_day_key"])
	state.grow_skip_used_today = bool(data["grow_skip_used_today"])
	state.zone_layout = _zone_layout_from_dict(data["zone_layout"])
	state.decorations = _decorations_from_array(data["decorations"])
	state.next_decoration_id = int(data["next_decoration_id"])
	state.worker_assignments = _int_keyed_resource_dict_from_dict(data["worker_assignments"], _worker_assignment_from_dict)
	return state


## True if `data` is a fully well-formed GameState Dictionary -- every
## required key present with the right type, every enum ordinal in range,
## schema_version not newer than this client understands. Does not mutate
## or construct anything; from_dict() calls this first and only proceeds
## to build a GameState if it passes.
static func validate(data: Dictionary) -> bool:
	if not _has_keys(data, [
		"schema_version", "coins", "plots", "inventory", "last_weather_event", "total_harvests",
		"has_polyhouse", "has_fan_pad", "has_drip_irrigation", "film_expires_at_epoch_ms",
		"has_agroforestry", "has_security", "has_aquaculture", "has_vertical_farm",
		"electricity_expires_at_epoch_ms", "farmhouse_level", "has_mandi", "has_mandi_terminal",
		"mandi_glut", "event_occurrence_index", "event_points", "event_has_premium_pass",
		"event_claimed_tier", "chanda_last_resolved_cycle_index", "chanda_blessing_active_until",
		"gems", "daily_task_day_key", "daily_task_kinds", "daily_task_progress", "daily_task_claimed",
		"daily_task_bonus_claimed", "grow_skip_day_key", "grow_skip_used_today",
		"zone_layout", "decorations", "next_decoration_id", "worker_assignments",
	]):
		return false

	if not _is_int(data["schema_version"]) or int(data["schema_version"]) > CURRENT_SCHEMA_VERSION:
		return false  # refuse a schema newer than this client understands
	if not _is_int(data["coins"]):
		return false
	if not (data["plots"] is Array):
		return false
	for plot_data in data["plots"]:
		if not (plot_data is Dictionary) or not _validate_plot(plot_data):
			return false
	if not (data["inventory"] is Dictionary) or not _validate_int_keyed_dict(data["inventory"], _validate_crop_stock, CropType.Kind.size()):
		return false
	if not (data["last_weather_event"] is String):
		return false
	for key in [
		"total_harvests", "film_expires_at_epoch_ms", "electricity_expires_at_epoch_ms",
		"event_occurrence_index", "event_points", "chanda_last_resolved_cycle_index",
		"chanda_blessing_active_until", "gems", "daily_task_day_key", "next_decoration_id",
		"grow_skip_day_key",
	]:
		if not _is_int(data[key]):
			return false
	for key in ["has_polyhouse", "has_fan_pad", "has_drip_irrigation", "has_agroforestry", "has_security", "has_aquaculture", "has_vertical_farm", "has_mandi", "has_mandi_terminal", "event_has_premium_pass", "daily_task_bonus_claimed", "grow_skip_used_today"]:
		if not (data[key] is bool):
			return false
	if not _is_int(data["farmhouse_level"]) or int(data["farmhouse_level"]) < 0:
		return false
	if not (data["mandi_glut"] is Dictionary) or not _validate_int_keyed_dict(data["mandi_glut"], _validate_mandi_glut, CropType.Kind.size()):
		return false
	if not _is_int(data["event_claimed_tier"]) or int(data["event_claimed_tier"]) < 0:
		return false
	if not (data["daily_task_kinds"] is Array):
		return false
	for k in data["daily_task_kinds"]:
		if not _is_int(k) or int(k) < 0 or int(k) >= DailyTaskKind.Kind.size():
			return false
	if not (data["daily_task_progress"] is Dictionary) or not _validate_int_keyed_dict(data["daily_task_progress"], _validate_plain_int, DailyTaskKind.Kind.size()):
		return false
	if not (data["daily_task_claimed"] is Dictionary) or not _validate_int_keyed_dict(data["daily_task_claimed"], _validate_plain_bool, DailyTaskKind.Kind.size()):
		return false
	if not (data["zone_layout"] is Dictionary):
		return false
	for zone_id in data["zone_layout"].keys():
		if not (zone_id is String) or not _validate_zone_anchor(data["zone_layout"][zone_id]):
			return false
	if not (data["decorations"] is Array):
		return false
	for decoration_data in data["decorations"]:
		if not (decoration_data is Dictionary) or not _validate_decoration(decoration_data):
			return false
	if not (data["worker_assignments"] is Dictionary) or not _validate_int_keyed_dict(data["worker_assignments"], _validate_worker_assignment, PlotKind.Kind.size()):
		return false
	return true


# --- Plot ---------------------------------------------------------------------

static func _plot_to_dict(plot: Plot) -> Dictionary:
	return {
		"id": plot.id,
		"kind": plot.kind,
		"state": _plot_state_to_dict(plot.state),
		"agro_row": plot.agro_row,
		"agro_col": plot.agro_col,
		"host_type": plot.host_type,
	}


static func _plots_to_array(plots: Array[Plot]) -> Array:
	var result: Array = []
	for plot in plots:
		result.append(_plot_to_dict(plot))
	return result


static func _validate_plot(data: Dictionary) -> bool:
	if not _has_keys(data, ["id", "kind", "state", "agro_row", "agro_col", "host_type"]):
		return false
	if not _is_int(data["id"]):
		return false
	if not _is_int(data["kind"]) or int(data["kind"]) < 0 or int(data["kind"]) >= PlotKind.Kind.size():
		return false
	if not (data["state"] is Dictionary) or not _validate_plot_state(data["state"]):
		return false
	if not _is_int(data["agro_row"]) or not _is_int(data["agro_col"]):
		return false
	var host: int = int(data["host_type"]) if _is_int(data["host_type"]) else -99
	if host != HostType.NONE and (host < 0 or host >= HostType.Kind.size()):
		return false
	return true


static func _plot_from_dict(data: Dictionary) -> Plot:
	var plot := Plot.new(int(data["id"]), int(data["kind"]) as PlotKind.Kind)
	plot.state = _plot_state_from_dict(data["state"])
	plot.agro_row = int(data["agro_row"])
	plot.agro_col = int(data["agro_col"])
	plot.host_type = int(data["host_type"])
	return plot


# --- PlotState ------------------------------------------------------------------

static func _plot_state_to_dict(state: PlotState) -> Dictionary:
	return {
		"kind": state.kind,
		"crop": state.crop,
		"planted_at_epoch_ms": state.planted_at_epoch_ms,
		"effective_grow_seconds": state.effective_grow_seconds,
		"weather_damaged": state.weather_damaged,
		"ready_at_epoch_ms": state.ready_at_epoch_ms,
	}


static func _validate_plot_state(data: Dictionary) -> bool:
	if not _has_keys(data, ["kind", "crop", "planted_at_epoch_ms", "effective_grow_seconds", "weather_damaged", "ready_at_epoch_ms"]):
		return false
	if not _is_int(data["kind"]) or int(data["kind"]) < 0 or int(data["kind"]) >= PlotState.Kind.size():
		return false
	# crop is -1 (no crop, EMPTY) or a valid CropType.Kind ordinal.
	var crop: int = int(data["crop"]) if _is_int(data["crop"]) else -99
	if crop != -1 and (crop < 0 or crop >= CropType.Kind.size()):
		return false
	if not _is_int(data["planted_at_epoch_ms"]) or not _is_int(data["effective_grow_seconds"]):
		return false
	if not (data["weather_damaged"] is bool):
		return false
	if not _is_int(data["ready_at_epoch_ms"]):
		return false
	return true


static func _plot_state_from_dict(data: Dictionary) -> PlotState:
	var state := PlotState.new()
	state.kind = int(data["kind"]) as PlotState.Kind
	state.crop = int(data["crop"])
	state.planted_at_epoch_ms = int(data["planted_at_epoch_ms"])
	state.effective_grow_seconds = int(data["effective_grow_seconds"])
	state.weather_damaged = bool(data["weather_damaged"])
	state.ready_at_epoch_ms = int(data["ready_at_epoch_ms"])
	return state


# --- CropStock --------------------------------------------------------------------

static func _crop_stock_to_dict(stock: CropStock) -> Dictionary:
	return {"normal": stock.normal, "damaged": stock.damaged}


static func _validate_crop_stock(data: Variant) -> bool:
	if not (data is Dictionary) or not _has_keys(data, ["normal", "damaged"]):
		return false
	return _is_int(data["normal"]) and _is_int(data["damaged"])


static func _crop_stock_from_dict(data: Dictionary) -> CropStock:
	return CropStock.new(int(data["normal"]), int(data["damaged"]))


# --- MandiGlut ----------------------------------------------------------------------

static func _mandi_glut_to_dict(glut: MandiGlut) -> Dictionary:
	return {"value": glut.value, "updated_at_epoch_ms": glut.updated_at_epoch_ms}


static func _validate_mandi_glut(data: Variant) -> bool:
	if not (data is Dictionary) or not _has_keys(data, ["value", "updated_at_epoch_ms"]):
		return false
	var value_ok: bool = data["value"] is float or data["value"] is int
	return value_ok and _is_int(data["updated_at_epoch_ms"])


static func _mandi_glut_from_dict(data: Dictionary) -> MandiGlut:
	return MandiGlut.new(float(data["value"]), int(data["updated_at_epoch_ms"]))


# --- Decoration -----------------------------------------------------------------

static func _decoration_to_dict(decoration: Decoration) -> Dictionary:
	return {
		"id": decoration.id,
		"type": decoration.type,
		"tile_x": decoration.tile_x,
		"tile_y": decoration.tile_y,
		"rotation_degrees": decoration.rotation_degrees,
		"flipped_x": decoration.flipped_x,
	}


static func _decorations_to_array(decorations: Array[Decoration]) -> Array:
	var result: Array = []
	for decoration in decorations:
		result.append(_decoration_to_dict(decoration))
	return result


static func _validate_decoration(data: Dictionary) -> bool:
	if not _has_keys(data, ["id", "type", "tile_x", "tile_y", "rotation_degrees", "flipped_x"]):
		return false
	if not _is_int(data["id"]):
		return false
	if not _is_int(data["type"]) or int(data["type"]) < 0 or int(data["type"]) >= DecorationType.Kind.size():
		return false
	if not (data["tile_x"] is float or data["tile_x"] is int) or not (data["tile_y"] is float or data["tile_y"] is int):
		return false
	if not _is_int(data["rotation_degrees"]):
		return false
	if not (data["flipped_x"] is bool):
		return false
	return true


static func _decorations_from_array(data: Array) -> Array[Decoration]:
	var result: Array[Decoration] = []
	for decoration_data: Dictionary in data:
		result.append(Decoration.new(
			int(decoration_data["id"]),
			int(decoration_data["type"]),
			float(decoration_data["tile_x"]),
			float(decoration_data["tile_y"]),
			int(decoration_data["rotation_degrees"]),
			bool(decoration_data["flipped_x"]),
		))
	return result


# --- ZoneAnchor -----------------------------------------------------------------

static func _zone_anchor_to_dict(anchor: ZoneAnchor) -> Dictionary:
	return {
		"tile_x": anchor.tile_x,
		"tile_y": anchor.tile_y,
		"rotation_degrees": anchor.rotation_degrees,
		"flipped_x": anchor.flipped_x,
	}


static func _zone_layout_to_dict(zone_layout: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for zone_id: String in zone_layout.keys():
		result[zone_id] = _zone_anchor_to_dict(zone_layout[zone_id])
	return result


static func _validate_zone_anchor(data: Variant) -> bool:
	if not (data is Dictionary) or not _has_keys(data, ["tile_x", "tile_y", "rotation_degrees", "flipped_x"]):
		return false
	if not (data["tile_x"] is float or data["tile_x"] is int) or not (data["tile_y"] is float or data["tile_y"] is int):
		return false
	if not _is_int(data["rotation_degrees"]):
		return false
	return data["flipped_x"] is bool


static func _zone_layout_from_dict(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for zone_id in data.keys():
		var anchor_data: Dictionary = data[zone_id]
		result[String(zone_id)] = ZoneAnchor.new(
			float(anchor_data["tile_x"]), float(anchor_data["tile_y"]),
			int(anchor_data["rotation_degrees"]), bool(anchor_data["flipped_x"]),
		)
	return result


# --- WorkerAssignment -----------------------------------------------------------

static func _worker_assignment_to_dict(assignment: WorkerAssignment) -> Dictionary:
	return {"plot_kind": assignment.plot_kind, "character_key": assignment.character_key}


static func _validate_worker_assignment(data: Variant) -> bool:
	if not (data is Dictionary) or not _has_keys(data, ["plot_kind", "character_key"]):
		return false
	if not _is_int(data["plot_kind"]) or int(data["plot_kind"]) < 0 or int(data["plot_kind"]) >= PlotKind.Kind.size():
		return false
	return data["character_key"] is String


static func _worker_assignment_from_dict(data: Dictionary) -> WorkerAssignment:
	return WorkerAssignment.new(int(data["plot_kind"]) as PlotKind.Kind, String(data["character_key"]))


# --- Generic int-keyed-dictionary helpers (inventory/mandi_glut/daily_task_*/worker_assignments) ---
# JSON object keys must be strings -- these convert the int-ordinal keys
# GameState actually uses to/from string keys for the JSON-safe dict form.

static func _int_keyed_resource_dict_to_dict(source: Dictionary, value_to_dict: Callable) -> Dictionary:
	var result: Dictionary = {}
	for key: int in source.keys():
		result[str(key)] = value_to_dict.call(source[key])
	return result


static func _int_keyed_resource_dict_from_dict(data: Dictionary, value_from_dict: Callable) -> Dictionary:
	var result: Dictionary = {}
	for key_str in data.keys():
		result[int(key_str)] = value_from_dict.call(data[key_str])
	return result


static func _int_keyed_int_dict_to_dict(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: int in source.keys():
		result[str(key)] = int(source[key])
	return result


static func _int_keyed_int_dict_from_dict(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_str in data.keys():
		result[int(key_str)] = int(data[key_str])
	return result


static func _int_keyed_bool_dict_to_dict(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: int in source.keys():
		result[str(key)] = bool(source[key])
	return result


static func _int_keyed_bool_dict_from_dict(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_str in data.keys():
		result[int(key_str)] = bool(data[key_str])
	return result


## Every key in an int-keyed dict must (a) be a string that parses as a
## valid int, (b) fall within [0, ordinal_count), and (c) have a value that
## passes `validate_value`. `ordinal_count` is the owning enum's real size
## (e.g. CropType.Kind.size()) -- never a hand-copied magic number that
## could silently drift from the real enum.
static func _validate_int_keyed_dict(data: Dictionary, validate_value: Callable, ordinal_count: int) -> bool:
	for key_str in data.keys():
		if not (key_str is String) or not key_str.is_valid_int():
			return false
		var ordinal := int(key_str)
		if ordinal < 0 or ordinal >= ordinal_count:
			return false
		if not validate_value.call(data[key_str]):
			return false
	return true


static func _validate_plain_int(value: Variant) -> bool:
	return _is_int(value)


static func _validate_plain_bool(value: Variant) -> bool:
	return value is bool


# --- Shared primitives ------------------------------------------------------------

static func _has_keys(data: Dictionary, keys: Array) -> bool:
	for key in keys:
		if not data.has(key):
			return false
	return true


## Godot's JSON parser turns every number into a float, so a payload that
## legitimately came from JSON.parse_string() would fail an `is int` check
## on every field even when correct -- accept a whole-number float as an
## int too, exactly the leniency a real JSON transport needs.
static func _is_int(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(value) and float(value) == floor(value)
	return false
