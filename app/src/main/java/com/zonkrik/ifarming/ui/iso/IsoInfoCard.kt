package com.zonkrik.ifarming.ui.iso

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zonkrik.ifarming.ui.ChunkyButton
import com.zonkrik.ifarming.ui.ChunkyTile
import com.zonkrik.ifarming.ui.theme.SaffronDark
import com.zonkrik.ifarming.ui.theme.SoilBrownDark
import com.zonkrik.ifarming.ui.theme.WoodBrownLight
import kotlin.math.roundToInt

/**
 * What's currently selected on the board -- drives the floating [IsoInfoCard]. A single shape
 * covers both buildings (which carry an action, e.g. "Manage"/"Build ₹X", opening the
 * management sheet) and growing crops (info-only, no action -- just a details peek that wasn't
 * available anywhere before this).
 */
data class IsoSelection(
    val col: Float,
    val row: Float,
    val emoji: String,
    val title: String,
    val subtitle: String,
    val actionLabel: String? = null,
    val onAction: (() -> Unit)? = null,
)

/**
 * A small floating "details" card anchored above the selected tile, Clash-of-Clans style: tap a
 * building or a growing crop to see what it is at a glance -- with an optional action button --
 * instead of jumping straight into a full sheet. Lives in screen space (a sibling of the
 * camera-transformed board content, not inside it) so it stays a constant, readable size while
 * tracking the anchor's live screen position as the camera pans/zooms.
 */
@Composable
fun IsoInfoCard(selection: IsoSelection, camera: IsoCameraState, onDismiss: () -> Unit) {
    val density = LocalDensity.current
    val anchorDp = worldToScreen(selection.col, selection.row)
    val anchorPx = with(density) { Offset(anchorDp.x.toPx(), anchorDp.y.toPx()) }
    val liftPx = with(density) { 92.dp.toPx() }

    Box(
        modifier = Modifier.offset {
            val screen = camera.offset.value + anchorPx * camera.scale.value
            IntOffset(screen.x.roundToInt(), (screen.y - liftPx).roundToInt())
        },
    ) {
        ChunkyTile(
            modifier = Modifier.widthIn(min = 190.dp, max = 260.dp).offset(x = (-95).dp),
            topColor = WoodBrownLight,
            bottomColor = SoilBrownDark,
            cornerRadius = 14.dp,
            elevation = 6.dp,
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(selection.emoji, fontSize = 24.sp, modifier = Modifier.padding(end = 8.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(selection.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                        Text(selection.subtitle, color = Color.White.copy(alpha = 0.85f), fontSize = 12.sp)
                    }
                    Text(
                        "✕",
                        color = Color.White.copy(alpha = 0.75f),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(start = 8.dp).clickable(onClick = onDismiss),
                    )
                }
                val action = selection.onAction
                if (selection.actionLabel != null && action != null) {
                    ChunkyButton(
                        modifier = Modifier.padding(top = 10.dp),
                        color = SaffronDark,
                        cornerRadius = 10.dp,
                        onClick = action,
                    ) {
                        Box(modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)) {
                            Text(selection.actionLabel, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        }
                    }
                }
            }
        }
    }
}
