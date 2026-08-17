package com.zonkrik.ifarming.ui.iso

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.StartOffset
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zonkrik.ifarming.game.CropType
import com.zonkrik.ifarming.game.HostType
import com.zonkrik.ifarming.game.Plot
import com.zonkrik.ifarming.game.PlotState
import com.zonkrik.ifarming.ui.OutlinedTitle
import com.zonkrik.ifarming.ui.theme.FieldGreen
import com.zonkrik.ifarming.ui.theme.FieldGreenDark
import com.zonkrik.ifarming.ui.theme.FieldGreenLight
import com.zonkrik.ifarming.ui.theme.RipeGold
import com.zonkrik.ifarming.ui.theme.SaffronDark
import com.zonkrik.ifarming.ui.theme.SoilBrown
import com.zonkrik.ifarming.ui.theme.SoilBrownDark
import com.zonkrik.ifarming.ui.theme.WaterBlue
import com.zonkrik.ifarming.ui.theme.WaterBlueDark
import kotlinx.coroutines.launch
import kotlin.math.ceil

/**
 * The isometric-board equivalent of [com.zonkrik.ifarming.ui.PlotCard] -- reproduces the same
 * Empty/Growing/ReadyToHarvest state logic (progress bar, countdown, weather-damage icon) and the
 * same callback shapes, so it drops straight into the existing `seedPickerPlotId = it` /
 * `viewModel.harvestPlot(it)` lambdas unchanged. Rendered as a standing sprite on a diamond ground
 * tile instead of a square card, with a little ambient "living world" motion (per the v2 design
 * doc's Visual Art Direction section): growing crops sway gently, ready crops bob to catch the eye,
 * and [isWater] tiles (Aquaculture) ripple.
 */
@Composable
fun IsoPlotTile(
    plot: Plot,
    col: Float,
    row: Float,
    nowMillis: Long,
    onEmptyTapped: (Int) -> Unit,
    onHarvestTapped: (Int) -> Unit,
    isWater: Boolean = false,
    /** Tapping a growing crop has nothing to *do* yet, but per the CoC-style info card, it should show its details. */
    onGrowingTapped: (() -> Unit)? = null,
) {
    IsoEntity(col = col, row = row) {
        when (val s = plot.state) {
            is PlotState.Empty -> IsoEmptyPlot(isWater = isWater) { onEmptyTapped(plot.id) }
            is PlotState.Growing -> IsoGrowingPlot(s, nowMillis, seed = plot.id, isWater = isWater, onClick = onGrowingTapped)
            is PlotState.ReadyToHarvest -> IsoReadyPlot(s) { onHarvestTapped(plot.id) }
        }
    }
}

@Composable
private fun IsoEmptyPlot(isWater: Boolean = false, onClick: () -> Unit) {
    IsoGroundTile(
        topColor = if (isWater) WaterBlue else SoilBrown,
        bottomColor = if (isWater) WaterBlueDark else SoilBrownDark,
        onClick = onClick,
    ) {
        if (isWater) WaterRipple(seed = 0)
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            OutlinedTitle("+", 22.sp)
        }
    }
}

@Composable
private fun IsoGrowingPlot(
    state: PlotState.Growing,
    nowMillis: Long,
    seed: Int = 0,
    isWater: Boolean = false,
    onClick: (() -> Unit)? = null,
) {
    val totalMs = state.effectiveGrowSeconds * 1000L
    val elapsedMs = (nowMillis - state.plantedAtEpochMs).coerceIn(0, totalMs)
    val progress = if (totalMs > 0) elapsedMs.toFloat() / totalMs.toFloat() else 1f
    val remainingSeconds = ceil((totalMs - elapsedMs) / 1000.0).toLong().coerceAtLeast(0)
    val sway = rememberSwayDegrees(seed)

    Box(contentAlignment = Alignment.BottomCenter) {
        IsoGroundTile(
            topColor = if (isWater) WaterBlue else FieldGreen,
            bottomColor = if (isWater) WaterBlueDark else FieldGreenDark,
            onClick = onClick,
        ) {
            if (isWater) WaterRipple(seed = seed)
        }
        Column(
            modifier = Modifier.padding(bottom = TILE_HEIGHT * 0.4f),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(state.crop.emoji, fontSize = 26.sp, modifier = Modifier.graphicsLayer { rotationZ = sway })
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier.width(TILE_WIDTH * 0.45f),
                color = RipeGold,
                trackColor = Color.Black.copy(alpha = 0.3f),
            )
            OutlinedTitle(formatSeconds(remainingSeconds), 10.sp)
        }
    }
}

@Composable
private fun IsoReadyPlot(state: PlotState.ReadyToHarvest, onClick: () -> Unit) {
    val bob = rememberBobOffset()
    Box(contentAlignment = Alignment.BottomCenter) {
        IsoGroundTile(topColor = RipeGold, bottomColor = SaffronDark, elevation = 7.dp, onClick = onClick)
        Column(
            modifier = Modifier.padding(bottom = TILE_HEIGHT * 0.4f).offset(y = (-6f * bob).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(state.crop.emoji, fontSize = 30.sp)
            OutlinedTitle(if (state.weatherDamaged) "⛈ Tap!" else "Tap!", 11.sp)
        }
    }
}

/**
 * The isometric-board equivalent of [com.zonkrik.ifarming.ui.AgroforestryTab]'s `AgroPlotCard` --
 * same host/Empty/Growing/ReadyToHarvest branching, same callback shapes, real world position
 * (see `IsoLayout.agroforestryOffset`).
 */
@Composable
fun IsoAgroTile(
    plot: Plot,
    col: Float,
    row: Float,
    nowMillis: Long,
    onEmptyTapped: (Int) -> Unit,
    onHostTapped: (Int) -> Unit,
    onHarvestTapped: (Int) -> Unit,
    onGrowingTapped: (() -> Unit)? = null,
) {
    val host = plot.hostType
    IsoEntity(col = col, row = row) {
        when {
            host != null -> IsoHostTile(host) { onHostTapped(plot.id) }
            plot.state is PlotState.Empty -> IsoEmptyPlot { onEmptyTapped(plot.id) }
            plot.state is PlotState.Growing -> IsoGrowingPlot(
                plot.state as PlotState.Growing,
                nowMillis,
                seed = plot.id,
                onClick = onGrowingTapped,
            )
            plot.state is PlotState.ReadyToHarvest -> IsoSandalwoodReadyTile { onHarvestTapped(plot.id) }
        }
    }
}

@Composable
private fun IsoHostTile(host: HostType, onClick: () -> Unit) {
    Box(contentAlignment = Alignment.BottomCenter) {
        IsoGroundTile(topColor = FieldGreenLight, bottomColor = FieldGreen, onClick = onClick)
        Column(
            modifier = Modifier.padding(bottom = TILE_HEIGHT * 0.4f),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(host.emoji, fontSize = 26.sp)
            OutlinedTitle("tap to remove", 9.sp)
        }
    }
}

@Composable
private fun IsoSandalwoodReadyTile(onClick: () -> Unit) {
    val bob = rememberBobOffset()
    Box(contentAlignment = Alignment.BottomCenter) {
        IsoGroundTile(topColor = RipeGold, bottomColor = SaffronDark, elevation = 7.dp, onClick = onClick)
        Column(
            modifier = Modifier.padding(bottom = TILE_HEIGHT * 0.4f).offset(y = (-6f * bob).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(CropType.SANDALWOOD.emoji, fontSize = 30.sp)
            OutlinedTitle("Tap!", 11.sp)
        }
    }
}

/**
 * A one-shot sparkle burst played at ([col],[row]) when a plot is harvested -- calls [onFinished]
 * once the animation completes so the caller can drop it from its tracking map. Independent of the
 * plot's own state so it keeps playing even though the plot itself flips to Empty/Growing the
 * instant the harvest is applied.
 */
@Composable
fun HarvestBurst(col: Float, row: Float, onFinished: () -> Unit) {
    val alpha = remember { Animatable(1f) }
    val scale = remember { Animatable(0.5f) }
    LaunchedEffect(col, row) {
        launch { scale.animateTo(1.6f, tween(450, easing = FastOutSlowInEasing)) }
        alpha.animateTo(0f, tween(450))
        onFinished()
    }
    IsoEntity(col = col, row = row, spriteStandHeight = 60.dp) {
        Text(
            "✨",
            fontSize = 30.sp,
            modifier = Modifier
                .padding(bottom = TILE_HEIGHT * 0.4f)
                .graphicsLayer {
                    this.alpha = alpha.value
                    scaleX = scale.value
                    scaleY = scale.value
                },
        )
    }
}

/** Slow, continuous 0..1 bob cycle -- used to lift ready-to-harvest sprites so they catch the eye. */
@Composable
private fun rememberBobOffset(): Float {
    val transition = rememberInfiniteTransition(label = "readyBob")
    val value by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(650, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "readyBobValue",
    )
    return value
}

/** Gentle +/-3 degree sway for growing crops, phase-offset by [seed] so a field doesn't sway in lockstep. */
@Composable
private fun rememberSwayDegrees(seed: Int): Float {
    val transition = rememberInfiniteTransition(label = "sway")
    val value by transition.animateFloat(
        initialValue = -3f,
        targetValue = 3f,
        animationSpec = infiniteRepeatable(
            animation = tween(1400, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse,
            initialStartOffset = StartOffset((seed % 5) * 220),
        ),
        label = "swayValue",
    )
    return value
}

/** A single expanding, fading ring -- drawn inside the diamond-clipped water tile it's called from. */
@Composable
private fun WaterRipple(seed: Int) {
    val transition = rememberInfiniteTransition(label = "ripple")
    val progress by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = LinearEasing),
            initialStartOffset = StartOffset((seed % 4) * 500),
        ),
        label = "rippleValue",
    )
    Canvas(modifier = Modifier.fillMaxSize()) {
        val maxRadius = size.minDimension / 2.2f
        drawCircle(
            color = Color.White.copy(alpha = (1f - progress).coerceIn(0f, 1f) * 0.5f),
            radius = maxRadius * progress.coerceAtLeast(0.05f),
            center = Offset(size.width / 2f, size.height / 2f),
            style = Stroke(width = 2.dp.toPx()),
        )
    }
}

private fun formatSeconds(totalSeconds: Long): String {
    val h = totalSeconds / 3600
    val m = (totalSeconds % 3600) / 60
    val s = totalSeconds % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
}
