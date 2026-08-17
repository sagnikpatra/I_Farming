package com.zonkrik.ifarming.ui.iso

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.VectorConverter
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.IntSize
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

const val ISO_MIN_SCALE = 0.6f
const val ISO_MAX_SCALE = 2.5f

/** How much of the viewport must always keep overlapping the known world content when clamping pan. */
private const val OVERLAP_FRACTION = 0.4f

/**
 * Camera state for the isometric board. [scale]/[offset] (px) drive a single `graphicsLayer` on
 * the board's content Box (see [isoCameraGestures] and `IsoBoard`). Live pinch/pan gestures
 * [applyGesture] the values directly for a 1:1 responsive feel; [centerOn] animates them for
 * programmatic camera moves (the initial Farmhouse-centered view, the quick-nav bar).
 */
class IsoCameraState {
    val scale = Animatable(1f)
    val offset = Animatable(Offset.Zero, Offset.VectorConverter)

    var viewportSize: IntSize = IntSize.Zero
    private var worldMinPx: Offset = Offset.Zero
    private var worldMaxPx: Offset = Offset.Zero

    /** Called once (world layout is static) to convert IsoLayout's Dp bounds into px for clamping. */
    fun setWorldBounds(minDp: DpOffset, maxDp: DpOffset, density: Density) {
        with(density) {
            worldMinPx = Offset(minDp.x.toPx(), minDp.y.toPx())
            worldMaxPx = Offset(maxDp.x.toPx(), maxDp.y.toPx())
        }
    }

    suspend fun applyGesture(centroid: Offset, pan: Offset, zoom: Float) {
        val newScale = (scale.value * zoom).coerceIn(ISO_MIN_SCALE, ISO_MAX_SCALE)
        // Zoom about the pinch centroid: keep the world point under the fingers fixed on screen.
        val zoomedOffset = centroid - (centroid - offset.value) * (newScale / scale.value)
        scale.snapTo(newScale)
        offset.snapTo(clampOffset(zoomedOffset + pan, newScale))
    }

    suspend fun centerOn(worldCol: Float, worldRow: Float, density: Density, targetScale: Float = scale.value) {
        if (viewportSize == IntSize.Zero) return
        val worldPointPx = with(density) {
            val dp = worldToScreen(worldCol, worldRow)
            Offset(dp.x.toPx(), dp.y.toPx())
        }
        val target = Offset(
            x = viewportSize.width / 2f - worldPointPx.x * targetScale,
            y = viewportSize.height / 2f - worldPointPx.y * targetScale,
        )
        scale.animateTo(targetScale)
        offset.animateTo(clampOffset(target, targetScale))
    }

    private fun clampOffset(candidate: Offset, atScale: Float): Offset {
        if (viewportSize == IntSize.Zero) return candidate
        val scaledMin = worldMinPx * atScale
        val scaledMax = worldMaxPx * atScale
        val overlapX = viewportSize.width * OVERLAP_FRACTION
        val overlapY = viewportSize.height * OVERLAP_FRACTION
        // The pan range that keeps >= overlapFraction of the viewport over the world content.
        val loX = viewportSize.width - overlapX - scaledMax.x
        val hiX = overlapX - scaledMin.x
        val loY = viewportSize.height - overlapY - scaledMax.y
        val hiY = overlapY - scaledMin.y
        return Offset(
            x = candidate.x.coerceIn(minOf(loX, hiX), maxOf(loX, hiX)),
            y = candidate.y.coerceIn(minOf(loY, hiY), maxOf(loY, hiY)),
        )
    }
}

@Composable
fun rememberIsoCameraState(): IsoCameraState = remember { IsoCameraState() }

/**
 * Combined pan + pinch-zoom gesture handling; ignores rotation (the isometric board never
 * rotates). [detectTransformGestures]'s `onGesture` callback is synchronous, so gesture frames are
 * forwarded to [IsoCameraState.applyGesture] (which does the actual `snapTo`) via [scope].
 */
fun Modifier.isoCameraGestures(camera: IsoCameraState, scope: CoroutineScope): Modifier =
    pointerInput(camera) {
        detectTransformGestures(panZoomLock = false) { centroid, pan, zoom, _ ->
            scope.launch { camera.applyGesture(centroid, pan, zoom) }
        }
    }
