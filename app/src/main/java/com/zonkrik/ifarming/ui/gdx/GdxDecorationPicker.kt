package com.zonkrik.ifarming.ui.gdx

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zonkrik.ifarming.game.DecorationType
import com.zonkrik.ifarming.ui.ChunkyTile
import com.zonkrik.ifarming.ui.OutlinedTitle
import com.zonkrik.ifarming.ui.theme.SoilBrownDark
import com.zonkrik.ifarming.ui.theme.WoodBrownLight

/**
 * Bottom-sheet picker for the "🎨" decorations HUD button -- same row-of-[ChunkyTile] shape as
 * `SeedPicker`. Choosing an entry arms placement mode in [GdxVillageBoard] (the next tap on the
 * board places it there) rather than placing immediately, since a decoration needs a world
 * position that only the board itself can resolve.
 */
@Composable
fun GdxDecorationPicker(coins: Long, onDecorationChosen: (DecorationType) -> Unit) {
    Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
        Text("Choose a decoration to place", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Column(modifier = Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            DecorationType.entries.forEach { type ->
                val affordable = coins >= type.cost
                ChunkyTile(
                    modifier = Modifier.fillMaxWidth(),
                    topColor = if (affordable) WoodBrownLight else WoodBrownLight.copy(alpha = 0.4f),
                    bottomColor = if (affordable) SoilBrownDark else SoilBrownDark.copy(alpha = 0.4f),
                    cornerRadius = 12.dp,
                    elevation = if (affordable) 4.dp else 0.dp,
                    onClick = { if (affordable) onDecorationChosen(type) },
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(type.emoji, fontSize = 26.sp, modifier = Modifier.padding(end = 10.dp))
                            OutlinedTitle(type.displayName, 14.sp)
                        }
                        OutlinedTitle("₹${type.cost}", 14.sp)
                    }
                }
            }
        }
    }
}
