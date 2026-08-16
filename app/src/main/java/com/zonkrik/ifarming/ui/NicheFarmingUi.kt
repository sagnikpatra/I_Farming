package com.zonkrik.ifarming.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items as lazyRowItems
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zonkrik.ifarming.game.GameData
import com.zonkrik.ifarming.game.GameState
import com.zonkrik.ifarming.game.GameViewModel
import com.zonkrik.ifarming.game.Plot
import com.zonkrik.ifarming.ui.theme.RipeGold

@Composable
fun NicheFarmingTab(
    state: GameState,
    nowMillis: Long,
    viewModel: GameViewModel,
    aquaculturePlots: List<Plot>,
    verticalFarmPlots: List<Plot>,
    onEmptyTapped: (Int) -> Unit,
    onHarvestTapped: (Int) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(bottom = 24.dp),
    ) {
        SectionHeader("🪷 Makhana Ponds")
        if (!state.hasAquaculture) {
            NicheBuildCard(
                emoji = "🪷",
                title = "Excavate Ponds",
                description = "Unlocks ${GameData.AQUACULTURE_PLOT_COUNT} pond plots for Makhana (Fox Nut) and " +
                    "Pond Fish -- a cheaper, faster-cycling alternative to Polyhouse crops.",
                costLabel = "Excavate for ₹${GameData.AQUACULTURE_UNLOCK_COST}",
                onBuild = { viewModel.buyAquaculture() },
            )
        } else {
            CompactPlotGrid(
                plots = aquaculturePlots,
                nowMillis = nowMillis,
                columns = 3,
                onEmptyTapped = onEmptyTapped,
                onHarvestTapped = onHarvestTapped,
            )
        }

        HorizontalDivider(modifier = Modifier.padding(vertical = 16.dp))

        SectionHeader("🌸 Saffron Vertical Farm")
        if (!state.hasVerticalFarm) {
            NicheBuildCard(
                emoji = "🌸",
                title = "Build a Vertical Farm",
                description = "Only ${GameData.VERTICAL_FARM_PLOT_COUNT} tiles, but Saffron sells for more per " +
                    "unit than anything except Sandalwood. Running the grow lights needs a recurring " +
                    "electricity payment to keep planting new cycles.",
                costLabel = "Build for ₹${GameData.VERTICAL_FARM_UNLOCK_COST}",
                onBuild = { viewModel.buyVerticalFarm() },
            )
        } else {
            ElectricityBar(state = state, nowMillis = nowMillis, viewModel = viewModel)
            CompactPlotGrid(
                plots = verticalFarmPlots,
                nowMillis = nowMillis,
                columns = 2,
                onEmptyTapped = onEmptyTapped,
                onHarvestTapped = onHarvestTapped,
            )
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        title,
        fontWeight = FontWeight.Bold,
        fontSize = 16.sp,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
    )
}

@Composable
private fun NicheBuildCard(
    emoji: String,
    title: String,
    description: String,
    costLabel: String,
    onBuild: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(emoji, fontSize = 40.sp)
        Text(title, fontWeight = FontWeight.Bold, fontSize = 17.sp, modifier = Modifier.padding(top = 4.dp))
        Text(description, fontSize = 13.sp, modifier = Modifier.padding(top = 6.dp))
        Card(
            modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primary),
            onClick = onBuild,
        ) {
            Box(modifier = Modifier.fillMaxWidth().padding(14.dp), contentAlignment = Alignment.Center) {
                Text(
                    costLabel,
                    color = MaterialTheme.colorScheme.onPrimary,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                )
            }
        }
    }
}

@Composable
private fun ElectricityBar(state: GameState, nowMillis: Long, viewModel: GameViewModel) {
    val active = viewModel.isElectricityActive(state, nowMillis)
    val remainingMs = state.electricityExpiresAtEpochMs?.let { it - nowMillis } ?: 0L

    LazyRow(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        lazyRowItems(listOf(0)) {
            Card(
                onClick = { viewModel.renewElectricity() },
                colors = CardDefaults.cardColors(
                    containerColor = if (active) RipeGold.copy(alpha = 0.3f) else MaterialTheme.colorScheme.surfaceVariant,
                ),
            ) {
                Text(
                    if (active) {
                        "⚡ Powered: ${formatHoursMinutes(remainingMs)} left"
                    } else {
                        "⚡ Pay Electricity ₹${GameData.ELECTRICITY_COST}"
                    },
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

@Composable
private fun CompactPlotGrid(
    plots: List<Plot>,
    nowMillis: Long,
    columns: Int,
    onEmptyTapped: (Int) -> Unit,
    onHarvestTapped: (Int) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        plots.chunked(columns).forEach { rowPlots ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                rowPlots.forEach { plot ->
                    PlotCard(
                        plot = plot,
                        nowMillis = nowMillis,
                        onEmptyTapped = onEmptyTapped,
                        onHarvestTapped = onHarvestTapped,
                        modifier = Modifier.weight(1f),
                    )
                }
                repeat(columns - rowPlots.size) {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

private fun formatHoursMinutes(ms: Long): String {
    val totalMinutes = (ms / 60000).coerceAtLeast(0)
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}
