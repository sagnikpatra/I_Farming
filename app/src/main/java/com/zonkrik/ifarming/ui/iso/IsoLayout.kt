package com.zonkrik.ifarming.ui.iso

import androidx.compose.ui.unit.DpOffset

/**
 * Hand-picked world-coordinate anchors for every zone on the village board, plus the plot-index
 * (or, for Agroforestry, real agroRow/agroCol) -> world-offset mapping within each zone. Farmhouse
 * sits at the world origin; everything else is laid out around it with enough gap that no zone's
 * footprint visually overlaps another's (verified visually, tuned here if it ever does). Footprint
 * sizes below are static, matching GameData's MAX_PLOTS/POLYHOUSE_PLOT_COUNT/AGROFORESTRY_GRID_SIZE/
 * AQUACULTURE_PLOT_COUNT/VERTICAL_FARM_PLOT_COUNT constants.
 */
object IsoLayout {
    val FARMHOUSE = 0f to 0f

    val OPEN_FIELD_ANCHOR = 3f to -3f
    private const val OPEN_FIELD_COLUMNS = 4

    /** Index within the (filtered) open-field plot list -> world (col,row). */
    fun openFieldOffset(index: Int): Pair<Float, Float> {
        val (anchorCol, anchorRow) = OPEN_FIELD_ANCHOR
        return (anchorCol + index % OPEN_FIELD_COLUMNS) to (anchorRow + index / OPEN_FIELD_COLUMNS)
    }

    val POLYHOUSE_ANCHOR = -4f to -3f
    private const val POLYHOUSE_COLUMNS = 2

    fun polyhouseOffset(index: Int): Pair<Float, Float> {
        val (anchorCol, anchorRow) = POLYHOUSE_ANCHOR
        return (anchorCol + index % POLYHOUSE_COLUMNS) to (anchorRow + 1 + index / POLYHOUSE_COLUMNS)
    }

    val AGROFORESTRY_ANCHOR = -4f to 3f

    /** The one zone with real spatial data -- offset directly from the plot's own agroCol/agroRow. */
    fun agroforestryOffset(agroCol: Int, agroRow: Int): Pair<Float, Float> {
        val (anchorCol, anchorRow) = AGROFORESTRY_ANCHOR
        return (anchorCol + 1 + agroCol) to (anchorRow + 1 + agroRow)
    }

    val AQUACULTURE_ANCHOR = 4f to 3f
    private const val AQUACULTURE_COLUMNS = 3

    fun aquacultureOffset(index: Int): Pair<Float, Float> {
        val (anchorCol, anchorRow) = AQUACULTURE_ANCHOR
        return (anchorCol + index % AQUACULTURE_COLUMNS) to (anchorRow + 1 + index / AQUACULTURE_COLUMNS)
    }

    val VERTICAL_FARM_ANCHOR = 4f to -3f
    private const val VERTICAL_FARM_COLUMNS = 2

    fun verticalFarmOffset(index: Int): Pair<Float, Float> {
        val (anchorCol, anchorRow) = VERTICAL_FARM_ANCHOR
        return (anchorCol + index % VERTICAL_FARM_COLUMNS) to (anchorRow + 1 + index / VERTICAL_FARM_COLUMNS)
    }

    val MANDI_ANCHOR = 0f to 6f

    /**
     * Conservative world (col,row) bounding box covering every zone's maximum possible footprint
     * (statically known from [GameData]'s plot-count constants), used to clamp the camera so the
     * board can never be panned fully off-screen.
     */
    private val worldColRange = -6f..8f
    private val worldRowRange = -5f..8f

    /** Precomputed Dp bounds for [IsoCameraState.setWorldBounds] -- the min/max of the bounding box's four corners. */
    val worldBoundsMinDp: DpOffset
    val worldBoundsMaxDp: DpOffset

    init {
        val corners = listOf(
            worldToScreen(worldColRange.start, worldRowRange.start),
            worldToScreen(worldColRange.start, worldRowRange.endInclusive),
            worldToScreen(worldColRange.endInclusive, worldRowRange.start),
            worldToScreen(worldColRange.endInclusive, worldRowRange.endInclusive),
        )
        worldBoundsMinDp = DpOffset(corners.minOf { it.x }, corners.minOf { it.y })
        worldBoundsMaxDp = DpOffset(corners.maxOf { it.x }, corners.maxOf { it.y })
    }
}
