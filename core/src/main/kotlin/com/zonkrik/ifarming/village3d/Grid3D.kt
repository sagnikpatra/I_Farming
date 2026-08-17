package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.math.Vector3

/** World-space spacing between adjacent grid tiles, in 3D world units. */
const val TILE_SPACING = 1.6f

/** Converts between the game's abstract (tileX, tileY) grid coordinates and 3D world positions -- a ground plane at y=0, unlike the 2D board's isometric-projected screen pixels. */
object Grid3D {
    fun tileToWorld(tileX: Float, tileY: Float, out: Vector3 = Vector3()): Vector3 =
        out.set(tileX * TILE_SPACING, 0f, tileY * TILE_SPACING)
}
