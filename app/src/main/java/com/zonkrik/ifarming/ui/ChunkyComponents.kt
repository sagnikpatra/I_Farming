package com.zonkrik.ifarming.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.zonkrik.ifarming.ui.theme.GoldLight
import com.zonkrik.ifarming.ui.theme.GrassGreenBottom
import com.zonkrik.ifarming.ui.theme.GrassGreenTop
import com.zonkrik.ifarming.ui.theme.SoilBrownDark
import com.zonkrik.ifarming.ui.theme.WoodBrownLight

/**
 * A chunky, beveled "3D game tile" -- the building-block of the Clash-of-Clans-flavored visual
 * language: gradient fill, glossy top highlight, dark inner bottom shadow, thick outline, and a
 * drop shadow lifting it off the board. Pure 2D layering (gradients + alpha overlays), so it never
 * changes hit-testing -- taps behave exactly as before, only the rendering is new.
 */
@Composable
fun ChunkyTile(
    modifier: Modifier = Modifier,
    topColor: Color,
    bottomColor: Color = topColor,
    borderColor: Color = SoilBrownDark,
    cornerRadius: Dp = 14.dp,
    elevation: Dp = 5.dp,
    onClick: (() -> Unit)? = null,
    content: @Composable BoxScope.() -> Unit,
) {
    val shape = RoundedCornerShape(cornerRadius)
    Box(
        modifier = modifier
            .shadow(elevation, shape, clip = false, ambientColor = Color.Black, spotColor = Color.Black)
            .clip(shape)
            .background(Brush.verticalGradient(listOf(topColor, bottomColor)))
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }
            .border(3.dp, borderColor, shape),
    ) {
        // Single full-bleed bevel gradient (highlight top, shadow bottom) via matchParentSize,
        // which Compose explicitly excludes from the Box's own size measurement -- unlike
        // fillMaxWidth/fillMaxHeight, this can never cause the tile to expand under loose constraints.
        Box(
            modifier = Modifier.matchParentSize().background(
                Brush.verticalGradient(
                    0.0f to Color.White.copy(alpha = 0.38f),
                    0.45f to Color.Transparent,
                    0.7f to Color.Transparent,
                    1.0f to Color.Black.copy(alpha = 0.28f),
                ),
            ),
        )
        content()
    }
}

/** A chunky beveled button: same visual language as [ChunkyTile] but sized/shaped for actions. */
@Composable
fun ChunkyButton(
    modifier: Modifier = Modifier,
    color: Color,
    enabled: Boolean = true,
    cornerRadius: Dp = 16.dp,
    onClick: () -> Unit,
    content: @Composable BoxScope.() -> Unit,
) {
    val shape = RoundedCornerShape(cornerRadius)
    val effectiveColor = if (enabled) color else color.copy(alpha = 0.45f)
    Box(
        modifier = modifier
            .shadow(if (enabled) 6.dp else 0.dp, shape, clip = false)
            .clip(shape)
            .background(Brush.verticalGradient(listOf(lighten(effectiveColor), effectiveColor)))
            .clickable(enabled = enabled, onClick = onClick)
            .border(2.5.dp, SoilBrownDark.copy(alpha = if (enabled) 1f else 0.5f), shape),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier.matchParentSize().background(
                Brush.verticalGradient(
                    0.0f to Color.White.copy(alpha = 0.32f),
                    0.55f to Color.Transparent,
                ),
            ),
        )
        content()
    }
}

/** Gold-trimmed pill used for the coin counter and similar always-visible readouts. */
@Composable
fun ResourceBadge(text: String, modifier: Modifier = Modifier, emoji: String? = null) {
    val shape = RoundedCornerShape(50)
    Box(
        modifier = modifier
            .shadow(4.dp, shape, clip = false)
            .clip(shape)
            .background(Brush.verticalGradient(listOf(WoodBrownLight, SoilBrownDark)))
            .border(2.dp, GoldLight, shape)
            .padding(horizontal = 14.dp, vertical = 7.dp),
    ) {
        Row {
            if (emoji != null) {
                Text(emoji, fontSize = 15.sp)
                Spacer(modifier = Modifier.padding(start = 3.dp))
            }
            Text(
                text,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 15.sp,
                style = TextStyle(shadow = Shadow(Color.Black.copy(alpha = 0.6f), Offset(1f, 1.5f), 2f)),
            )
        }
    }
}

/** Wood-and-gold banner used as the app's top bar, replacing the flat Material app bar. */
@Composable
fun BannerSurface(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    val shape = RoundedCornerShape(bottomStart = 18.dp, bottomEnd = 18.dp)
    Box(
        modifier = modifier
            .shadow(6.dp, shape)
            .background(Brush.verticalGradient(listOf(WoodBrownLight, SoilBrownDark)), shape = shape)
            .border(width = 2.dp, color = GoldLight.copy(alpha = 0.7f), shape = shape),
        content = content,
    )
}

/** Rich grass-green backdrop for the farm board, replacing the flat cream background. */
fun Modifier.gameGroundBackground(): Modifier = this.background(
    Brush.verticalGradient(listOf(GrassGreenTop, GrassGreenBottom)),
)

private fun lighten(color: Color, amount: Float = 0.18f): Color = Color(
    red = (color.red + (1f - color.red) * amount).coerceIn(0f, 1f),
    green = (color.green + (1f - color.green) * amount).coerceIn(0f, 1f),
    blue = (color.blue + (1f - color.blue) * amount).coerceIn(0f, 1f),
    alpha = color.alpha,
)
