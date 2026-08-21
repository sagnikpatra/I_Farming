## Covers SaveSerializer (adr-0003-cloud-save-and-player-accounts.md Phase
## 0): round-trip fidelity through the JSON-safe Dictionary form, real
## JSON-transport safety (not just asserted -- actually round-tripped
## through JSON.stringify()/parse_string()), and hostile-input rejection
## (the SEC-001 defect class -- an out-of-range enum ordinal must never
## reach GameState construction). Every case here is what a downloaded
## cloud save could plausibly contain -- SaveSystem's local `.tres` path is
## untouched and not covered here.
extends GutTest

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 50_000


# --- Round-trip fidelity -----------------------------------------------------------

func test_fresh_state_round_trips_through_to_dict_and_from_dict() -> void:
	var data := SaveSerializer.to_dict(eco.state)
	var restored := SaveSerializer.from_dict(data)

	assert_not_null(restored)
	assert_eq(restored.coins, eco.state.coins)
	assert_eq(restored.plots.size(), eco.state.plots.size())
	assert_eq(restored.schema_version, SaveSerializer.CURRENT_SCHEMA_VERSION)


func test_a_richly_populated_state_round_trips_field_for_field() -> void:
	# Exercise real economy actions so this isn't just testing empty/default
	# values -- plots, inventory, structures, LiveOps state, decorations,
	# zone layout, and worker assignments all get real, non-default data.
	var now: int = 1_700_000_000_000
	# Generous starting balance -- several real purchases below (Polyhouse,
	# Fan & Pad, Agroforestry, Security) must all actually succeed, not
	# silently no-op on insufficient funds (this file's established guard-
	# clause style, same as every other GameEconomy test's own balance).
	eco.state.coins = 10_000_000
	eco.plant_seed(eco.state.plots[0].id, CropType.Kind.WHEAT, now)
	eco.state.inventory[CropType.Kind.PADDY] = CropStock.new(4, 2)
	eco.state.total_harvests = 7
	eco.buy_polyhouse()
	eco.buy_fan_pad()
	eco.state.film_expires_at_epoch_ms = now + 10_000
	eco.buy_agroforestry()
	eco.buy_security()
	eco.state.farmhouse_level = 3
	eco.state.has_mandi = true
	eco.state.mandi_glut[CropType.Kind.TOMATO] = MandiGlut.new(0.42, now)
	eco.state.event_occurrence_index = 5
	eco.state.event_points = 80
	eco.state.event_claimed_tier = 1
	eco.give_chanda(now)
	eco.state.gems = 17
	_set_todays_tasks(now, [DailyTaskKind.Kind.HARVEST, DailyTaskKind.Kind.SELL])
	eco.state.daily_task_progress[DailyTaskKind.Kind.HARVEST] = 2
	eco.state.zone_layout["farmhouse"] = ZoneAnchor.new(3.5, 2.0, 90, true)
	eco.state.decorations.append(Decoration.new(1, DecorationType.Kind.LANTERN, 4.0, 5.0, 180, false))
	eco.state.next_decoration_id = 2
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "mage")

	var data := SaveSerializer.to_dict(eco.state)
	var restored := SaveSerializer.from_dict(data)

	assert_not_null(restored)
	# Several purchases above spend down from the starting balance -- assert
	# against the real post-purchase value, not a hardcoded starting number.
	assert_eq(restored.coins, eco.state.coins)
	assert_eq(restored.plots[0].state.kind, PlotState.Kind.GROWING)
	assert_eq(restored.plots[0].state.crop, CropType.Kind.WHEAT)
	var restored_paddy: CropStock = restored.inventory[CropType.Kind.PADDY]
	assert_eq(restored_paddy.normal, 4)
	assert_eq(restored_paddy.damaged, 2)
	assert_eq(restored.total_harvests, 7)
	assert_true(restored.has_polyhouse)
	assert_true(restored.has_fan_pad)
	assert_eq(restored.film_expires_at_epoch_ms, now + 10_000)
	assert_true(restored.has_agroforestry)
	assert_true(restored.has_security)
	assert_eq(restored.farmhouse_level, 3)
	assert_true(restored.has_mandi)
	var restored_glut: MandiGlut = restored.mandi_glut[CropType.Kind.TOMATO]
	assert_almost_eq(restored_glut.value, 0.42, 0.0001)
	assert_eq(restored_glut.updated_at_epoch_ms, now)
	assert_eq(restored.event_occurrence_index, 5)
	assert_eq(restored.event_points, 80)
	assert_eq(restored.event_claimed_tier, 1)
	assert_eq(restored.chanda_last_resolved_cycle_index, eco.state.chanda_last_resolved_cycle_index)
	assert_eq(restored.gems, 17)
	assert_eq(restored.daily_task_progress[DailyTaskKind.Kind.HARVEST], 2)
	var restored_anchor: ZoneAnchor = restored.zone_layout["farmhouse"]
	assert_almost_eq(restored_anchor.tile_x, 3.5, 0.0001)
	assert_eq(restored_anchor.rotation_degrees, 90)
	assert_true(restored_anchor.flipped_x)
	assert_eq(restored.decorations.size(), 1)
	assert_eq(restored.decorations[0].type, DecorationType.Kind.LANTERN)
	assert_eq(restored.next_decoration_id, 2)
	var restored_worker: WorkerAssignment = restored.worker_assignments[PlotKind.Kind.OPEN_FIELD]
	assert_eq(restored_worker.character_key, "mage")


func test_round_trip_survives_a_real_json_transport() -> void:
	# Not just asserting "this is JSON-safe" -- actually proving it by
	# passing the dict through Godot's real JSON encoder/decoder, the exact
	# transport adr-0003 requires instead of a `.tres` fetched from a
	# network (SEC-003's trigger condition).
	eco.state.coins = 999
	eco.state.zone_layout["farmhouse"] = ZoneAnchor.new(1.0, 2.0, 0, false)

	var data := SaveSerializer.to_dict(eco.state)
	var json_text := JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(json_text)

	assert_true(parsed is Dictionary, "JSON round trip should produce a Dictionary back")
	var restored := SaveSerializer.from_dict(parsed)
	assert_not_null(restored, "a real JSON round trip must still validate and parse")
	assert_eq(restored.coins, 999)


func _set_todays_tasks(now: int, kinds: Array[int]) -> void:
	eco.state.daily_task_day_key = eco._current_local_day_key(now)
	eco.state.daily_task_kinds = kinds
	eco.state.daily_task_progress = {}
	eco.state.daily_task_claimed = {}
	eco.state.daily_task_bonus_claimed = false


# --- validate() / from_dict() hostile-input rejection -------------------------------

func test_missing_required_key_is_rejected() -> void:
	var data := SaveSerializer.to_dict(eco.state)
	data.erase("coins")
	assert_false(SaveSerializer.validate(data))
	assert_null(SaveSerializer.from_dict(data))


func test_wrong_type_for_a_field_is_rejected() -> void:
	var data := SaveSerializer.to_dict(eco.state)
	data["coins"] = "not a number"
	assert_false(SaveSerializer.validate(data))
	assert_null(SaveSerializer.from_dict(data))


func test_out_of_range_plot_kind_ordinal_is_rejected() -> void:
	var data := SaveSerializer.to_dict(eco.state)
	data["plots"][0]["kind"] = 9999
	assert_false(SaveSerializer.validate(data))
	assert_null(SaveSerializer.from_dict(data))


func test_out_of_range_crop_ordinal_in_plot_state_is_rejected() -> void:
	var data := SaveSerializer.to_dict(eco.state)
	data["plots"][0]["state"]["crop"] = 9999
	assert_false(SaveSerializer.validate(data))
	assert_null(SaveSerializer.from_dict(data))


func test_negative_crop_ordinal_other_than_the_no_crop_sentinel_is_rejected() -> void:
	var data := SaveSerializer.to_dict(eco.state)
	data["plots"][0]["state"]["crop"] = -2  # -1 is the only valid "no crop" sentinel
	assert_false(SaveSerializer.validate(data))


func test_out_of_range_decoration_type_ordinal_is_rejected() -> void:
	eco.state.decorations.append(Decoration.new(1, DecorationType.Kind.LANTERN, 1.0, 1.0, 0, false))
	var data := SaveSerializer.to_dict(eco.state)
	data["decorations"][0]["type"] = 9999
	assert_false(SaveSerializer.validate(data))
	assert_null(SaveSerializer.from_dict(data))


func test_out_of_range_int_keyed_dict_key_is_rejected() -> void:
	var data := SaveSerializer.to_dict(eco.state)
	data["inventory"]["9999"] = {"normal": 1, "damaged": 0}
	assert_false(SaveSerializer.validate(data))
	assert_null(SaveSerializer.from_dict(data))


func test_non_numeric_int_keyed_dict_key_is_rejected() -> void:
	var data := SaveSerializer.to_dict(eco.state)
	data["inventory"]["not_a_number"] = {"normal": 1, "damaged": 0}
	assert_false(SaveSerializer.validate(data))
	assert_null(SaveSerializer.from_dict(data))


func test_schema_version_newer_than_this_client_understands_is_rejected() -> void:
	var data := SaveSerializer.to_dict(eco.state)
	data["schema_version"] = SaveSerializer.CURRENT_SCHEMA_VERSION + 1
	assert_false(SaveSerializer.validate(data))
	assert_null(SaveSerializer.from_dict(data))


func test_malformed_plots_array_is_rejected() -> void:
	var data := SaveSerializer.to_dict(eco.state)
	data["plots"] = "not an array"
	assert_false(SaveSerializer.validate(data))
	assert_null(SaveSerializer.from_dict(data))


func test_plot_missing_a_required_key_is_rejected() -> void:
	var data := SaveSerializer.to_dict(eco.state)
	data["plots"][0].erase("state")
	assert_false(SaveSerializer.validate(data))
	assert_null(SaveSerializer.from_dict(data))


func test_completely_empty_dictionary_is_rejected_not_crashed_on() -> void:
	assert_false(SaveSerializer.validate({}))
	assert_null(SaveSerializer.from_dict({}))


func test_deliberately_adversarial_payload_is_rejected() -> void:
	# A payload an attacker might actually construct: right shape, but
	# poisoned enum ordinals and a claimed-future schema version throughout.
	var data := SaveSerializer.to_dict(eco.state)
	data["schema_version"] = 999
	data["farmhouse_level"] = -1
	data["worker_assignments"]["9999"] = {"plot_kind": 9999, "character_key": "hacker"}
	assert_false(SaveSerializer.validate(data))
	assert_null(SaveSerializer.from_dict(data))
