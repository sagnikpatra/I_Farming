package com.zonkrik.ifarming.ui.iso

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import com.zonkrik.ifarming.game.GameData
import com.zonkrik.ifarming.game.GameState
import com.zonkrik.ifarming.game.GameViewModel
import com.zonkrik.ifarming.game.Plot
import com.zonkrik.ifarming.game.PlotKind
import com.zonkrik.ifarming.game.PlotState
import com.zonkrik.ifarming.ui.gameGroundBackground
import com.zonkrik.ifarming.ui.theme.FieldGreen
import com.zonkrik.ifarming.ui.theme.FieldGreenLight
import com.zonkrik.ifarming.ui.theme.SoilBrown
import com.zonkrik.ifarming.ui.theme.SoilBrownDark
import com.zonkrik.ifarming.ui.theme.WoodBrownLight
import kotlinx.coroutines.launch

/**
 * The full pannable/zoomable "village view": every structure and plot laid out per [IsoLayout],
 * on top of one camera-transformed content Box (see [IsoCameraState]). Tap targets are ordinary
 * Compose `clickable`s inside that transformed layer, so hit-testing automatically accounts for
 * the current pan/zoom -- no manual screen-to-world math needed here.
 */
@Composable
fun IsoBoard(
    state: GameState,
    nowMillis: Long,
    viewModel: GameViewModel,
    camera: IsoCameraState,
    onEmptyTapped: (Int) -> Unit,
    onHarvestTapped: (Int) -> Unit,
    onEmptyAgroTileTapped: (Int) -> Unit,
    onOpenSheet: (IsoSheet) -> Unit,
    onBuyLand: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    var hasCentered by remember { mutableStateOf(false) }

    // Tracks in-flight harvest sparkle bursts (plotId -> world position), independent of plot
    // state so the burst can finish playing even though the plot itself flips to Empty/Growing
    // the instant harvestPlot() runs. Self-cleaning: each HarvestBurst removes its own entry.
    val harvestBursts = remember { mutableStateMapOf<Int, Pair<Float, Float>>() }
    fun harvestWithBurst(plotId: Int, col: Float, row: Float) {
        harvestBursts[plotId] = col to row
        onHarvestTapped(plotId)
    }

    // The currently selected building/crop, shown via the floating CoC-style [IsoInfoCard]
    // instead of jumping straight into the full management sheet on every tap.
    var selection by remember { mutableStateOf<IsoSelection?>(null) }
    fun selectBuilding(
        col: Float,
        row: Float,
        emoji: String,
        title: String,
        subtitle: String,
        actionLabel: String,
        sheet: IsoSheet,
    ) {
        selection = IsoSelection(col, row, emoji, title, subtitle, actionLabel) {
            selection = null
            onOpenSheet(sheet)
        }
    }
    fun selectGrowingCrop(plot: Plot, col: Float, row: Float) {
        val growing = plot.state as? PlotState.Growing ?: return
        val totalMs = growing.effectiveGrowSeconds * 1000L
        val elapsedMs = (nowMillis - growing.plantedAtEpochMs).coerceIn(0, totalMs)
        val remainingSeconds = ((totalMs - elapsedMs) / 1000L).coerceAtLeast(0)
        selection = IsoSelection(
            col = col,
            row = row,
            emoji = growing.crop.emoji,
            title = growing.crop.displayName,
            subtitle = "${formatRemainingCompact(remainingSeconds)} left · sells ₹${growing.crop.baseSellPrice}",
        )
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .gameGroundBackground()
            .clipToBounds()
            .onSizeChanged { size ->
                camera.viewportSize = size
                camera.setWorldBounds(IsoLayout.worldBoundsMinDp, IsoLayout.worldBoundsMaxDp, density)
                if (!hasCentered) {
                    hasCentered = true
                    scope.launch { camera.centerOn(IsoLayout.FARMHOUSE.first, IsoLayout.FARMHOUSE.second, density) }
                }
            }
            .isoCameraGestures(camera, scope),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    scaleX = camera.scale.value
                    scaleY = camera.scale.value
                    translationX = camera.offset.value.x
                    translationY = camera.offset.value.y
                    transformOrigin = TransformOrigin(0f, 0f)
                },
        ) {
            // --- Farmhouse: always present, tap shows its info card. ---
            val farmhouseLevel = GameData.farmhouseLevelDef(state.farmhouseLevel)
            IsoBuilding(
                col = IsoLayout.FARMHOUSE.first,
                row = IsoLayout.FARMHOUSE.second,
                emoji = farmhouseLevel.emoji,
                groundTopColor = WoodBrownLight,
                groundBottomColor = SoilBrownDark,
                onClick = {
                    selectBuilding(
                        col = IsoLayout.FARMHOUSE.first,
                        row = IsoLayout.FARMHOUSE.second,
                        emoji = farmhouseLevel.emoji,
                        title = farmhouseLevel.displayName,
                        subtitle = "Farmhouse · Level ${state.farmhouseLevel} of ${GameData.FARMHOUSE_MAX_LEVEL}",
                        actionLabel = "Manage",
                        sheet = IsoSheet.Farmhouse,
                    )
                },
            )

            // --- Open Field: always present, expands up to GameData.MAX_PLOTS. ---
            val openFieldPlots = state.plots.filter { it.kind == PlotKind.OPEN_FIELD }
            openFieldPlots.forEachIndexed { index, plot ->
                val (col, row) = IsoLayout.openFieldOffset(index)
                IsoPlotTile(
                    plot = plot,
                    col = col,
                    row = row,
                    nowMillis = nowMillis,
                    onEmptyTapped = onEmptyTapped,
                    onHarvestTapped = { harvestWithBurst(it, col, row) },
                    onGrowingTapped = { selectGrowingCrop(plot, col, row) },
                )
            }
            if (openFieldPlots.size < GameData.MAX_PLOTS) {
                val (col, row) = IsoLayout.openFieldOffset(openFieldPlots.size)
                IsoLandGhostTile(
                    col = col,
                    row = row,
                    cost = GameData.landExpansionCost(openFieldPlots.size),
                    onClick = onBuyLand,
                )
            }

            // --- Polyhouse ---
            val (polyCol, polyRow) = IsoLayout.POLYHOUSE_ANCHOR
            if (!state.hasPolyhouse) {
                val cost = GameData.polyhouseCost(GameData.isSubsidyUnlocked(state.totalHarvests))
                IsoBuilding(
                    col = polyCol,
                    row = polyRow,
                    emoji = "🏠",
                    groundTopColor = SoilBrown,
                    groundBottomColor = SoilBrownDark,
                    locked = true,
                    badgeText = "₹$cost",
                    onClick = {
                        selectBuilding(
                            col = polyCol,
                            row = polyRow,
                            emoji = "🏠",
                            title = "Polyhouse",
                            subtitle = "Protected cultivation -- Colored Capsicum & Dutch Rose",
                            actionLabel = "Build ₹$cost",
                            sheet = IsoSheet.Polyhouse,
                        )
                    },
                )
            } else {
                IsoBuilding(
                    col = polyCol,
                    row = polyRow,
                    emoji = "🏠",
                    groundTopColor = FieldGreenLight,
                    groundBottomColor = FieldGreen,
                    onClick = {
                        selectBuilding(
                            col = polyCol,
                            row = polyRow,
                            emoji = "🏠",
                            title = "Polyhouse",
                            subtitle = "${GameData.POLYHOUSE_PLOT_COUNT} protected plots",
                            actionLabel = "Manage",
                            sheet = IsoSheet.Polyhouse,
                        )
                    },
                )
                val polyhousePlots = state.plots.filter { it.kind == PlotKind.POLYHOUSE }
                polyhousePlots.forEachIndexed { index, plot ->
                    val (col, row) = IsoLayout.polyhouseOffset(index)
                    IsoPlotTile(
                        plot = plot,
                        col = col,
                        row = row,
                        nowMillis = nowMillis,
                        onEmptyTapped = onEmptyTapped,
                        onHarvestTapped = { harvestWithBurst(it, col, row) },
                        onGrowingTapped = { selectGrowingCrop(plot, col, row) },
                    )
                }
            }

            // --- Agroforestry ---
            val (agroAnchorCol, agroAnchorRow) = IsoLayout.AGROFORESTRY_ANCHOR
            if (!state.hasAgroforestry) {
                IsoBuilding(
                    col = agroAnchorCol,
                    row = agroAnchorRow,
                    emoji = "🌳",
                    groundTopColor = SoilBrown,
                    groundBottomColor = SoilBrownDark,
                    locked = true,
                    badgeText = "₹${GameData.AGROFORESTRY_UNLOCK_COST}",
                    onClick = {
                        selectBuilding(
                            col = agroAnchorCol,
                            row = agroAnchorRow,
                            emoji = "🌳",
                            title = "Agroforestry",
                            subtitle = "Grow Sandalwood (Srigandham) -- a multi-week, high-value crop",
                            actionLabel = "Clear ₹${GameData.AGROFORESTRY_UNLOCK_COST}",
                            sheet = IsoSheet.Agroforestry,
                        )
                    },
                )
            } else {
                IsoBuilding(
                    col = agroAnchorCol,
                    row = agroAnchorRow,
                    emoji = if (state.hasSecurity) "🛡️" else "🌳",
                    groundTopColor = FieldGreenLight,
                    groundBottomColor = FieldGreen,
                    onClick = {
                        selectBuilding(
                            col = agroAnchorCol,
                            row = agroAnchorRow,
                            emoji = if (state.hasSecurity) "🛡️" else "🌳",
                            title = "Agroforestry",
                            subtitle = "${GameData.AGROFORESTRY_GRID_SIZE}x${GameData.AGROFORESTRY_GRID_SIZE} Sandalwood grid" +
                                if (state.hasSecurity) " · secured" else "",
                            actionLabel = "Manage",
                            sheet = IsoSheet.Agroforestry,
                        )
                    },
                )
                val agroPlots = state.plots.filter { it.kind == PlotKind.AGROFORESTRY }
                agroPlots.forEach { plot ->
                    val (col, row) = IsoLayout.agroforestryOffset(plot.agroCol ?: 0, plot.agroRow ?: 0)
                    IsoAgroTile(
                        plot = plot,
                        col = col,
                        row = row,
                        nowMillis = nowMillis,
                        onEmptyTapped = onEmptyAgroTileTapped,
                        onHostTapped = { viewModel.removeHost(it) },
                        onHarvestTapped = { harvestWithBurst(it, col, row) },
                        onGrowingTapped = { selectGrowingCrop(plot, col, row) },
                    )
                }
            }

            // --- Aquaculture ---
            val (aquaAnchorCol, aquaAnchorRow) = IsoLayout.AQUACULTURE_ANCHOR
            if (!state.hasAquaculture) {
                IsoBuilding(
                    col = aquaAnchorCol,
                    row = aquaAnchorRow,
                    emoji = "🪷",
                    groundTopColor = SoilBrown,
                    groundBottomColor = SoilBrownDark,
                    locked = true,
                    badgeText = "₹${GameData.AQUACULTURE_UNLOCK_COST}",
                    onClick = {
                        selectBuilding(
                            col = aquaAnchorCol,
                            row = aquaAnchorRow,
                            emoji = "🪷",
                            title = "Makhana Ponds",
                            subtitle = "Aquaculture -- Fox Nut & Pond Fish",
                            actionLabel = "Excavate ₹${GameData.AQUACULTURE_UNLOCK_COST}",
                            sheet = IsoSheet.Niche,
                        )
                    },
                )
            } else {
                IsoBuilding(
                    col = aquaAnchorCol,
                    row = aquaAnchorRow,
                    emoji = "🪷",
                    groundTopColor = FieldGreenLight,
                    groundBottomColor = FieldGreen,
                    onClick = {
                        selectBuilding(
                            col = aquaAnchorCol,
                            row = aquaAnchorRow,
                            emoji = "🪷",
                            title = "Makhana Ponds",
                            subtitle = "${GameData.AQUACULTURE_PLOT_COUNT} pond plots",
                            actionLabel = "Manage",
                            sheet = IsoSheet.Niche,
                        )
                    },
                )
                val aquaculturePlots = state.plots.filter { it.kind == PlotKind.AQUACULTURE }
                aquaculturePlots.forEachIndexed { index, plot ->
                    val (col, row) = IsoLayout.aquacultureOffset(index)
                    IsoPlotTile(
                        plot = plot,
                        col = col,
                        row = row,
                        nowMillis = nowMillis,
                        onEmptyTapped = onEmptyTapped,
                        onHarvestTapped = { harvestWithBurst(it, col, row) },
                        isWater = true,
                        onGrowingTapped = { selectGrowingCrop(plot, col, row) },
                    )
                }
            }

            // --- Vertical Farm ---
            val (vfAnchorCol, vfAnchorRow) = IsoLayout.VERTICAL_FARM_ANCHOR
            if (!state.hasVerticalFarm) {
                IsoBuilding(
                    col = vfAnchorCol,
                    row = vfAnchorRow,
                    emoji = "🌸",
                    groundTopColor = SoilBrown,
                    groundBottomColor = SoilBrownDark,
                    locked = true,
                    badgeText = "₹${GameData.VERTICAL_FARM_UNLOCK_COST}",
                    onClick = {
                        selectBuilding(
                            col = vfAnchorCol,
                            row = vfAnchorRow,
                            emoji = "🌸",
                            title = "Saffron Vertical Farm",
                            subtitle = "Ultra-high-value, low-footprint -- needs electricity",
                            actionLabel = "Build ₹${GameData.VERTICAL_FARM_UNLOCK_COST}",
                            sheet = IsoSheet.Niche,
                        )
                    },
                )
            } else {
                IsoBuilding(
                    col = vfAnchorCol,
                    row = vfAnchorRow,
                    emoji = "🌸",
                    groundTopColor = FieldGreenLight,
                    groundBottomColor = FieldGreen,
                    onClick = {
                        selectBuilding(
                            col = vfAnchorCol,
                            row = vfAnchorRow,
                            emoji = "🌸",
                            title = "Saffron Vertical Farm",
                            subtitle = "${GameData.VERTICAL_FARM_PLOT_COUNT} compact plots",
                            actionLabel = "Manage",
                            sheet = IsoSheet.Niche,
                        )
                    },
                )
                val verticalFarmPlots = state.plots.filter { it.kind == PlotKind.VERTICAL_FARM }
                verticalFarmPlots.forEachIndexed { index, plot ->
                    val (col, row) = IsoLayout.verticalFarmOffset(index)
                    IsoPlotTile(
                        plot = plot,
                        col = col,
                        row = row,
                        nowMillis = nowMillis,
                        onEmptyTapped = onEmptyTapped,
                        onHarvestTapped = { harvestWithBurst(it, col, row) },
                        onGrowingTapped = { selectGrowingCrop(plot, col, row) },
                    )
                }
            }

            // --- Mandi: no plots either way; MandiTab already branches on state.hasMandi itself. ---
            val (mandiCol, mandiRow) = IsoLayout.MANDI_ANCHOR
            IsoBuilding(
                col = mandiCol,
                row = mandiRow,
                emoji = "🏛️",
                groundTopColor = if (state.hasMandi) FieldGreenLight else SoilBrown,
                groundBottomColor = if (state.hasMandi) FieldGreen else SoilBrownDark,
                locked = !state.hasMandi,
                badgeText = if (!state.hasMandi) "₹${GameData.MANDI_UNLOCK_COST}" else null,
                onClick = {
                    selectBuilding(
                        col = mandiCol,
                        row = mandiRow,
                        emoji = "🏛️",
                        title = "Mandi",
                        subtitle = if (state.hasMandi) "e-NAM trading post" else "e-NAM trading post -- not yet built",
                        actionLabel = if (state.hasMandi) "Manage" else "Build ₹${GameData.MANDI_UNLOCK_COST}",
                        sheet = IsoSheet.Mandi,
                    )
                },
            )

            // --- Ambient harvest sparkle bursts, drawn above everything else. ---
            harvestBursts.entries.toList().forEach { (plotId, position) ->
                HarvestBurst(col = position.first, row = position.second) { harvestBursts.remove(plotId) }
            }
        }

        // The CoC-style info card lives outside the camera-transformed content so it stays a
        // constant, readable size while tracking the selected tile's live screen position.
        selection?.let { IsoInfoCard(selection = it, camera = camera) { selection = null } }
    }
}

private fun formatRemainingCompact(totalSeconds: Long): String {
    val days = totalSeconds / 86400
    val hours = (totalSeconds % 86400) / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return when {
        days > 0 -> "${days}d ${hours}h"
        hours > 0 -> "%dh %02dm".format(hours, minutes)
        else -> "%d:%02d".format(minutes, seconds)
    }
}
