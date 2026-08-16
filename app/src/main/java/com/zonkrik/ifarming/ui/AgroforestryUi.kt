package com.zonkrik.ifarming.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items as lazyRowItems
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zonkrik.ifarming.game.CropType
import com.zonkrik.ifarming.game.GameData
import com.zonkrik.ifarming.game.GameState
import com.zonkrik.ifarming.game.GameViewModel
import com.zonkrik.ifarming.game.HostType
import com.zonkrik.ifarming.game.Plot
import com.zonkrik.ifarming.game.PlotState
import com.zonkrik.ifarming.ui.theme.FieldGreenLight
import com.zonkrik.ifarming.ui.theme.RipeGold
import com.zonkrik.ifarming.ui.theme.SoilBrown
import kotlin.math.ceil

@Composable
fun AgroforestryTab(
    state: GameState,
    nowMillis: Long,
    viewModel: GameViewModel,
    agroPlots: List<Plot>,
    onEmptyTileTapped: (Int) -> Unit,
) {
    if (!state.hasAgroforestry) {
        AgroBuildCard(coins = state.coins, onBuild = { viewModel.buyAgroforestry() })
        return
    }

    Column(modifier = Modifier.fillMaxSize()) {
        LazyRow(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            lazyRowItems(listOf(0)) {
                Card(
                    onClick = { if (!state.hasSecurity) viewModel.buySecurity() },
                    colors = CardDefaults.cardColors(
                        containerColor = if (state.hasSecurity) {
                            RipeGold.copy(alpha = 0.3f)
                        } else {
                            MaterialTheme.colorScheme.surfaceVariant
                        },
                    ),
                ) {
                    Text(
                        if (state.hasSecurity) "Security (Fencing + CCTV) ✓" else "Security ₹${GameData.SECURITY_COST}",
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }
        Text(
            "Plant a host next to an empty tile, then Sandalwood beside the host.",
            fontSize = 12.sp,
            modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 4.dp),
        )

        LazyVerticalGrid(
            columns = GridCells.Fixed(GameData.AGROFORESTRY_GRID_SIZE),
            contentPadding = PaddingValues(12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            items(agroPlots, key = { it.id }) { plot ->
                AgroPlotCard(
                    plot = plot,
                    nowMillis = nowMillis,
                    onEmptyTapped = { onEmptyTileTapped(plot.id) },
                    onHostTapped = { viewModel.removeHost(plot.id) },
                    onHarvestTapped = { viewModel.harvestPlot(plot.id) },
                )
            }
        }
    }
}

@Composable
private fun AgroBuildCard(coins: Long, onBuild: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("🌳", fontSize = 48.sp)
        Text(
            "Clear Land for Agroforestry",
            fontWeight = FontWeight.Bold,
            fontSize = 18.sp,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            "Unlocks a ${GameData.AGROFORESTRY_GRID_SIZE}x${GameData.AGROFORESTRY_GRID_SIZE} plot grid for Sandalwood " +
                "(Srigandham) cultivation. Sandalwood is semi-parasitic -- it must be planted next to a host plant " +
                "(Pigeon Pea, Neem, or Acacia) and takes weeks to mature, but a single mature tree is worth a fortune.",
            fontSize = 13.sp,
            modifier = Modifier.padding(top = 8.dp),
        )
        Card(
            modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primary),
            onClick = onBuild,
        ) {
            Box(modifier = Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                Text(
                    "Clear Land for ₹${GameData.AGROFORESTRY_UNLOCK_COST}",
                    color = MaterialTheme.colorScheme.onPrimary,
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                )
            }
        }
    }
}

@Composable
private fun AgroPlotCard(
    plot: Plot,
    nowMillis: Long,
    onEmptyTapped: () -> Unit,
    onHostTapped: () -> Unit,
    onHarvestTapped: () -> Unit,
) {
    val host = plot.hostType
    when {
        host != null -> HostTile(host, onHostTapped)
        plot.state is PlotState.Empty -> EmptyAgroTile(onEmptyTapped)
        plot.state is PlotState.Growing -> SandalwoodGrowingTile(plot.state as PlotState.Growing, nowMillis)
        plot.state is PlotState.ReadyToHarvest -> SandalwoodReadyTile(onHarvestTapped)
    }
}

@Composable
private fun HostTile(host: HostType, onClick: () -> Unit) {
    Card(
        modifier = Modifier.aspectRatio(1f),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = FieldGreenLight.copy(alpha = 0.25f)),
        border = BorderStroke(2.dp, FieldGreenLight),
        onClick = onClick,
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(host.emoji, fontSize = 28.sp)
                Text(host.displayName, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                Text("tap to remove", fontSize = 9.sp)
            }
        }
    }
}

@Composable
private fun EmptyAgroTile(onClick: () -> Unit) {
    Card(
        modifier = Modifier.aspectRatio(1f),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        border = BorderStroke(2.dp, SoilBrown.copy(alpha = 0.35f)),
        onClick = onClick,
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("+", fontSize = 30.sp, color = SoilBrown.copy(alpha = 0.5f), fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun SandalwoodGrowingTile(state: PlotState.Growing, nowMillis: Long) {
    val totalMs = state.effectiveGrowSeconds * 1000L
    val elapsedMs = (nowMillis - state.plantedAtEpochMs).coerceIn(0, totalMs)
    val progress = if (totalMs > 0) elapsedMs.toFloat() / totalMs.toFloat() else 1f
    val remainingSeconds = ceil((totalMs - elapsedMs) / 1000.0).toLong().coerceAtLeast(0)

    Card(
        modifier = Modifier.aspectRatio(1f),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = FieldGreenLight.copy(alpha = 0.18f)),
        border = BorderStroke(2.dp, FieldGreenLight.copy(alpha = 0.6f)),
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(6.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                Text(state.crop.emoji, fontSize = 26.sp)
            }
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier.fillMaxWidth(),
                color = FieldGreenLight,
            )
            Text(text = formatLongDuration(remainingSeconds), fontSize = 10.sp, color = SoilBrown)
        }
    }
}

@Composable
private fun SandalwoodReadyTile(onClick: () -> Unit) {
    Card(
        modifier = Modifier.aspectRatio(1f),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = RipeGold.copy(alpha = 0.25f)),
        border = BorderStroke(2.5.dp, RipeGold),
        onClick = onClick,
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(CropType.SANDALWOOD.emoji, fontSize = 32.sp)
                Text("Tap!", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = SoilBrown)
            }
        }
    }
}

@Composable
fun AgroPlantPicker(
    coins: Long,
    canPlantSandalwood: Boolean,
    onHostChosen: (HostType) -> Unit,
    onSandalwoodChosen: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
        Text("Plant on this tile", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text(
            "Host plants are placed instantly and support a Sandalwood tree in an adjacent tile.",
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 4.dp, bottom = 8.dp),
        )
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            HostType.entries.forEach { host ->
                val affordable = coins >= host.cost
                PlantOptionRow(
                    emoji = host.emoji,
                    title = host.displayName,
                    subtitle = if (host == HostType.ACACIA) "Instant · shortens Sandalwood grow time" else "Instant",
                    cost = host.cost,
                    enabled = affordable,
                    onClick = { onHostChosen(host) },
                )
            }
            val sandalwood = CropType.SANDALWOOD
            val affordable = coins >= sandalwood.seedCost
            PlantOptionRow(
                emoji = sandalwood.emoji,
                title = sandalwood.displayName,
                subtitle = if (canPlantSandalwood) {
                    "${sandalwood.growSeconds / 86400}+ days · sells ₹${sandalwood.baseSellPrice}"
                } else {
                    "Needs an adjacent host plant"
                },
                cost = sandalwood.seedCost,
                enabled = affordable && canPlantSandalwood,
                onClick = onSandalwoodChosen,
            )
        }
    }
}

@Composable
private fun PlantOptionRow(
    emoji: String,
    title: String,
    subtitle: String,
    cost: Long,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = { if (enabled) onClick() },
        colors = CardDefaults.cardColors(
            containerColor = if (enabled) {
                MaterialTheme.colorScheme.surfaceVariant
            } else {
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
            },
        ),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(emoji, fontSize = 26.sp, modifier = Modifier.padding(end = 10.dp))
                Column {
                    Text(title, fontWeight = FontWeight.Bold)
                    Text(subtitle, fontSize = 12.sp)
                }
            }
            Text("₹$cost", fontWeight = FontWeight.Bold)
        }
    }
}

private fun formatLongDuration(totalSeconds: Long): String {
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
