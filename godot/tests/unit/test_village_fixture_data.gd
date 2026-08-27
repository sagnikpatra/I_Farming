## Covers VillageFixtureData.crop_stage_model_path() -- the pure crop-ordinal
## + stage -> staged-model-path lookup added for the crop growth-stage
## geometry pass (Track B sourced the models into assets_3d/ but deliberately
## left them unwired -- see design/art/ui-visual-direction-2026-08.md, §3).
## Exercises every CropType.Kind ordinal explicitly so a future crop addition
## that forgets to extend the match's `_` fallback is caught here rather than
## silently rendering a bad-fit model on the board.
extends GutTest


func test_wheat_growing_returns_wheat_stage_a() -> void:
	assert_eq(
		VillageFixtureData.crop_stage_model_path(CropType.Kind.WHEAT, false),
		VillageFixtureData.CROP_WHEAT_STAGE_GROWING
	)


func test_wheat_ready_returns_wheat_stage_b() -> void:
	assert_eq(
		VillageFixtureData.crop_stage_model_path(CropType.Kind.WHEAT, true),
		VillageFixtureData.CROP_WHEAT_STAGE_READY
	)


func test_tomato_growing_and_ready_use_the_leafy_stand_in_model() -> void:
	assert_eq(
		VillageFixtureData.crop_stage_model_path(CropType.Kind.TOMATO, false),
		VillageFixtureData.CROP_LEAFY_STAGE_GROWING
	)
	assert_eq(
		VillageFixtureData.crop_stage_model_path(CropType.Kind.TOMATO, true),
		VillageFixtureData.CROP_LEAFY_STAGE_READY
	)


func test_capsicum_growing_and_ready_use_the_leafy_stand_in_model() -> void:
	assert_eq(
		VillageFixtureData.crop_stage_model_path(CropType.Kind.CAPSICUM, false),
		VillageFixtureData.CROP_LEAFY_STAGE_GROWING
	)
	assert_eq(
		VillageFixtureData.crop_stage_model_path(CropType.Kind.CAPSICUM, true),
		VillageFixtureData.CROP_LEAFY_STAGE_READY
	)


## Makhana and Pond Fish were newly sourced 2026-08-27 (real CC0 fits: a
## water lily and a fish model -- see village_fixture_data.gd's own doc
## comment on the constants block for the full sourcing account, including
## why Paddy/Dutch Rose/Sandalwood/Saffron below still aren't mapped). Both
## are single-stage models -- no distinct Growing vs. Ready geometry exists
## for either, so the same path returns regardless of is_ready.
func test_makhana_returns_the_lily_model_at_both_stages() -> void:
	assert_eq(
		VillageFixtureData.crop_stage_model_path(CropType.Kind.MAKHANA, false),
		VillageFixtureData.CROP_MAKHANA_MODEL
	)
	assert_eq(
		VillageFixtureData.crop_stage_model_path(CropType.Kind.MAKHANA, true),
		VillageFixtureData.CROP_MAKHANA_MODEL
	)


func test_pond_fish_returns_the_fish_model_at_both_stages() -> void:
	assert_eq(
		VillageFixtureData.crop_stage_model_path(CropType.Kind.POND_FISH, false),
		VillageFixtureData.CROP_POND_FISH_MODEL
	)
	assert_eq(
		VillageFixtureData.crop_stage_model_path(CropType.Kind.POND_FISH, true),
		VillageFixtureData.CROP_POND_FISH_MODEL
	)


## Paddy/Dutch Rose/Sandalwood/Saffron still deliberately have no sourced
## model that reasonably fits their real shape under this project's CC0-only
## constraint (see village_fixture_data.gd's own doc comment) -- every one
## of them must return "" so village_board.gd's _build_plot() falls back to
## the existing dirt-mesh+tint rendering instead of forcing a bad-fit model
## onto them.
func test_crops_with_no_reasonable_model_fit_return_empty_string() -> void:
	var unmapped_crops: Array[int] = [
		CropType.Kind.PADDY,
		CropType.Kind.DUTCH_ROSE,
		CropType.Kind.SANDALWOOD,
		CropType.Kind.SAFFRON,
	]
	for crop in unmapped_crops:
		assert_eq(VillageFixtureData.crop_stage_model_path(crop, false), "")
		assert_eq(VillageFixtureData.crop_stage_model_path(crop, true), "")


## PlotFixture.crop's "-1 = no crop planted" sentinel (EMPTY/GHOST/host-
## occupied cells) must not match any crop's mapping.
func test_no_crop_sentinel_returns_empty_string() -> void:
	assert_eq(VillageFixtureData.crop_stage_model_path(-1, false), "")
	assert_eq(VillageFixtureData.crop_stage_model_path(-1, true), "")


# --- farmhouse_model_path() (design/gdd/farmhouse-visual-tiers.md) --------------
# 5 tiers matching farmhouse_level_def()'s own emoji boundaries: 🛖 alone at
# 0, 🏠 spans 1-2, 🏡 spans 3-4, 🏰 spans 5-6, 🏛️ alone at 7.

func test_farmhouse_tier_1_is_level_0_only() -> void:
	assert_eq(VillageFixtureData.farmhouse_model_path(0), VillageFixtureData.FARMHOUSE_MODEL_TIER_1)


func test_farmhouse_tier_2_spans_levels_1_and_2() -> void:
	assert_eq(VillageFixtureData.farmhouse_model_path(1), VillageFixtureData.FARMHOUSE_MODEL_TIER_2)
	assert_eq(VillageFixtureData.farmhouse_model_path(2), VillageFixtureData.FARMHOUSE_MODEL_TIER_2)


func test_farmhouse_tier_3_spans_levels_3_and_4() -> void:
	assert_eq(VillageFixtureData.farmhouse_model_path(3), VillageFixtureData.FARMHOUSE_MODEL_TIER_3)
	assert_eq(VillageFixtureData.farmhouse_model_path(4), VillageFixtureData.FARMHOUSE_MODEL_TIER_3)


func test_farmhouse_tier_4_spans_levels_5_and_6() -> void:
	assert_eq(VillageFixtureData.farmhouse_model_path(5), VillageFixtureData.FARMHOUSE_MODEL_TIER_4)
	assert_eq(VillageFixtureData.farmhouse_model_path(6), VillageFixtureData.FARMHOUSE_MODEL_TIER_4)


func test_farmhouse_tier_5_is_level_7_only() -> void:
	assert_eq(VillageFixtureData.farmhouse_model_path(7), VillageFixtureData.FARMHOUSE_MODEL_TIER_5)


func test_farmhouse_tier_clamps_out_of_range_levels_to_the_last_tier() -> void:
	assert_eq(VillageFixtureData.farmhouse_model_path(99), VillageFixtureData.FARMHOUSE_MODEL_TIER_5)
	assert_eq(VillageFixtureData.farmhouse_model_path(-1), VillageFixtureData.FARMHOUSE_MODEL_TIER_1)


func test_farmhouse_tiers_are_five_distinct_models() -> void:
	var tiers: Array[String] = [
		VillageFixtureData.FARMHOUSE_MODEL_TIER_1, VillageFixtureData.FARMHOUSE_MODEL_TIER_2,
		VillageFixtureData.FARMHOUSE_MODEL_TIER_3, VillageFixtureData.FARMHOUSE_MODEL_TIER_4,
		VillageFixtureData.FARMHOUSE_MODEL_TIER_5,
	]
	var unique: Dictionary = {}
	for tier in tiers:
		unique[tier] = true
	assert_eq(unique.size(), 5)
