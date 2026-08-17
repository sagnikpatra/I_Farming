package com.zonkrik.ifarming.village

/** Sentinel ids for the tappable tiles that aren't real plots. Real plots use their GameState `Plot.id`. */
const val FARMHOUSE_TILE_ID = -1
const val LAND_GHOST_TILE_ID = -2
const val POLYHOUSE_BUILDING_ID = -3
const val AGROFORESTRY_BUILDING_ID = -4
const val AQUACULTURE_BUILDING_ID = -5
const val VERTICAL_FARM_BUILDING_ID = -6
const val MANDI_BUILDING_ID = -7

/**
 * Decoration tiles share the same `onTap(id: Int)` callback signature as everything else, so each
 * decoration's tile id is encoded as `DECORATION_ID_OFFSET - decoration.id` (a large, disjoint
 * negative range) rather than widening that callback's signature -- see `VillageSnapshotMapper`
 * (encode) and `GdxVillageBoard`'s tap routing (decode).
 */
const val DECORATION_ID_OFFSET = -1000

/**
 * Zone-id strings identifying the six draggable structure zones -- the single source of truth,
 * reused by `ui/gdx/VillageSnapshotMapper` (to look up a saved custom anchor) and
 * `game/GameRepository` (as the JSON keys for `GameState.zoneLayout`).
 */
const val ZONE_ID_FARMHOUSE = "FARMHOUSE"
const val ZONE_ID_POLYHOUSE = "POLYHOUSE"
const val ZONE_ID_AGROFORESTRY = "AGROFORESTRY"
const val ZONE_ID_AQUACULTURE = "AQUACULTURE"
const val ZONE_ID_VERTICAL_FARM = "VERTICAL_FARM"
const val ZONE_ID_MANDI = "MANDI"

/**
 * A growing crop's timing, so [Building] can animate its own countdown/progress bar locally every
 * frame (via wall-clock time) instead of the host app re-pushing a snapshot every second.
 */
data class GrowthInfo(val startAtMs: Long, val durationMs: Long)

/**
 * A plain, Android-agnostic description of one tile/building to render -- the host app translates
 * `GameState` into a `List<TileSnapshot>` each time it changes (see `ui/gdx/VillageSnapshotMapper`
 * in the `app` module); `core` never sees `GameState`/`Plot`/`CropType` directly.
 */
data class TileSnapshot(
    val id: Int,
    val tileX: Float,
    val tileY: Float,
    val groundKind: GroundKind,
    /** Key into the sprite texture map passed to `VillageGame.applySnapshot` -- see `EmojiTextureCache`. */
    val spriteKey: String,
    val growthInfo: GrowthInfo? = null,
    /** True only for the six structure-zone building tiles and decorations -- see the `ZONE_ID_*` constants. */
    val draggable: Boolean = false,
    val zoneId: String? = null,
    /** Set only for decoration tiles -- routes taps/drags through `onDecorationTapped`/`onDecorationMoved` instead of `onTap`/`onZoneMoved`. */
    val decorationId: Int? = null,
    val rotationDegrees: Int = 0,
    val flippedX: Boolean = false,
)
