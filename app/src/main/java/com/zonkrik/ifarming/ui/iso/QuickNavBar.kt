package com.zonkrik.ifarming.ui.iso

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zonkrik.ifarming.ui.ChunkyTile
import com.zonkrik.ifarming.ui.theme.SaffronDark
import com.zonkrik.ifarming.ui.theme.WoodBrownLight
import kotlinx.coroutines.launch

private data class QuickNavTarget(val emoji: String, val label: String, val col: Float, val row: Float)

private val QUICK_NAV_TARGETS = listOf(
    QuickNavTarget("🏠", "Home", IsoLayout.FARMHOUSE.first, IsoLayout.FARMHOUSE.second),
    QuickNavTarget("🌾", "Field", IsoLayout.OPEN_FIELD_ANCHOR.first, IsoLayout.OPEN_FIELD_ANCHOR.second),
    QuickNavTarget("🏚️", "Polyhouse", IsoLayout.POLYHOUSE_ANCHOR.first, IsoLayout.POLYHOUSE_ANCHOR.second),
    QuickNavTarget("🌳", "Agroforestry", IsoLayout.AGROFORESTRY_ANCHOR.first, IsoLayout.AGROFORESTRY_ANCHOR.second),
    QuickNavTarget("🪷", "Ponds", IsoLayout.AQUACULTURE_ANCHOR.first, IsoLayout.AQUACULTURE_ANCHOR.second),
    QuickNavTarget("🌸", "Vertical Farm", IsoLayout.VERTICAL_FARM_ANCHOR.first, IsoLayout.VERTICAL_FARM_ANCHOR.second),
    QuickNavTarget("🏛️", "Mandi", IsoLayout.MANDI_ANCHOR.first, IsoLayout.MANDI_ANCHOR.second),
)

/**
 * Screen-space row of icon chips that pan the camera to a zone -- the isometric board's
 * replacement for the old `ScrollableTabRow`. Pure camera navigation: never opens a sheet or
 * touches the ViewModel.
 */
@Composable
fun QuickNavBar(camera: IsoCameraState, modifier: Modifier = Modifier) {
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()

    LazyRow(
        modifier = modifier.padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(QUICK_NAV_TARGETS) { target ->
            ChunkyTile(
                topColor = WoodBrownLight,
                bottomColor = SaffronDark,
                cornerRadius = 50.dp,
                elevation = 3.dp,
                onClick = { scope.launch { camera.centerOn(target.col, target.row, density) } },
            ) {
                Box(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
                    Text(target.emoji, fontSize = 18.sp)
                }
            }
        }
    }
}
