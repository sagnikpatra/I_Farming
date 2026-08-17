package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.graphics.g3d.ModelInstance
import com.badlogic.gdx.math.Vector3
import com.badlogic.gdx.math.collision.BoundingBox
import com.zonkrik.ifarming.village.GrowthInfo

/** Half-extent of an entity's tap/ray-pick hit box, in world units -- generous and uniform across every entity (rather than each model's exact, sometimes tiny, mesh bounds) so tapping still feels like "the whole tile is tappable", matching the old 2D board's per-tile hit-testing. */
private const val HIT_BOX_HALF_WIDTH = TILE_SPACING * 0.45f
private const val HIT_BOX_HEIGHT = 2.2f

/**
 * One tile's 3D representation: either a hand-picked model ([Model3DAssets]) or a billboarded emoji
 * quad ([BillboardModelBuilder]), wrapped with enough game-facing state ([tileX]/[tileY],
 * [draggable], [zoneId]/[decorationId]) for [Village3DStage] to route taps/drags -- the 3D
 * counterpart of the 2D board's `Building` Scene2D actor, minus any Scene2D dependency (hit-testing
 * here is manual ray-picking against [bounds], not free actor hit-testing).
 */
class Entity3D(
    val tileId: Int,
    var tileX: Float,
    var tileY: Float,
    val instance: ModelInstance,
    val draggable: Boolean,
    val zoneId: String?,
    val decorationId: Int?,
    val growthInfo: GrowthInfo?,
    var rotationDegrees: Int,
    var flippedX: Boolean,
) {
    val bounds = BoundingBox()

    init {
        refreshTransform()
    }

    /** Re-derives [instance]'s world transform and [bounds] from [tileX]/[tileY]/[rotationDegrees]/[flippedX] -- called after any of those change (initial placement, live-drag, or a rotate/flip). */
    fun refreshTransform() {
        val world = Grid3D.tileToWorld(tileX, tileY)
        instance.transform
            .setToTranslation(world)
            .rotate(Vector3.Y, rotationDegrees.toFloat())
        if (flippedX) instance.transform.scale(-1f, 1f, 1f)

        bounds.set(
            Vector3(world.x - HIT_BOX_HALF_WIDTH, 0f, world.z - HIT_BOX_HALF_WIDTH),
            Vector3(world.x + HIT_BOX_HALF_WIDTH, HIT_BOX_HEIGHT, world.z + HIT_BOX_HALF_WIDTH),
        )
    }
}
