package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.math.Vector3

/**
 * The board's fixed camera angle -- unlike a free-look 3D camera, this board only ever pans/zooms
 * (matching the old 2D board's exact gesture set, so the UX doesn't regress), never rotates. Both
 * [Village3DStage]'s camera itself and anything that needs to face it ([BillboardModelBuilder]'s
 * emoji quads) share this one fixed basis, computed once, rather than each recomputing it.
 *
 * [offsetDir] is the classic true-isometric direction (equal parts X/Y/Z) -- `(1,1,1)` normalized
 * gives the ~35.264 degree elevation angle isometric games are named for.
 */
object CameraRig {
    val offsetDir: Vector3 = Vector3(1f, 1f, 1f).nor()
    val worldUp: Vector3 = Vector3(0f, 1f, 0f)

    /** Unit vector pointing from the board toward the camera -- what a billboard's face should point along. */
    val towardCamera: Vector3 = offsetDir.cpy()

    val right: Vector3 = Vector3(towardCamera).crs(worldUp).nor()
    val up: Vector3 = Vector3(right).crs(towardCamera).nor()

    /** [right] and [towardCamera] flattened onto the ground plane -- used for screen-drag camera panning. */
    val groundRight: Vector3 = Vector3(right.x, 0f, right.z).nor()
    val groundForward: Vector3 = Vector3(-towardCamera.x, 0f, -towardCamera.z).nor()
}
