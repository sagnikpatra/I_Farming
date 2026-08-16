package com.zonkrik.ifarming.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zonkrik.ifarming.game.GameData
import com.zonkrik.ifarming.game.GameState
import com.zonkrik.ifarming.game.GameViewModel

@Composable
fun FarmhouseTab(state: GameState, viewModel: GameViewModel) {
    val currentDef = GameData.farmhouseLevelDef(state.farmhouseLevel)
    val isMaxLevel = state.farmhouseLevel >= GameData.FARMHOUSE_MAX_LEVEL
    val nextDef = if (isMaxLevel) null else GameData.farmhouseLevelDef(state.farmhouseLevel + 1)

    val storageUsed = viewModel.totalInventoryUnits(state)
    val storageCap = viewModel.storageCapacity(state)
    val storageProgress = (storageUsed.toFloat() / storageCap.toFloat()).coerceIn(0f, 1f)

    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(currentDef.emoji, fontSize = 56.sp)
        Text(
            currentDef.displayName,
            fontWeight = FontWeight.Bold,
            fontSize = 20.sp,
            modifier = Modifier.padding(top = 6.dp),
        )
        Text(
            "Farmhouse Level ${currentDef.level} of ${GameData.FARMHOUSE_MAX_LEVEL}",
            fontSize = 12.sp,
            modifier = Modifier.padding(top = 2.dp),
        )

        Card(modifier = Modifier.fillMaxWidth().padding(top = 16.dp)) {
            Column(modifier = Modifier.padding(14.dp)) {
                Text("Current Bonuses", fontWeight = FontWeight.Bold, modifier = Modifier.padding(bottom = 8.dp))
                BonusRow("📦 Storage capacity", "${currentDef.storageCapacity} units")
                BonusRow("⚡ Growth speed", "+${currentDef.growthSpeedBonusPercent}% faster")
                BonusRow("💰 Sell price", "+${currentDef.sellPriceBonusPercent}%")
            }
        }

        Card(modifier = Modifier.fillMaxWidth().padding(top = 12.dp)) {
            Column(modifier = Modifier.padding(14.dp)) {
                Text(
                    "Storage: $storageUsed / $storageCap",
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 8.dp),
                )
                LinearProgressIndicator(progress = { storageProgress }, modifier = Modifier.fillMaxWidth())
            }
        }

        if (nextDef != null) {
            Card(modifier = Modifier.fillMaxWidth().padding(top = 12.dp)) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Text(
                        "${nextDef.emoji} Next: ${nextDef.displayName}",
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(bottom = 8.dp),
                    )
                    BonusRow("📦 Storage capacity", "${nextDef.storageCapacity} units")
                    BonusRow("⚡ Growth speed", "+${nextDef.growthSpeedBonusPercent}% faster")
                    BonusRow("💰 Sell price", "+${nextDef.sellPriceBonusPercent}%")
                }
            }
            Card(
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primary),
                onClick = { viewModel.buyFarmhouseUpgrade() },
            ) {
                Box(modifier = Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                    Text(
                        "Upgrade for ₹${nextDef.upgradeCost}",
                        color = MaterialTheme.colorScheme.onPrimary,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                    )
                }
            }
        } else {
            Text(
                "🎉 Your farmhouse has reached its finest form.",
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 16.dp),
            )
        }
    }
}

@Composable
private fun BonusRow(label: String, value: String) {
    Column(modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
        Text("$label: $value", fontSize = 13.sp)
    }
}
