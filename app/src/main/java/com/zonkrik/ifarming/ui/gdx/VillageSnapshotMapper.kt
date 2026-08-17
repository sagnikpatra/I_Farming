package com.zonkrik.ifarming.ui.gdx

import com.zonkrik.ifarming.game.GameData
import com.zonkrik.ifarming.game.GameState
import com.zonkrik.ifarming.game.PlotKind
import com.zonkrik.ifarming.game.PlotState
import com.zonkrik.ifarming.village.AGROFORESTRY_BUILDING_ID
import com.zonkrik.ifarming.village.AQUACULTURE_BUILDING_ID
import com.zonkrik.ifarming.village.DECORATION_ID_OFFSET
import com.zonkrik.ifarming.village.FARMHOUSE_TILE_ID
import com.zonkrik.ifarming.village.GroundKind
import com.zonkrik.ifarming.village.GrowthInfo
import com.zonkrik.ifarming.village.LAND_GHOST_TILE_ID
import com.zonkrik.ifarming.village.MANDI_BUILDING_ID
import com.zonkrik.ifarming.village.POLYHOUSE_BUILDING_ID
import com.zonkrik.ifarming.village.TileSnapshot
import com.zonkrik.ifarming.village.VERTICAL_FARM_BUILDING_ID
import com.zonkrik.ifarming.village.ZONE_ID_AGROFORESTRY
import com.zonkrik.ifarming.village.ZONE_ID_AQUACULTURE
import com.zonkrik.ifarming.village.ZONE_ID_FARMHOUSE
import com.zonkrik.ifarming.village.ZONE_ID_MANDI
import com.zonkrik.ifarming.village.ZONE_ID_POLYHOUSE
import com.zonkrik.ifarming.village.ZONE_ID_VERTICAL_FARM

/**
 * Translates [GameState] into the plain [TileSnapshot] list `core` renders. Zone anchors default
 * to fixed world (col,row) constants, spaced apart deliberately so no two zones' footprints
 * overlap by default -- but each of the six structure zones can be dragged to a custom spot (see
 * the village board's drag-to-reposition feature), saved in `state.zoneLayout` and resolved here
 * in place of the default. Every attached plot's position is computed *relative to* the resolved
 * anchor, so a moved zone's plots automatically move with it.
 */
object VillageSnapshotMapper {
    private val FARMHOUSE_DEFAULT = 0f to 0f
    // 4 columns wide, up to GameData.MAX_PLOTS/4 rows tall -- occupies world tiles
    // X:[6,9], Y:[-6,-3] at full expansion. VERTICAL_FARM_DEFAULT used to sit at (8,-6), squarely
    // inside that rectangle (the open field's 3rd starting plot and the Vertical Farm building
    // landed on the exact same world tile, confirmed via ray-pick hit-testing a single tap hitting
    // both) -- moved well clear of it below.
    private val OPEN_FIELD_ANCHOR = 6f to -6f
    private val POLYHOUSE_DEFAULT = -8f to -6f
    private val AGROFORESTRY_DEFAULT = -8f to 6f
    private val AQUACULTURE_DEFAULT = 8f to 6f
    private val VERTICAL_FARM_DEFAULT = 8f to -12f
    private val MANDI_DEFAULT = 0f to 12f

    /** A resolved structure-zone position + orientation -- either the saved custom anchor or the zone's fixed default. */
    private data class ResolvedAnchor(
        val tileX: Float,
        val tileY: Float,
        val rotationDegrees: Int = 0,
        val flippedX: Boolean = false,
    )

    private fun anchorOf(state: GameState, zoneId: String, default: Pair<Float, Float>): ResolvedAnchor {
        val saved = state.zoneLayout[zoneId] ?: return ResolvedAnchor(default.first, default.second)
        return ResolvedAnchor(saved.tileX, saved.tileY, saved.rotationDegrees, saved.flippedX)
    }

    fun build(state: GameState): List<TileSnapshot> {
        val tiles = mutableListOf<TileSnapshot>()

        val farmhouseLevel = GameData.farmhouseLevelDef(state.farmhouseLevel)
        val farmhouseAnchor = anchorOf(state, ZONE_ID_FARMHOUSE, FARMHOUSE_DEFAULT)
        tiles += TileSnapshot(
            FARMHOUSE_TILE_ID, farmhouseAnchor.tileX, farmhouseAnchor.tileY, GroundKind.FARMHOUSE, farmhouseLevel.emoji,
            draggable = true, zoneId = ZONE_ID_FARMHOUSE,
            rotationDegrees = farmhouseAnchor.rotationDegrees, flippedX = farmhouseAnchor.flippedX,
        )

        addOpenField(tiles, state)
        addPolyhouse(tiles, state)
        addAgroforestry(tiles, state)
        addAquaculture(tiles, state)
        addVerticalFarm(tiles, state)
        addMandi(tiles, state)
        addDecorations(tiles, state)

        return tiles
    }

    private fun addDecorations(tiles: MutableList<TileSnapshot>, state: GameState) {
        state.decorations.forEach { decoration ->
            tiles += TileSnapshot(
                id = DECORATION_ID_OFFSET - decoration.id,
                tileX = decoration.tileX,
                tileY = decoration.tileY,
                groundKind = GroundKind.UNLOCKED,
                spriteKey = decoration.type.emoji,
                draggable = true,
                decorationId = decoration.id,
                rotationDegrees = decoration.rotationDegrees,
                flippedX = decoration.flippedX,
            )
        }
    }

    private fun addOpenField(tiles: MutableList<TileSnapshot>, state: GameState) {
        val (anchorX, anchorY) = OPEN_FIELD_ANCHOR
        val columns = 4
        val openFieldPlots = state.plots.filter { it.kind == PlotKind.OPEN_FIELD }
        openFieldPlots.forEachIndexed { index, plot ->
            val col = anchorX + index % columns
            val row = anchorY + index / columns
            tiles += plotSnapshot(plot.id, col, row, plot.state)
        }
        if (openFieldPlots.size < GameData.MAX_PLOTS) {
            val col = anchorX + openFieldPlots.size % columns
            val row = anchorY + openFieldPlots.size / columns
            tiles += TileSnapshot(LAND_GHOST_TILE_ID, col, row, GroundKind.GHOST, "🌍")
        }
    }

    private fun addPolyhouse(tiles: MutableList<TileSnapshot>, state: GameState) {
        val anchor = anchorOf(state, ZONE_ID_POLYHOUSE, POLYHOUSE_DEFAULT)
        val (anchorX, anchorY) = anchor.tileX to anchor.tileY
        tiles += TileSnapshot(
            POLYHOUSE_BUILDING_ID, anchorX, anchorY,
            if (state.hasPolyhouse) GroundKind.UNLOCKED else GroundKind.SOIL, "🏠",
            draggable = true, zoneId = ZONE_ID_POLYHOUSE,
            rotationDegrees = anchor.rotationDegrees, flippedX = anchor.flippedX,
        )
        if (!state.hasPolyhouse) return
        val polyhousePlots = state.plots.filter { it.kind == PlotKind.POLYHOUSE }
        val columns = 2
        polyhousePlots.forEachIndexed { index, plot ->
            val col = anchorX + index % columns
            val row = anchorY + 1 + index / columns
            tiles += plotSnapshot(plot.id, col, row, plot.state)
        }
    }

    private fun addAgroforestry(tiles: MutableList<TileSnapshot>, state: GameState) {
        val anchor = anchorOf(state, ZONE_ID_AGROFORESTRY, AGROFORESTRY_DEFAULT)
        val (anchorX, anchorY) = anchor.tileX to anchor.tileY
        tiles += TileSnapshot(
            AGROFORESTRY_BUILDING_ID, anchorX, anchorY,
            if (state.hasAgroforestry) GroundKind.UNLOCKED else GroundKind.SOIL,
            if (state.hasSecurity) "🛡️" else "🌳",
            draggable = true, zoneId = ZONE_ID_AGROFORESTRY,
            rotationDegrees = anchor.rotationDegrees, flippedX = anchor.flippedX,
        )
        if (!state.hasAgroforestry) return
        val agroPlots = state.plots.filter { it.kind == PlotKind.AGROFORESTRY }
        agroPlots.forEach { plot ->
            val col = anchorX + 1 + (plot.agroCol ?: 0)
            val row = anchorY + 1 + (plot.agroRow ?: 0)
            val host = plot.hostType
            tiles += if (host != null) {
                TileSnapshot(plot.id, col, row, GroundKind.UNLOCKED, host.emoji)
            } else {
                plotSnapshot(plot.id, col, row, plot.state)
            }
        }
    }

    private fun addAquaculture(tiles: MutableList<TileSnapshot>, state: GameState) {
        val anchor = anchorOf(state, ZONE_ID_AQUACULTURE, AQUACULTURE_DEFAULT)
        val (anchorX, anchorY) = anchor.tileX to anchor.tileY
        tiles += TileSnapshot(
            AQUACULTURE_BUILDING_ID, anchorX, anchorY,
            if (state.hasAquaculture) GroundKind.UNLOCKED else GroundKind.SOIL, "🪷",
            draggable = true, zoneId = ZONE_ID_AQUACULTURE,
            rotationDegrees = anchor.rotationDegrees, flippedX = anchor.flippedX,
        )
        if (!state.hasAquaculture) return
        val aquaculturePlots = state.plots.filter { it.kind == PlotKind.AQUACULTURE }
        val columns = 3
        aquaculturePlots.forEachIndexed { index, plot ->
            val col = anchorX + index % columns
            val row = anchorY + 1 + index / columns
            tiles += plotSnapshot(plot.id, col, row, plot.state, isWater = true)
        }
    }

    private fun addVerticalFarm(tiles: MutableList<TileSnapshot>, state: GameState) {
        val anchor = anchorOf(state, ZONE_ID_VERTICAL_FARM, VERTICAL_FARM_DEFAULT)
        val (anchorX, anchorY) = anchor.tileX to anchor.tileY
        tiles += TileSnapshot(
            VERTICAL_FARM_BUILDING_ID, anchorX, anchorY,
            if (state.hasVerticalFarm) GroundKind.UNLOCKED else GroundKind.SOIL, "🌸",
            draggable = true, zoneId = ZONE_ID_VERTICAL_FARM,
            rotationDegrees = anchor.rotationDegrees, flippedX = anchor.flippedX,
        )
        if (!state.hasVerticalFarm) return
        val verticalFarmPlots = state.plots.filter { it.kind == PlotKind.VERTICAL_FARM }
        val columns = 2
        verticalFarmPlots.forEachIndexed { index, plot ->
            val col = anchorX + index % columns
            val row = anchorY + 1 + index / columns
            tiles += plotSnapshot(plot.id, col, row, plot.state)
        }
    }

    private fun addMandi(tiles: MutableList<TileSnapshot>, state: GameState) {
        val anchor = anchorOf(state, ZONE_ID_MANDI, MANDI_DEFAULT)
        val (anchorX, anchorY) = anchor.tileX to anchor.tileY
        tiles += TileSnapshot(
            MANDI_BUILDING_ID, anchorX, anchorY,
            if (state.hasMandi) GroundKind.UNLOCKED else GroundKind.SOIL, "🏛️",
            draggable = true, zoneId = ZONE_ID_MANDI,
            rotationDegrees = anchor.rotationDegrees, flippedX = anchor.flippedX,
        )
    }

    /** Shared Empty/Growing/ReadyToHarvest -> TileSnapshot mapping used by every plain crop-plot zone. */
    private fun plotSnapshot(id: Int, col: Float, row: Float, state: PlotState, isWater: Boolean = false): TileSnapshot {
        val (groundKind, spriteKey) = when (state) {
            is PlotState.Empty -> (if (isWater) GroundKind.WATER else GroundKind.SOIL) to "+"
            is PlotState.Growing -> (if (isWater) GroundKind.WATER else GroundKind.GROWING) to state.crop.emoji
            is PlotState.ReadyToHarvest -> GroundKind.READY to state.crop.emoji
        }
        val growthInfo = (state as? PlotState.Growing)?.let {
            GrowthInfo(startAtMs = it.plantedAtEpochMs, durationMs = it.effectiveGrowSeconds * 1000L)
        }
        return TileSnapshot(id, col, row, groundKind, spriteKey, growthInfo)
    }
}
