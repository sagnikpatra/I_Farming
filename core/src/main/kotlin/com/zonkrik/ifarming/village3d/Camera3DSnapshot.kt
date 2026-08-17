package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.math.Vector3

/**
 * A plain, immutable copy of the 3D camera's current state -- written once per frame on the GL
 * thread (see `Village3DGame.render`), read on the main thread (`ui/gdx/GdxVillageBoard`) to
 * project world positions to screen pixels for the info card, the 3D-camera equivalent of the old
 * 2D board's `CameraSnapshot`. Carries enough fields for the host app to reconstruct a throwaway
 * `PerspectiveCamera` and call `project()` on it -- see `GdxVillageBoard.screenPositionOf`.
 */
data class Camera3DSnapshot(
    val position: Vector3,
    val direction: Vector3,
    val up: Vector3,
    val fieldOfViewY: Float,
    val near: Float,
    val far: Float,
    val viewportWidth: Int,
    val viewportHeight: Int,
)
