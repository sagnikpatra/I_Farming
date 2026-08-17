package com.zonkrik.ifarming.village

/**
 * A plain, immutable copy of the camera's current world position/zoom/viewport size, written once
 * per frame by [VillageGame] (GL thread) and read by the host app's Compose overlay (main thread)
 * to position the CoC-style info card above a selected tile as the camera pans/zooms. `data class`
 * copies are safe to hand across threads without extra synchronization; only the holding field
 * (`VillageGame.cameraSnapshot`, `@Volatile`) needs to guarantee visibility of the latest one.
 */
data class CameraSnapshot(
    val worldX: Float,
    val worldY: Float,
    val zoom: Float,
    val viewportWidth: Int,
    val viewportHeight: Int,
)
