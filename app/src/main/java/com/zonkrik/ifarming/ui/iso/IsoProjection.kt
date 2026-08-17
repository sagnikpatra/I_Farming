package com.zonkrik.ifarming.ui.iso

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp

/**
 * Pure math for the isometric board -- no Compose state here. Everything else (camera, layout,
 * board) is built on top of these two functions plus [TILE_WIDTH]/[TILE_HEIGHT].
 *
 * Standard 2:1 diamond projection: moving one step in `col` shifts screen-right-and-down, moving
 * one step in `row` shifts screen-left-and-down -- the classic isometric diamond grid. World
 * coordinates are plain floats so buildings can straddle whole tiles.
 */
const val TILE_WIDTH_DP = 128
const val TILE_HEIGHT_DP = 64

val TILE_WIDTH: Dp = TILE_WIDTH_DP.dp
val TILE_HEIGHT: Dp = TILE_HEIGHT_DP.dp

/**
 * World (col,row) -> Dp offset from the world origin. Pure Dp arithmetic -- Compose lays out
 * children in Dp regardless of the camera's runtime scale/pan (a `graphicsLayer` transform applied
 * after layout), so placing an [IsoEntity] via `Modifier.offset(x, y)` with this value keeps every
 * tile's hit-testing correct under any zoom/pan without any manual px conversion at placement time.
 */
fun worldToScreen(col: Float, row: Float): DpOffset =
    DpOffset(
        x = TILE_WIDTH * ((col - row) / 2f),
        y = TILE_HEIGHT * ((col + row) / 2f),
    )

/**
 * Painter's-algorithm depth key: tiles/buildings with a larger key are visually "closer" to the
 * camera (further down-screen) and must be drawn on top of ones with a smaller key. For a
 * multi-tile footprint, pass the (col,row) of the footprint corner closest to the screen bottom
 * (largest col+row within the footprint) so a building correctly occludes what's behind it.
 */
fun depthKey(col: Float, row: Float): Float = col + row
