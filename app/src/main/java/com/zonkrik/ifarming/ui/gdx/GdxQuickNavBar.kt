package com.zonkrik.ifarming.ui.gdx

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zonkrik.ifarming.ui.ChunkyTile
import com.zonkrik.ifarming.ui.theme.SaffronDark
import com.zonkrik.ifarming.ui.theme.WoodBrownLight

private data class QuickNavTarget(val emoji: String, val col: Float, val row: Float)

/**
 * Screen-space row of icon chips that instantly recenter the LibGDX camera on a zone -- the
 * `GdxVillageBoard` equivalent of the earlier Compose board's `QuickNavBar`. [onNavigate] is
 * responsible for marshaling the camera move onto the GL thread (see `GdxVillageBoard`).
 *
 * [homeAnchor] is the Farmhouse's *current* (tileX, tileY) -- unlike the other six zones (whose
 * quick-nav targets still point at their fixed default anchors), Home always needs to track
 * wherever the Farmhouse actually is, since it's the one building every player expects "Home" to
 * mean, drag-to-reposition or not.
 */
@Composable
fun GdxQuickNavBar(homeAnchor: Pair<Float, Float>, onNavigate: (Float, Float) -> Unit, modifier: Modifier = Modifier) {
    val targets = listOf(
        QuickNavTarget("🏠", homeAnchor.first, homeAnchor.second),
        QuickNavTarget("🌾", 6f, -6f),
        QuickNavTarget("🏚️", -8f, -6f),
        QuickNavTarget("🌳", -8f, 6f),
        QuickNavTarget("🪷", 8f, 6f),
        QuickNavTarget("🌸", 8f, -6f),
        QuickNavTarget("🏛️", 0f, 12f),
    )

    LazyRow(
        modifier = modifier.padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(targets) { target ->
            ChunkyTile(
                topColor = WoodBrownLight,
                bottomColor = SaffronDark,
                cornerRadius = 50.dp,
                elevation = 3.dp,
                onClick = { onNavigate(target.col, target.row) },
            ) {
                Box(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
                    Text(target.emoji, fontSize = 18.sp)
                }
            }
        }
    }
}
