package com.zonkrik.ifarming.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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
import com.zonkrik.ifarming.game.PlotKind
import com.zonkrik.ifarming.ui.theme.FieldGreenLight
import com.zonkrik.ifarming.ui.theme.RipeGold

@Composable
fun MandiTab(state: GameState, nowMillis: Long, viewModel: GameViewModel) {
    if (!state.hasMandi) {
        MandiBuildCard(onBuild = { viewModel.buyMandi() })
        return
    }

    val relevantCrops = CropType.entries.filter { crop ->
        when (crop.requiredPlotKind) {
            PlotKind.OPEN_FIELD -> true
            PlotKind.POLYHOUSE -> state.hasPolyhouse
            PlotKind.AGROFORESTRY -> state.hasAgroforestry
            PlotKind.AQUACULTURE -> state.hasAquaculture
            PlotKind.VERTICAL_FARM -> state.hasVerticalFarm
        }
    }

    LazyColumn(modifier = Modifier.fillMaxSize()) {
        item {
            Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                Text("🏛️ Local Mandi · e-NAM", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Text(
                    "Prices swing with server-wide demand and your own recent sales -- flood the " +
                        "market and the price dips until it recovers. Produce from protected " +
                        "cultivation earns an automatic A-Grade bonus.",
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 4.dp, bottom = 10.dp),
                )
                if (!state.hasMandiTerminal) {
                    Card(
                        onClick = { viewModel.buyMandiTerminal() },
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    ) {
                        Text(
                            "📡 Digital Auction Terminal ₹${GameData.MANDI_TERMINAL_COST} -- unlocks tomorrow's forecast",
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }
        }
        items(relevantCrops, key = { it.name }) { crop ->
            MandiCropRow(crop = crop, state = state, nowMillis = nowMillis, viewModel = viewModel)
        }
    }
}

@Composable
private fun MandiBuildCard(onBuild: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("🏛️", fontSize = 48.sp)
        Text(
            "Register at the Local Mandi",
            fontWeight = FontWeight.Bold,
            fontSize = 18.sp,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            "Trade crops through an e-NAM-style electronic auction instead of a flat roadside " +
                "price. Prices move with demand and your own recent selling, within safe bands -- " +
                "a genuine alternative to Quick Sell, not a replacement for it.",
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
                    "Register for ₹${GameData.MANDI_UNLOCK_COST}",
                    color = MaterialTheme.colorScheme.onPrimary,
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                )
            }
        }
    }
}

@Composable
private fun MandiCropRow(crop: CropType, state: GameState, nowMillis: Long, viewModel: GameViewModel) {
    val heldUnits = state.inventory[crop]?.total ?: 0
    val multiplier = viewModel.mandiPriceMultiplier(state, crop, nowMillis)
    val pct = (multiplier * 100).let { Math.round(it) }
    val trend = when {
        pct > 102 -> "▲"
        pct < 98 -> "▼"
        else -> "―"
    }
    val isGraded = crop.requiredPlotKind != PlotKind.OPEN_FIELD

    Card(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 5.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (heldUnits > 0) RipeGold.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant,
        ),
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(crop.emoji, fontSize = 22.sp, modifier = Modifier.padding(end = 8.dp))
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(crop.displayName, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            if (isGraded) {
                                Text(
                                    " A-Grade",
                                    fontSize = 10.sp,
                                    color = FieldGreenLight,
                                    fontWeight = FontWeight.Bold,
                                )
                            }
                        }
                        Text("Held: $heldUnits", fontSize = 11.sp)
                    }
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("$trend $pct%", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    if (state.hasMandiTerminal) {
                        val forecast = viewModel.mandiForecastPercent(crop, nowMillis)
                        val forecastTrend = if (forecast >= 0) "▲" else "▼"
                        Text("Tomorrow: $forecastTrend ${if (forecast >= 0) "+" else ""}$forecast%", fontSize = 10.sp)
                    }
                }
            }
            Card(
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                onClick = { if (heldUnits > 0) viewModel.sellToMandi(crop) },
                colors = CardDefaults.cardColors(
                    containerColor = if (heldUnits > 0) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    },
                ),
            ) {
                Box(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp), contentAlignment = Alignment.Center) {
                    Text(
                        if (heldUnits > 0) "Sell $heldUnits via Mandi" else "Nothing to sell",
                        color = if (heldUnits > 0) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                    )
                }
            }
        }
    }
}
