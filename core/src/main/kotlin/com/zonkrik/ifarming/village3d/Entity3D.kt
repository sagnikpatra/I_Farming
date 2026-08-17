package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.graphics.g3d.ModelInstance
import com.badlogic.gdx.math.Vector3
import com.badlogic.gdx.math.collision.BoundingBox
import com.zonkrik.ifarming.village.GrowthInfo

/**
 * Half-extent of an entity's tap/ray-pick hit box, in world units.
 *
 * Kept narrower than a full tile (half-width * 2 < TILE_SPACING) so adjacent tiles' boxes never
 * touch laterally. The height matters more than it looks: with the board's steep camera angle,
 * a single orthographic ray sweeps roughly (height * 0.42) world units sideways as it passes
 * through one box's vertical extent (0.42 = the ray direction's X/Z-per-Y slope at this camera's
 * angle) -- a too-tall box lets one tap's ray graze through *other* tiles' boxes several tile
 * -widths away, not just its immediate neighbors. Confirmed on-device: at the old 3.5-unit height
 * a single tap could register hits on a plot and an unrelated structure zone ~7 tiles apart.
 */
private const val HIT_BOX_HALF_WIDTH = TILE_SPACING * 0.48f
private const val HIT_BOX_HEIGHT = 2.2f

/**
 * One tile's 3D representation: either a hand-picked model ([Model3DAssets]) or a billboarded emoji
 * quad ([BillboardModelBuilder]), wrapped with enough game-facing state ([tileX]/[tileY],
 * [draggable], [zoneId]/[decorationId]) for [Village3DStage] to route taps/drags -- the 3D
 * counterpart of the 2D board's `Building` Scene2D actor, minus any Scene2D dependency (hit-testing
 * here is manual ray-picking against [bounds], not free actor hit-testing).
 *
 * Owns [shadowInstance] directly (rather than [Village3DStage] tracking a parallel shadow list) so
 * [refreshTransform] can never let the two drift apart -- a shadow living in its own list, keyed
 * only by rebuild-time iteration order, previously stayed frozen at the entity's pre-drag position
 * while the entity itself followed the finger during a long-press-drag.
 */
class Entity3D(
    val tileId: Int,
    var tileX: Float,
    var tileY: Float,
    val instance: ModelInstance,
    val shadowInstance: ModelInstance,
    val draggable: Boolean,
    val zoneId: String?,
    val decorationId: Int?,
    val growthInfo: GrowthInfo?,
    var rotationDegrees: Int,
    var flippedX: Boolean,
) {
    val bounds = BoundingBox()

    /** Structures/decorations get a slightly larger shadow than a crop-plot billboard -- see [Village3DStage]'s old shadow-building logic, now folded in here. */
    private val isStructureOrDecoration = zoneId != null || decorationId != null

    init {
        refreshTransform()
    }

    /** Re-derives [instance]'s and [shadowInstance]'s world transforms and [bounds] from [tileX]/[tileY]/[rotationDegrees]/[flippedX] -- called after any of those change (initial placement, live-drag, or a rotate/flip). */
    fun refreshTransform() {
        val world = Grid3D.tileToWorld(tileX, tileY)
        instance.transform
            .setToTranslation(world)
            .rotate(Vector3.Y, rotationDegrees.toFloat())
        if (flippedX) instance.transform.scale(-1f, 1f, 1f)

        shadowInstance.transform.setToTranslation(world)
        if (isStructureOrDecoration) shadowInstance.transform.scale(1.5f, 1f, 1.5f)

        bounds.set(
            Vector3(world.x - HIT_BOX_HALF_WIDTH, 0f, world.z - HIT_BOX_HALF_WIDTH),
            Vector3(world.x + HIT_BOX_HALF_WIDTH, HIT_BOX_HEIGHT, world.z + HIT_BOX_HALF_WIDTH),
        )
    }
}
