package com.zonkrik.ifarming.ui.gdx

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
 * What's currently selected on the LibGDX board -- drives the floating [GdxInfoCard]. A single
 * shape covers both buildings (which carry an action, e.g. "Manage"/"Build ₹X", opening the
 * management sheet) and growing crops (info-only, no action -- just a details peek).
 */
data class GdxSelection(
    val tileX: Float,
    val tileY: Float,
    val emoji: String,
    val title: String,
    val subtitle: String,
    val actionLabel: String? = null,
    val onAction: (() -> Unit)? = null,
    /** Shown as a "↻" icon button when set -- draggable structures/decorations only. */
    val onRotate: (() -> Unit)? = null,
    /** Shown as a "⇋" icon button when set -- draggable structures/decorations only. */
    val onFlip: (() -> Unit)? = null,
    /** Shown as a "Remove" button when set -- decorations only. */
    val onRemove: (() -> Unit)? = null,
)

/**
 * A small floating "details" card anchored above the selected tile, Clash-of-Clans style -- the
 * LibGDX-board counterpart of the earlier Compose board's `IsoInfoCard`. Unlike that version, the
 * anchor's on-screen position isn't computed from a Compose-owned camera; the caller
 * ([GdxVillageBoard]) tracks the live LibGDX camera every frame (see `Camera3DSnapshot`) and passes
 * the already-resolved [screenPosition] in, so this composable itself only has to draw the card.
 */
@Composable
fun GdxInfoCard(selection: GdxSelection, screenPosition: Offset, onDismiss: () -> Unit) {
    Box(
        modifier = Modifier.offset {
            IntOffset(
                (screenPosition.x - 95.dp.toPx()).roundToInt(),
                (screenPosition.y - 190.dp.toPx()).roundToInt(),
            )
        },
    ) {
        ChunkyTile(
            modifier = Modifier.widthIn(min = 190.dp, max = 260.dp),
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
                val hasOrientationControls = selection.onRotate != null || selection.onFlip != null || selection.onRemove != null
                if (hasOrientationControls) {
                    Row(modifier = Modifier.padding(top = 10.dp)) {
                        selection.onRotate?.let { rotate ->
                            ChunkyButton(
                                modifier = Modifier.padding(end = 8.dp),
                                color = WoodBrownLight,
                                cornerRadius = 10.dp,
                                onClick = rotate,
                            ) {
                                Box(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
                                    Text("↻", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                                }
                            }
                        }
                        selection.onFlip?.let { flip ->
                            ChunkyButton(
                                modifier = Modifier.padding(end = 8.dp),
                                color = WoodBrownLight,
                                cornerRadius = 10.dp,
                                onClick = flip,
                            ) {
                                Box(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
                                    Text("⇋", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                                }
                            }
                        }
                        selection.onRemove?.let { remove ->
                            ChunkyButton(
                                color = SoilBrownDark,
                                cornerRadius = 10.dp,
                                onClick = remove,
                            ) {
                                Box(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
                                    Text("Remove", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                }
                            }
                        }
                    }
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
