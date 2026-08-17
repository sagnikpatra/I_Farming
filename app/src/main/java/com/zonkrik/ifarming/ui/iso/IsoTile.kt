package com.zonkrik.ifarming.ui.iso

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.zonkrik.ifarming.ui.ChunkyTile
import com.zonkrik.ifarming.ui.theme.SoilBrownDark

/** The diamond outline every ground tile is clipped/bordered to -- a 2:1 isometric tile face. */
fun diamondShape(): Shape = GenericShape { size, _ ->
    moveTo(size.width / 2f, 0f)
    lineTo(size.width, size.height / 2f)
    lineTo(size.width / 2f, size.height)
    lineTo(0f, size.height / 2f)
    close()
}

/** A single diamond ground tile, styled with the same [ChunkyTile] gradient/border/bevel/shadow used everywhere else. */
@Composable
fun IsoGroundTile(
    modifier: Modifier = Modifier,
    topColor: Color,
    bottomColor: Color = topColor,
    borderColor: Color = SoilBrownDark,
    elevation: Dp = 3.dp,
    onClick: (() -> Unit)? = null,
    content: @Composable BoxScope.() -> Unit = {},
) {
    ChunkyTile(
        modifier = modifier.size(TILE_WIDTH, TILE_HEIGHT),
        topColor = topColor,
        bottomColor = bottomColor,
        borderColor = borderColor,
        elevation = elevation,
        shape = diamondShape(),
        onClick = onClick,
        content = content,
    )
}

/**
 * Positions any child at world grid ([col],[row]) inside the (already camera-transformed) board
 * content Box, and z-orders it via [depthKey] so painter's-algorithm depth sorting "just works"
 * regardless of composition order. [spriteStandHeight] reserves extra room above the tile's own
 * diamond footprint so a billboarded crop/building sprite can stand tall without shifting the
 * tile's own world-anchored position -- the ground diamond itself should be placed
 * bottom-and-center-aligned by [content].
 */
@Composable
fun IsoEntity(
    col: Float,
    row: Float,
    modifier: Modifier = Modifier,
    spriteStandHeight: Dp = 56.dp,
    content: @Composable BoxScope.() -> Unit,
) {
    val screen = worldToScreen(col, row)
    Box(
        modifier = modifier
            .offset(x = screen.x, y = screen.y - spriteStandHeight)
            .width(TILE_WIDTH)
            .height(TILE_HEIGHT + spriteStandHeight)
            .zIndex(depthKey(col, row)),
        contentAlignment = Alignment.BottomCenter,
    ) {
        content()
    }
}
