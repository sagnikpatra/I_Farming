package com.zonkrik.ifarming.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zonkrik.ifarming.game.Plot
import com.zonkrik.ifarming.game.PlotState
import com.zonkrik.ifarming.ui.theme.FieldGreen
import com.zonkrik.ifarming.ui.theme.FieldGreenDark
import com.zonkrik.ifarming.ui.theme.RipeGold
import com.zonkrik.ifarming.ui.theme.SaffronDark
import com.zonkrik.ifarming.ui.theme.SoilBrown
import com.zonkrik.ifarming.ui.theme.SoilBrownDark
import kotlin.math.ceil
import androidx.compose.material3.Text as M3Text

@Composable
fun PlotCard(
    plot: Plot,
    nowMillis: Long,
    onEmptyTapped: (Int) -> Unit,
    onHarvestTapped: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    when (val s = plot.state) {
        is PlotState.Empty -> EmptyPlot(modifier) { onEmptyTapped(plot.id) }
        is PlotState.Growing -> GrowingPlot(s, nowMillis, modifier)
        is PlotState.ReadyToHarvest -> ReadyPlot(s, modifier) { onHarvestTapped(plot.id) }
    }
}

/** Bold outlined text -- readable over the busy gradient/board backgrounds. */
@Composable
private fun OutlinedLabel(text: String, fontSize: androidx.compose.ui.unit.TextUnit, color: Color = Color.White) {
    M3Text(
        text,
        fontSize = fontSize,
        fontWeight = FontWeight.Bold,
        color = color,
        style = TextStyle(shadow = Shadow(Color.Black.copy(alpha = 0.55f), Offset(1f, 1.5f), 2f)),
    )
}

@Composable
private fun EmptyPlot(modifier: Modifier, onClick: () -> Unit) {
    ChunkyTile(
        modifier = modifier.aspectRatio(1f),
        topColor = SoilBrown,
        bottomColor = SoilBrownDark,
        cornerRadius = 12.dp,
        elevation = 3.dp,
        onClick = onClick,
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            OutlinedLabel("+", 32.sp)
        }
    }
}

@Composable
private fun GrowingPlot(state: PlotState.Growing, nowMillis: Long, modifier: Modifier) {
    val totalMs = state.effectiveGrowSeconds * 1000L
    val elapsedMs = (nowMillis - state.plantedAtEpochMs).coerceIn(0, totalMs)
    val progress = if (totalMs > 0) elapsedMs.toFloat() / totalMs.toFloat() else 1f
    val remainingSeconds = ceil((totalMs - elapsedMs) / 1000.0).toLong().coerceAtLeast(0)

    ChunkyTile(
        modifier = modifier.aspectRatio(1f),
        topColor = FieldGreen,
        bottomColor = FieldGreenDark,
        cornerRadius = 12.dp,
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(6.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                M3Text(state.crop.emoji, fontSize = 26.sp)
            }
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier.fillMaxWidth(),
                color = RipeGold,
                trackColor = Color.Black.copy(alpha = 0.25f),
            )
            OutlinedLabel(formatSeconds(remainingSeconds), 11.sp)
        }
    }
}

@Composable
private fun ReadyPlot(state: PlotState.ReadyToHarvest, modifier: Modifier, onClick: () -> Unit) {
    ChunkyTile(
        modifier = modifier.aspectRatio(1f),
        topColor = RipeGold,
        bottomColor = SaffronDark,
        cornerRadius = 12.dp,
        elevation = 7.dp,
        onClick = onClick,
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                M3Text(state.crop.emoji, fontSize = 32.sp)
                OutlinedLabel("Tap!", 11.sp)
            }
            if (state.weatherDamaged) {
                Box(modifier = Modifier.align(Alignment.TopEnd).padding(4.dp)) {
                    M3Text("⛈", fontSize = 14.sp)
                }
            }
        }
    }
}

private fun formatSeconds(totalSeconds: Long): String {
    val h = totalSeconds / 3600
    val m = (totalSeconds % 3600) / 60
    val s = totalSeconds % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
}
