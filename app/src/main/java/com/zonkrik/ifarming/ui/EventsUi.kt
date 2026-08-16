package com.zonkrik.ifarming.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import com.zonkrik.ifarming.ui.theme.FieldGreenLight
import com.zonkrik.ifarming.ui.theme.RipeGold

@Composable
fun EventsTab(state: GameState, nowMillis: Long, viewModel: GameViewModel) {
    Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        MonsoonCard(nowMillis = nowMillis, viewModel = viewModel)
        FestivalCard(state = state, nowMillis = nowMillis, viewModel = viewModel)
    }
}

@Composable
private fun MonsoonCard(nowMillis: Long, viewModel: GameViewModel) {
    val active = viewModel.isMonsoonActive(nowMillis)
    val remaining = viewModel.monsoonPhaseRemainingMs(nowMillis)

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = if (active) FieldGreenLight.copy(alpha = 0.2f) else MaterialTheme.colorScheme.surfaceVariant,
        ),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(if (active) "🌧️ Monsoon Season -- Active" else "☁️ Monsoon Season", fontWeight = FontWeight.Bold, fontSize = 17.sp)
            Text(
                if (active) "Ends in ${formatDuration(remaining)}" else "Next monsoon in ${formatDuration(remaining)}",
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 2.dp, bottom = 8.dp),
            )
            Text(
                "While active, open-field crops grow 20% faster but risk a 10% chance of total " +
                    "flood loss when they mature. Polyhouse owners are completely immune.",
                fontSize = 12.sp,
            )
        }
    }
}

@Composable
private fun FestivalCard(state: GameState, nowMillis: Long, viewModel: GameViewModel) {
    val active = viewModel.isFestivalActive(nowMillis)
    val remaining = viewModel.festivalPhaseRemainingMs(nowMillis)
    val festival = viewModel.currentFestival(nowMillis)
    val eventState = viewModel.eventStatePreview(nowMillis)
    val points = eventState.eventPoints
    val tier = eventState.eventClaimedTier
    val hasPremium = eventState.eventHasPremiumPass
    val nextThreshold = GameData.FESTIVAL_TIER_THRESHOLDS.getOrNull(tier)
    val progress = if (nextThreshold != null) {
        (points.toFloat() / nextThreshold.toFloat()).coerceIn(0f, 1f)
    } else {
        1f
    }

    Card(modifier = Modifier.fillMaxWidth().padding(top = 12.dp)) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                "${festival.emoji} ${festival.displayName}",
                fontWeight = FontWeight.Bold,
                fontSize = 17.sp,
            )
            Text(
                if (active) {
                    "Active -- ends in ${formatDuration(remaining)}"
                } else {
                    "Not running -- next festival in ${formatDuration(remaining)}"
                },
                fontSize = 12.sp,
                modifier = Modifier.padding(top = 2.dp, bottom = 4.dp),
            )
            Text(
                "Sell ${festival.targetCrop.emoji} ${festival.targetCrop.displayName} while the festival " +
                    "is running to earn Event Points and climb the reward tiers.",
                fontSize = 12.sp,
                modifier = Modifier.padding(bottom = 10.dp),
            )

            Text(
                if (nextThreshold != null) "Points: $points / $nextThreshold" else "Points: $points -- all tiers reached!",
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp,
                modifier = Modifier.padding(bottom = 6.dp),
            )
            LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth())

            Column(modifier = Modifier.padding(top = 14.dp)) {
                GameData.FESTIVAL_TIER_THRESHOLDS.forEachIndexed { index, threshold ->
                    TierRow(
                        tierNumber = index + 1,
                        threshold = threshold,
                        freeReward = GameData.FESTIVAL_FREE_REWARDS[index],
                        premiumReward = GameData.FESTIVAL_PREMIUM_BONUS[index],
                        reached = tier > index,
                        hasPremium = hasPremium,
                    )
                }
            }

            if (!hasPremium) {
                Card(
                    modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = if (active) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                    ),
                    onClick = { viewModel.buyPremiumPass() },
                ) {
                    Box(modifier = Modifier.fillMaxWidth().padding(14.dp), contentAlignment = Alignment.Center) {
                        Text(
                            if (active) {
                                "Buy Premium Pass -- ₹${GameData.FESTIVAL_PREMIUM_PASS_COST}"
                            } else {
                                "Premium Pass available during festivals"
                            },
                            color = if (active) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp,
                        )
                    }
                }
            } else {
                Text(
                    "🎫 Premium Pass active for this festival",
                    fontWeight = FontWeight.Bold,
                    fontSize = 12.sp,
                    color = RipeGold,
                    modifier = Modifier.padding(top = 10.dp),
                )
            }
        }
    }
}

@Composable
private fun TierRow(tierNumber: Int, threshold: Int, freeReward: Long, premiumReward: Long, reached: Boolean, hasPremium: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            "${if (reached) "✅" else "▫️"} Tier $tierNumber ($threshold pts)",
            fontSize = 12.sp,
            fontWeight = if (reached) FontWeight.Bold else FontWeight.Normal,
        )
        Text(
            if (hasPremium) "₹$freeReward + ₹$premiumReward" else "₹$freeReward (+₹$premiumReward 🔒)",
            fontSize = 12.sp,
        )
    }
}

private fun formatDuration(ms: Long): String {
    val totalMinutes = (ms / 60000).coerceAtLeast(0)
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}
