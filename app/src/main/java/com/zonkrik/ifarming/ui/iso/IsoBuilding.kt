package com.zonkrik.ifarming.ui.iso

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zonkrik.ifarming.ui.ResourceBadge
import com.zonkrik.ifarming.ui.theme.SoilBrown
import com.zonkrik.ifarming.ui.theme.SoilBrownDark

/**
 * A standing building sprite on one ground tile -- used for Farmhouse/Polyhouse/Agroforestry/
 * Aquaculture/VerticalFarm/Mandi. Tapping always opens that zone's management sheet (see
 * `IsoSheet`); plot-level plant/harvest interaction happens on separate [IsoPlotTile]s placed
 * around the building, not here.
 */
@Composable
fun IsoBuilding(
    col: Float,
    row: Float,
    emoji: String,
    groundTopColor: Color,
    groundBottomColor: Color = groundTopColor,
    locked: Boolean = false,
    badgeText: String? = null,
    onClick: () -> Unit,
) {
    IsoEntity(col = col, row = row, spriteStandHeight = 84.dp) {
        Box(contentAlignment = Alignment.BottomCenter) {
            IsoGroundTile(topColor = groundTopColor, bottomColor = groundBottomColor, onClick = onClick)
            Column(
                modifier = Modifier.padding(bottom = TILE_HEIGHT * 0.35f),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Box(contentAlignment = Alignment.TopEnd) {
                    Text(
                        emoji,
                        fontSize = if (locked) 32.sp else 44.sp,
                        modifier = if (locked) Modifier.alpha(0.4f) else Modifier,
                    )
                    if (locked) {
                        Text("🔒", fontSize = 15.sp)
                    }
                }
                if (badgeText != null) {
                    ResourceBadge(text = badgeText, modifier = Modifier.padding(top = 4.dp))
                }
            }
        }
    }
}

/**
 * The next purchasable Open Field slot -- a dimmed ground tile calling [onClick]
 * (`viewModel.buyLandExpansion()`) directly, mirroring today's "+Land" FAB but placed on the map.
 */
@Composable
fun IsoLandGhostTile(col: Float, row: Float, cost: Long, onClick: () -> Unit) {
    IsoEntity(col = col, row = row, spriteStandHeight = 40.dp) {
        Box(contentAlignment = Alignment.BottomCenter) {
            IsoGroundTile(
                topColor = SoilBrown.copy(alpha = 0.55f),
                bottomColor = SoilBrownDark.copy(alpha = 0.55f),
                onClick = onClick,
            ) {
                Box(modifier = Modifier.padding(0.dp), contentAlignment = Alignment.Center) {
                    Text("🌍", fontSize = 20.sp)
                }
            }
            ResourceBadge(text = "+Land ₹$cost", modifier = Modifier.padding(bottom = TILE_HEIGHT * 0.6f))
        }
    }
}
