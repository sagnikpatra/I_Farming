package com.zonkrik.ifarming.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items as lazyRowItems
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zonkrik.ifarming.game.CropType
import com.zonkrik.ifarming.game.DecorationType
import com.zonkrik.ifarming.game.GameData
import com.zonkrik.ifarming.game.GameEvent
import com.zonkrik.ifarming.game.GameState
import com.zonkrik.ifarming.game.GameViewModel
import com.zonkrik.ifarming.game.PlotKind
import com.zonkrik.ifarming.ui.gdx.GdxDecorationPicker
import com.zonkrik.ifarming.ui.gdx.GdxVillageBoard
import com.zonkrik.ifarming.ui.iso.IsoSheet
import com.zonkrik.ifarming.ui.theme.FieldGreen
import com.zonkrik.ifarming.ui.theme.RipeGold
import com.zonkrik.ifarming.ui.theme.SaffronDark
import com.zonkrik.ifarming.ui.theme.SoilBrown
import com.zonkrik.ifarming.ui.theme.SoilBrownDark
import com.zonkrik.ifarming.ui.theme.WoodBrownLight
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FarmScreen(viewModel: GameViewModel) {
    val state by viewModel.state.collectAsState()
    val nowMillis by viewModel.nowMillis.collectAsState()
    val event by viewModel.events.collectAsState()

    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var seedPickerPlotId by remember { mutableStateOf<Int?>(null) }
    var agroPickerPlotId by remember { mutableStateOf<Int?>(null) }
    var activeSheet by remember { mutableStateOf<IsoSheet?>(null) }
    var showDecorationPicker by remember { mutableStateOf(false) }
    var pendingDecorationType by remember { mutableStateOf<DecorationType?>(null) }

    LaunchedEffect(event) {
        val current = event
        if (current is GameEvent.Info) {
            snackbarHostState.showSnackbar(current.message)
            viewModel.consumeEvent()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            BannerSurface(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column {
                        OutlinedTitle("Kisan Khet", 20.sp)
                        OutlinedTitle("किसान खेत", 12.sp)
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        ResourceBadge(
                            text = "Decorate",
                            emoji = "🎨",
                            modifier = Modifier.padding(end = 8.dp).clickable { showDecorationPicker = true },
                        )
                        ResourceBadge(text = "${state.coins}", emoji = "🪙")
                    }
                }
            }
        },
    ) { innerPadding ->
        Box(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            // Phase 2 of the LibGDX migration: every zone renders from real GameState, with
            // pan/pinch-zoom camera controls and a quick-nav bar. Live countdown/progress-bar
            // rendering and the CoC-style info card are still deferred to a later pass.
            GdxVillageBoard(
                state = state,
                viewModel = viewModel,
                onEmptyTapped = {
                    seedPickerPlotId = it
                    activeSheet = null
                },
                onEmptyAgroTileTapped = {
                    agroPickerPlotId = it
                    activeSheet = null
                },
                onOpenSheet = {
                    activeSheet = it
                    seedPickerPlotId = null
                    agroPickerPlotId = null
                },
                pendingDecorationType = pendingDecorationType,
                onDecorationPlacementConsumed = { pendingDecorationType = null },
                modifier = Modifier.fillMaxSize(),
            )

            Column(modifier = Modifier.fillMaxWidth()) {
                LiveOpsBanner(nowMillis = nowMillis, viewModel = viewModel, onTapped = { activeSheet = IsoSheet.Events })
                InventoryBar(
                    inventory = state.inventory,
                    onSellCrop = { viewModel.sellCrop(it) },
                    onSellAll = { viewModel.sellAll() },
                )
            }
        }
    }

    val targetPlotId = seedPickerPlotId
    if (targetPlotId != null) {
        val targetKind = state.plots.find { it.id == targetPlotId }?.kind ?: PlotKind.OPEN_FIELD
        val sheetState = rememberModalBottomSheetState()
        ModalBottomSheet(
            onDismissRequest = { seedPickerPlotId = null },
            sheetState = sheetState,
        ) {
            SeedPicker(
                coins = state.coins,
                plotKind = targetKind,
                onCropChosen = { crop ->
                    viewModel.plantSeed(targetPlotId, crop)
                    scope.launch { sheetState.hide() }
                    seedPickerPlotId = null
                },
            )
        }
    }

    if (showDecorationPicker) {
        val decorationSheetState = rememberModalBottomSheetState()
        ModalBottomSheet(
            onDismissRequest = { showDecorationPicker = false },
            sheetState = decorationSheetState,
        ) {
            GdxDecorationPicker(
                coins = state.coins,
                onDecorationChosen = { type ->
                    pendingDecorationType = type
                    scope.launch { decorationSheetState.hide() }
                    showDecorationPicker = false
                },
            )
        }
    }

    val targetAgroPlotId = agroPickerPlotId
    if (targetAgroPlotId != null) {
        val agroSheetState = rememberModalBottomSheetState()
        ModalBottomSheet(
            onDismissRequest = { agroPickerPlotId = null },
            sheetState = agroSheetState,
        ) {
            AgroPlantPicker(
                coins = state.coins,
                canPlantSandalwood = viewModel.canPlantSandalwood(targetAgroPlotId),
                onHostChosen = { host ->
                    viewModel.plantHost(targetAgroPlotId, host)
                    scope.launch { agroSheetState.hide() }
                    agroPickerPlotId = null
                },
                onSandalwoodChosen = {
                    viewModel.plantSandalwood(targetAgroPlotId)
                    scope.launch { agroSheetState.hide() }
                    agroPickerPlotId = null
                },
            )
        }
    }

    val targetSheet = activeSheet
    if (targetSheet != null) {
        val managementSheetState = rememberModalBottomSheetState()
        ModalBottomSheet(
            onDismissRequest = { activeSheet = null },
            sheetState = managementSheetState,
        ) {
            when (targetSheet) {
                IsoSheet.Polyhouse -> PolyhouseTab(
                    state = state,
                    nowMillis = nowMillis,
                    viewModel = viewModel,
                    polyhousePlots = state.plots.filter { it.kind == PlotKind.POLYHOUSE },
                    onEmptyTapped = { seedPickerPlotId = it },
                    onHarvestTapped = { viewModel.harvestPlot(it) },
                    showPlots = false,
                )
                IsoSheet.Agroforestry -> AgroforestryTab(
                    state = state,
                    nowMillis = nowMillis,
                    viewModel = viewModel,
                    agroPlots = state.plots.filter { it.kind == PlotKind.AGROFORESTRY },
                    onEmptyTileTapped = { agroPickerPlotId = it },
                    showPlots = false,
                )
                IsoSheet.Niche -> NicheFarmingTab(
                    state = state,
                    nowMillis = nowMillis,
                    viewModel = viewModel,
                    aquaculturePlots = state.plots.filter { it.kind == PlotKind.AQUACULTURE },
                    verticalFarmPlots = state.plots.filter { it.kind == PlotKind.VERTICAL_FARM },
                    onEmptyTapped = { seedPickerPlotId = it },
                    onHarvestTapped = { viewModel.harvestPlot(it) },
                    showPlots = false,
                )
                IsoSheet.Farmhouse -> FarmhouseTab(state = state, viewModel = viewModel)
                IsoSheet.Mandi -> MandiTab(state = state, nowMillis = nowMillis, viewModel = viewModel)
                IsoSheet.Events -> EventsTab(state = state, nowMillis = nowMillis, viewModel = viewModel)
            }
        }
    }
}

/** Bold, drop-shadowed text -- readable over the grass/wood backgrounds without a solid card behind it. */
@Composable
fun OutlinedTitle(text: String, fontSize: androidx.compose.ui.unit.TextUnit, color: Color = Color.White) {
    Text(
        text,
        fontSize = fontSize,
        fontWeight = FontWeight.Bold,
        color = color,
        style = TextStyle(shadow = Shadow(Color.Black.copy(alpha = 0.55f), Offset(1f, 1.5f), 2f)),
    )
}

@Composable
private fun PlotGrid(
    plots: List<com.zonkrik.ifarming.game.Plot>,
    nowMillis: Long,
    onEmptyTapped: (Int) -> Unit,
    onHarvestTapped: (Int) -> Unit,
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(3),
        contentPadding = PaddingValues(12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier.fillMaxSize(),
    ) {
        items(plots, key = { it.id }) { plot ->
            PlotCard(
                plot = plot,
                nowMillis = nowMillis,
                onEmptyTapped = onEmptyTapped,
                onHarvestTapped = onHarvestTapped,
            )
        }
    }
}

/** Slim, tappable strip that surfaces a live Monsoon/Festival on top of the isometric board. */
@Composable
private fun LiveOpsBanner(nowMillis: Long, viewModel: GameViewModel, onTapped: () -> Unit) {
    val monsoonActive = viewModel.isMonsoonActive(nowMillis)
    val festivalActive = viewModel.isFestivalActive(nowMillis)
    if (!monsoonActive && !festivalActive) return

    val festival = viewModel.currentFestival(nowMillis)
    val label = when {
        monsoonActive && festivalActive -> "🌧️ Monsoon Season · ${festival.emoji} ${festival.displayName} active -- tap for details"
        monsoonActive -> "🌧️ Monsoon Season is active -- tap for details"
        else -> "${festival.emoji} ${festival.displayName} is active -- tap to earn Event Points"
    }

    ChunkyTile(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
        topColor = RipeGold,
        bottomColor = SaffronDark,
        cornerRadius = 12.dp,
        elevation = 3.dp,
        onClick = onTapped,
    ) {
        Box(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
            OutlinedTitle(label, 12.sp)
        }
    }
}

@Composable
private fun PolyhouseTab(
    state: GameState,
    nowMillis: Long,
    viewModel: GameViewModel,
    polyhousePlots: List<com.zonkrik.ifarming.game.Plot>,
    onEmptyTapped: (Int) -> Unit,
    onHarvestTapped: (Int) -> Unit,
    /** False when opened from the isometric map as a management panel -- the plots are already tappable on the board. */
    showPlots: Boolean = true,
) {
    if (!state.hasPolyhouse) {
        PolyhouseBuildCard(state = state, onBuild = { viewModel.buyPolyhouse() })
        return
    }

    Column(modifier = Modifier.fillMaxSize()) {
        PolyhouseUpgradesBar(state = state, nowMillis = nowMillis, viewModel = viewModel)
        if (showPlots) {
            PlotGrid(
                plots = polyhousePlots,
                nowMillis = nowMillis,
                onEmptyTapped = onEmptyTapped,
                onHarvestTapped = onHarvestTapped,
            )
        }
    }
}

@Composable
private fun PolyhouseBuildCard(state: GameState, onBuild: () -> Unit) {
    val subsidyUnlocked = GameData.isSubsidyUnlocked(state.totalHarvests)
    val cost = GameData.polyhouseCost(subsidyUnlocked)
    val progress = (state.totalHarvests.toFloat() / GameData.SUBSIDY_QUEST_TARGET.toFloat()).coerceIn(0f, 1f)

    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("🏠", fontSize = 48.sp)
        OutlinedTitle("Build a Naturally Ventilated Polyhouse", 18.sp)
        Text(
            "Unlocks ${GameData.POLYHOUSE_PLOT_COUNT} protected plots for Colored Capsicum and Dutch Rose -- " +
                "crops worth far more than anything grown in the open field.",
            fontSize = 13.sp,
            color = Color.White,
            modifier = Modifier.padding(top = 8.dp),
        )

        ChunkyTile(
            modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
            topColor = WoodBrownLight,
            bottomColor = SoilBrownDark,
            cornerRadius = 14.dp,
        ) {
            Column(modifier = Modifier.padding(14.dp)) {
                OutlinedTitle(
                    if (subsidyUnlocked) "🎉 Government subsidy unlocked -- 50% off!" else "Government Subsidy Quest",
                    14.sp,
                )
                Text(
                    "Harvest ${state.totalHarvests}/${GameData.SUBSIDY_QUEST_TARGET} crops to unlock a 50% subsidy",
                    fontSize = 12.sp,
                    color = Color.White,
                    modifier = Modifier.padding(top = 4.dp, bottom = 8.dp),
                )
                LinearProgressIndicator(
                    progress = { progress },
                    modifier = Modifier.fillMaxWidth(),
                    color = RipeGold,
                    trackColor = Color.Black.copy(alpha = 0.3f),
                )
            }
        }

        ChunkyButton(
            modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
            color = FieldGreen,
            onClick = onBuild,
        ) {
            Box(modifier = Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                OutlinedTitle("Build for ₹$cost", 16.sp)
            }
        }
    }
}

@Composable
private fun PolyhouseUpgradesBar(state: GameState, nowMillis: Long, viewModel: GameViewModel) {
    val filmActive = viewModel.isFilmActive(state, nowMillis)
    val filmRemainingMs = state.filmExpiresAtEpochMs?.let { it - nowMillis } ?: 0L

    LazyRow(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        lazyRowItems(listOf("fanpad", "drip", "film")) { key ->
            when (key) {
                "fanpad" -> UpgradeChip(
                    label = if (state.hasFanPad) "Fan & Pad ✓" else "Fan & Pad ₹${GameData.FAN_PAD_COST}",
                    active = state.hasFanPad,
                    onClick = { if (!state.hasFanPad) viewModel.buyFanPad() },
                )
                "drip" -> UpgradeChip(
                    label = if (state.hasDripIrrigation) "Drip Irrigation ✓" else "Drip Irrigation ₹${GameData.DRIP_IRRIGATION_COST}",
                    active = state.hasDripIrrigation,
                    onClick = { if (!state.hasDripIrrigation) viewModel.buyDripIrrigation() },
                )
                else -> UpgradeChip(
                    label = if (filmActive) {
                        "Film: ${formatDuration(filmRemainingMs)} left"
                    } else {
                        "Renew Film ₹${GameData.UV_FILM_COST}"
                    },
                    active = filmActive,
                    onClick = { viewModel.renewFilm() },
                )
            }
        }
    }
}

@Composable
fun UpgradeChip(label: String, active: Boolean, onClick: () -> Unit) {
    ChunkyTile(
        topColor = if (active) RipeGold else SoilBrown,
        bottomColor = if (active) SaffronDark else SoilBrownDark,
        cornerRadius = 50.dp,
        elevation = 3.dp,
        onClick = onClick,
    ) {
        Box(modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp)) {
            OutlinedTitle(label, 13.sp)
        }
    }
}

private fun formatDuration(ms: Long): String {
    val totalMinutes = (ms / 60000).coerceAtLeast(0)
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}

@Composable
private fun SeedPicker(coins: Long, plotKind: PlotKind, onCropChosen: (CropType) -> Unit) {
    val availableCrops = CropType.entries.filter { it.requiredPlotKind == plotKind }
    Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
        Text("Choose a seed to plant", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Column(modifier = Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            availableCrops.forEach { crop ->
                val affordable = coins >= crop.seedCost
                ChunkyTile(
                    modifier = Modifier.fillMaxWidth(),
                    topColor = if (affordable) WoodBrownLight else WoodBrownLight.copy(alpha = 0.4f),
                    bottomColor = if (affordable) SoilBrownDark else SoilBrownDark.copy(alpha = 0.4f),
                    cornerRadius = 12.dp,
                    elevation = if (affordable) 4.dp else 0.dp,
                    onClick = { if (affordable) onCropChosen(crop) },
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(crop.emoji, fontSize = 26.sp, modifier = Modifier.padding(end = 10.dp))
                            Column {
                                OutlinedTitle(crop.displayName, 14.sp)
                                Text(
                                    "${crop.growSeconds / 60}m grow · sells ₹${crop.baseSellPrice}",
                                    fontSize = 12.sp,
                                    color = Color.White.copy(alpha = 0.9f),
                                )
                            }
                        }
                        OutlinedTitle("₹${crop.seedCost}", 14.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun InventoryBar(
    inventory: Map<CropType, com.zonkrik.ifarming.game.CropStock>,
    onSellCrop: (CropType) -> Unit,
    onSellAll: () -> Unit,
) {
    if (inventory.isEmpty()) return

    Row(
        modifier = Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        LazyRow(
            modifier = Modifier.weight(1f),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            lazyRowItems(inventory.entries.toList(), key = { it.key.name }) { (crop, stock) ->
                ChunkyTile(
                    topColor = WoodBrownLight,
                    bottomColor = SoilBrownDark,
                    cornerRadius = 50.dp,
                    elevation = 3.dp,
                    onClick = { onSellCrop(crop) },
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(crop.emoji, fontSize = 18.sp)
                        OutlinedTitle(" x${stock.total}", 14.sp)
                    }
                }
            }
        }
        ChunkyButton(
            color = SaffronDark,
            cornerRadius = 50.dp,
            modifier = Modifier.padding(start = 8.dp),
            onClick = onSellAll,
        ) {
            Box(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
                OutlinedTitle("Sell All", 14.sp)
            }
        }
    }
}
