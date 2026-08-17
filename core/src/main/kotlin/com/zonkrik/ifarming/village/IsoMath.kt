package com.zonkrik.ifarming.village

/**
 * Standard 2:1 isometric diamond projection -- the same math already proven in the Compose board
 * (`ui/iso/IsoProjection.kt`'s `worldToScreen`/`depthKey`). Duplicated here deliberately: `core`
 * must not depend on the `app` module (wrong dependency direction for a platform-independent
 * LibGDX module), and it's only a handful of lines.
 */
class IsoMath(
    private val tileWidth: Float = 128f,
    private val tileHeight: Float = 64f,
) {
    /** Grid (tileX, tileY) -> screen pixel position of the tile's center-top point. */
    fun gridToScreen(tileX: Float, tileY: Float): Pair<Float, Float> {
        val screenX = (tileX - tileY) * (tileWidth / 2f)
        val screenY = (tileX + tileY) * (tileHeight / 2f)
        return screenX to screenY
    }

    /** Inverse of [gridToScreen] -- world pixel position -> grid (tileX, tileY), for drag-to-reposition. */
    fun screenToGrid(screenX: Float, screenY: Float): Pair<Float, Float> {
        val tileX = (screenX / (tileWidth / 2f) + screenY / (tileHeight / 2f)) / 2f
        val tileY = (screenY / (tileHeight / 2f) - screenX / (tileWidth / 2f)) / 2f
        return tileX to tileY
    }

    /**
     * Depth-sort key: entities further "back" (smaller tileX + tileY) must draw first so closer
     * ones draw on top and overlap correctly. See `VillageStage.resortDepth`.
     */
    fun depthKey(tileX: Float, tileY: Float): Float = tileX + tileY
}
