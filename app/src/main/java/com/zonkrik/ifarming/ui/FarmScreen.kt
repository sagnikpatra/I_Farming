package com.zonkrik.ifarming.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items as lazyRowItems
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
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
import com.zonkrik.ifarming.ui.theme.GoldLight
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

    // CoC style layout: The board fills the whole screen, HUD floats on top.
    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = Color.Transparent,
        contentWindowInsets = WindowInsets(0, 0, 0, 0)
    ) { innerPadding ->
        Box(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            // The main LibGDX board
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

            // HUD: Top-Left Title (account for status bar)
            val topPadding = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
            Column(modifier = Modifier.padding(start = 16.dp, top = topPadding + 8.dp).align(Alignment.TopStart)) {
                OutlinedTitle("Kisan Khet", 24.sp)
                OutlinedTitle("किसान खेत", 14.sp)
            }

            // HUD: Top-Right Resources
            Row(
                modifier = Modifier.padding(end = 16.dp, top = topPadding + 8.dp).align(Alignment.TopEnd),
                verticalAlignment = Alignment.CenterVertically
            ) {
                HUDResourceBar(text = "${state.coins}", emoji = "🪙")
                Spacer(modifier = Modifier.width(12.dp))
                HUDLevelBadge(level = state.farmhouseLevel)
            }

            // HUD: Bottom-Left Inventory / Events (float above navigation bar)
            Column(
                modifier = Modifier.padding(start = 16.dp, bottom = 100.dp).align(Alignment.BottomStart),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                LiveOpsBanner(nowMillis = nowMillis, viewModel = viewModel, onTapped = { activeSheet = IsoSheet.Events })
                InventoryHUD(
                    inventory = state.inventory,
                    onSellCrop = { viewModel.sellCrop(it) },
                    onSellAll = { viewModel.sellAll() }
                )
            }

            // HUD: Bottom-Right Shop Button
            Box(
                modifier = Modifier.padding(end = 16.dp, bottom = 100.dp).align(Alignment.BottomEnd)
            ) {
                RoundActionButton(emoji = "🎨", label = "Shop", onClick = { showDecorationPicker = true })
            }
        }
    }

    // Modal Sheets
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

@Composable
fun HUDResourceBar(text: String, emoji: String) {
    val shape = RoundedCornerShape(50)
    Box(
        modifier = Modifier
            .shadow(6.dp, shape)
            .border(2.dp, GoldLight, shape)
            .clip(shape)
            .background(Brush.verticalGradient(listOf(Color(0xFF5D4037), Color(0xFF3E2723))))
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(emoji, fontSize = 20.sp)
            Spacer(modifier = Modifier.width(8.dp))
            OutlinedTitle(text, 18.sp)
        }
    }
}

@Composable
fun HUDLevelBadge(level: Int) {
    Box(
        modifier = Modifier
            .size(48.dp)
            .shadow(6.dp, CircleShape)
            .border(2.dp, Color.White, CircleShape)
            .clip(CircleShape)
            .background(Brush.radialGradient(listOf(Color(0xFF42A5F5), Color(0xFF1976D2)))),
        contentAlignment = Alignment.Center
    ) {
        OutlinedTitle("$level", 18.sp)
    }
}

@Composable
fun RoundActionButton(emoji: String, label: String, onClick: () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .shadow(6.dp, CircleShape)
                .border(2.dp, GoldLight, CircleShape)
                .clip(CircleShape)
                .background(Brush.verticalGradient(listOf(WoodBrownLight, SoilBrownDark)))
                .clickable { onClick() },
            contentAlignment = Alignment.Center
        ) {
            Text(emoji, fontSize = 32.sp)
        }
        Spacer(modifier = Modifier.height(4.dp))
        OutlinedTitle(label, 12.sp)
    }
}

@Composable
fun OutlinedTitle(text: String, fontSize: androidx.compose.ui.unit.TextUnit, color: Color = Color.White) {
    Text(
        text,
        fontSize = fontSize,
        fontWeight = FontWeight.Bold,
        color = color,
        style = TextStyle(shadow = Shadow(Color.Black.copy(alpha = 0.7f), Offset(2f, 3f), 4f)),
    )
}

@Composable
private fun LiveOpsBanner(nowMillis: Long, viewModel: GameViewModel, onTapped: () -> Unit) {
    val monsoonActive = viewModel.isMonsoonActive(nowMillis)
    val festivalActive = viewModel.isFestivalActive(nowMillis)
    if (!monsoonActive && !festivalActive) return

    val festival = viewModel.currentFestival(nowMillis)
    val label = when {
        monsoonActive && festivalActive -> "🌧️ Monsoon · ${festival.emoji} ${festival.displayName}"
        monsoonActive -> "🌧️ Monsoon Season"
        else -> "${festival.emoji} ${festival.displayName}"
    }

    ChunkyTile(
        topColor = RipeGold,
        bottomColor = SaffronDark,
        cornerRadius = 12.dp,
        elevation = 3.dp,
        onClick = onTapped,
    ) {
        Box(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
            OutlinedTitle(label, 12.sp)
        }
    }
}

@Composable
private fun InventoryHUD(
    inventory: Map<CropType, com.zonkrik.ifarming.game.CropStock>,
    onSellCrop: (CropType) -> Unit,
    onSellAll: () -> Unit,
) {
    if (inventory.isEmpty()) return

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            lazyRowItems(inventory.entries.toList(), key = { it.key.name }) { (crop, stock) ->
                ChunkyTile(
                    topColor = WoodBrownLight,
                    bottomColor = SoilBrownDark,
                    cornerRadius = 10.dp,
                    elevation = 4.dp,
                    onClick = { onSellCrop(crop) },
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(crop.emoji, fontSize = 18.sp)
                        OutlinedTitle(" ${stock.total}", 14.sp)
                    }
                }
            }
        }
        ChunkyButton(
            color = SaffronDark,
            cornerRadius = 50.dp,
            onClick = onSellAll,
        ) {
            Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                OutlinedTitle("Sell All", 14.sp)
            }
        }
    }
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
private fun PolyhouseTab(
    state: GameState,
    nowMillis: Long,
    viewModel: GameViewModel,
    polyhousePlots: List<com.zonkrik.ifarming.game.Plot>,
    onEmptyTapped: (Int) -> Unit,
    onHarvestTapped: (Int) -> Unit,
    showPlots: Boolean = true,
) {
    if (!state.hasPolyhouse) {
        PolyhouseBuildCard(state = state, onBuild = { viewModel.buyPolyhouse() })
        return
    }
    Column(modifier = Modifier.fillMaxSize()) {
        PolyhouseUpgradesBar(state = state, nowMillis = nowMillis, viewModel = viewModel)
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
            "Unlocks ${GameData.POLYHOUSE_PLOT_COUNT} protected plots for Colored Capsicum and Dutch Rose.",
            fontSize = 13.sp, color = Color.White, modifier = Modifier.padding(top = 8.dp),
        )
        ChunkyTile(
            modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
            topColor = WoodBrownLight, bottomColor = SoilBrownDark, cornerRadius = 14.dp,
        ) {
            Column(modifier = Modifier.padding(14.dp)) {
                OutlinedTitle(if (subsidyUnlocked) "🎉 Subsidy unlocked!" else "Subsidy Quest", 14.sp)
                LinearProgressIndicator(
                    progress = { progress }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    color = RipeGold, trackColor = Color.Black.copy(alpha = 0.3f),
                )
            }
        }
        ChunkyButton(modifier = Modifier.fillMaxWidth().padding(top = 16.dp), color = FieldGreen, onClick = onBuild) {
            Box(modifier = Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                OutlinedTitle("Build for ₹$cost", 16.sp)
            }
        }
    }
}

@Composable
private fun PolyhouseUpgradesBar(state: GameState, nowMillis: Long, viewModel: GameViewModel) {
    val filmActive = viewModel.isFilmActive(state, nowMillis)
    LazyRow(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        lazyRowItems(listOf("fanpad", "drip", "film")) { key ->
            when (key) {
                "fanpad" -> UpgradeChip(label = if (state.hasFanPad) "Fan & Pad ✓" else "Fan & Pad", active = state.hasFanPad, onClick = { if (!state.hasFanPad) viewModel.buyFanPad() })
                "drip" -> UpgradeChip(label = if (state.hasDripIrrigation) "Drip ✓" else "Drip Irrigation", active = state.hasDripIrrigation, onClick = { if (!state.hasDripIrrigation) viewModel.buyDripIrrigation() })
                else -> UpgradeChip(label = if (filmActive) "Film Active ✓" else "Renew Film", active = filmActive, onClick = { viewModel.renewFilm() })
            }
        }
    }
}

@Composable
fun UpgradeChip(label: String, active: Boolean, onClick: () -> Unit) {
    ChunkyTile(
        topColor = if (active) RipeGold else SoilBrown,
        bottomColor = if (active) SaffronDark else SoilBrownDark,
        cornerRadius = 50.dp, elevation = 3.dp, onClick = onClick,
    ) {
        Box(modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp)) {
            OutlinedTitle(label, 13.sp)
        }
    }
}
