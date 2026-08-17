package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.graphics.GL20
import com.badlogic.gdx.graphics.PerspectiveCamera
import com.badlogic.gdx.graphics.g2d.TextureRegion
import com.badlogic.gdx.graphics.g3d.Environment
import com.badlogic.gdx.graphics.g3d.ModelBatch
import com.badlogic.gdx.graphics.g3d.ModelInstance
import com.badlogic.gdx.graphics.g3d.attributes.ColorAttribute
import com.badlogic.gdx.graphics.g3d.environment.DirectionalLight
import com.badlogic.gdx.input.GestureDetector
import com.badlogic.gdx.math.Intersector
import com.badlogic.gdx.math.Plane
import com.badlogic.gdx.math.Vector3
import com.zonkrik.ifarming.village.TileSnapshot
import kotlin.math.roundToInt

private const val MIN_DISTANCE = 5f
private const val MAX_DISTANCE = 26f
private const val DEFAULT_DISTANCE = 12f
private const val LONG_PRESS_SECONDS = 0.45f
private const val BILLBOARD_SIZE = 1f

/** Loose clamp on how far the camera target can pan from the village's center, in world units. */
private const val PAN_BOUNDS = 40f

/**
 * The 3D counterpart of the old 2D board's `VillageStage`: owns the camera, lighting, and every
 * tile's [Entity3D], and drives all touch interaction. Scene2D's `Stage` gave the 2D board free
 * actor hit-testing and gesture routing for nothing; a real 3D scene has no such thing, so this
 * reimplements it by hand:
 *  - **Tap-to-select** / **long-press-then-drag**: raw [GestureDetector] (not Scene2D's
 *    `ActorGestureListener`, which needs a `Stage`) driving manual ray-picking
 *    ([Intersector.intersectRayBounds]) against each [Entity3D]'s [Entity3D.bounds].
 *  - **Drag position**: [Intersector.intersectRayPlane] against the ground plane (y=0) instead of
 *    the 2D board's `IsoMath.screenToGrid`.
 *  - **Pan/zoom**: moves a `cameraTarget` point across the ground plane / dollies the camera's
 *    distance from it, along [CameraRig]'s fixed basis -- the camera itself never rotates.
 */
class Village3DStage {
    val camera = PerspectiveCamera(52f, Gdx.graphics.width.toFloat(), Gdx.graphics.height.toFloat())
    private val environment = Environment()
    private val modelBatch = ModelBatch()
    private val model3DCache = Model3DCache()
    private val billboardCache = mutableMapOf<String, com.badlogic.gdx.graphics.g3d.Model>()

    private val entities = mutableListOf<Entity3D>()
    private val groundInstances = mutableListOf<ModelInstance>()

    private val cameraTarget = Vector3(0f, 0f, 0f)
    private var distance = DEFAULT_DISTANCE
    private val groundPlane = Plane(Vector3.Y, 0f)

    private var touchDownCandidate: Entity3D? = null
    private var draggedEntity: Entity3D? = null
    private var zoomBaselinePointerDistance = -1f
    private var zoomBaselineCameraDistance = DEFAULT_DISTANCE

    private var onTap: (Int) -> Unit = {}
    private var onZoneMoved: (String, Float, Float) -> Unit = { _, _, _ -> }
    private var onDecorationMoved: (Int, Float, Float) -> Unit = { _, _, _ -> }
    private var onGroundTapped: (Float, Float) -> Unit = { _, _ -> }

    val gestureDetector = GestureDetector(20f, 0.4f, LONG_PRESS_SECONDS, 0.15f, gestureListener())

    init {
        environment.set(ColorAttribute(ColorAttribute.AmbientLight, 0.6f, 0.6f, 0.62f, 1f))
        environment.add(DirectionalLight().set(0.75f, 0.75f, 0.7f, -0.5f, -1f, -0.35f))
        camera.near = 0.1f
        camera.far = 200f
        updateCameraTransform()
    }

    private fun gestureListener() = object : GestureDetector.GestureAdapter() {
        override fun touchDown(x: Float, y: Float, pointer: Int, button: Int): Boolean {
            touchDownCandidate = rayPick(x, y)
            return true
        }

        override fun tap(x: Float, y: Float, count: Int, button: Int): Boolean {
            val hit = rayPick(x, y)
            if (hit != null) {
                onTap(hit.tileId)
            } else {
                rayGroundPoint(x, y)?.let { onGroundTapped(it.x / TILE_SPACING, it.z / TILE_SPACING) }
            }
            return true
        }

        override fun longPress(x: Float, y: Float): Boolean {
            val candidate = touchDownCandidate ?: return false
            if (!candidate.draggable) return false
            draggedEntity = candidate
            return true
        }

        override fun pan(x: Float, y: Float, deltaX: Float, deltaY: Float): Boolean {
            val dragged = draggedEntity
            if (dragged != null) {
                val point = rayGroundPoint(x, y) ?: return true
                dragged.tileX = point.x / TILE_SPACING
                dragged.tileY = point.z / TILE_SPACING
                dragged.refreshTransform()
            } else {
                panCamera(deltaX, deltaY)
            }
            return true
        }

        override fun panStop(x: Float, y: Float, pointer: Int, button: Int): Boolean {
            val dragged = draggedEntity ?: return true
            dragged.tileX = dragged.tileX.roundToInt().toFloat()
            dragged.tileY = dragged.tileY.roundToInt().toFloat()
            dragged.refreshTransform()
            val decorationId = dragged.decorationId
            if (decorationId != null) {
                onDecorationMoved(decorationId, dragged.tileX, dragged.tileY)
            } else {
                dragged.zoneId?.let { onZoneMoved(it, dragged.tileX, dragged.tileY) }
            }
            draggedEntity = null
            touchDownCandidate = null
            return true
        }

        override fun zoom(initialDistance: Float, distance: Float): Boolean {
            if (initialDistance != zoomBaselinePointerDistance) {
                zoomBaselinePointerDistance = initialDistance
                zoomBaselineCameraDistance = this@Village3DStage.distance
            }
            this@Village3DStage.distance =
                (zoomBaselineCameraDistance * initialDistance / distance).coerceIn(MIN_DISTANCE, MAX_DISTANCE)
            updateCameraTransform()
            return true
        }
    }

    private fun rayPick(screenX: Float, screenY: Float): Entity3D? {
        val ray = camera.getPickRay(screenX, screenY)
        var closest: Entity3D? = null
        var closestDistance = Float.MAX_VALUE
        val hitPoint = Vector3()
        for (entity in entities) {
            if (Intersector.intersectRayBounds(ray, entity.bounds, hitPoint)) {
                val dst = hitPoint.dst2(camera.position)
                if (dst < closestDistance) {
                    closestDistance = dst
                    closest = entity
                }
            }
        }
        return closest
    }

    private fun rayGroundPoint(screenX: Float, screenY: Float): Vector3? {
        val ray = camera.getPickRay(screenX, screenY)
        val out = Vector3()
        return if (Intersector.intersectRayPlane(ray, groundPlane, out)) out else null
    }

    private fun panCamera(deltaX: Float, deltaY: Float) {
        // World units per screen pixel at the current zoom distance, so a drag keeps the tile under
        // the finger instead of feeling arbitrarily fast/slow as the player zooms in/out.
        val halfFovRadians = Math.toRadians(camera.fieldOfView / 2.0)
        val panScale = (2f * distance * Math.tan(halfFovRadians)).toFloat() / camera.viewportHeight
        cameraTarget.mulAdd(CameraRig.groundRight, -deltaX * panScale)
        cameraTarget.mulAdd(CameraRig.groundForward, deltaY * panScale)
        cameraTarget.x = cameraTarget.x.coerceIn(-PAN_BOUNDS, PAN_BOUNDS)
        cameraTarget.z = cameraTarget.z.coerceIn(-PAN_BOUNDS, PAN_BOUNDS)
        updateCameraTransform()
    }

    private fun updateCameraTransform() {
        camera.position.set(cameraTarget).mulAdd(CameraRig.offsetDir, distance)
        camera.up.set(CameraRig.worldUp)
        camera.lookAt(cameraTarget)
        camera.update()
    }

    /**
     * Replaces every tile with a fresh set built from [tiles] -- same full-rebuild-over-diffing
     * choice the 2D board made, for the same reason (simplicity, and the tile counts here are
     * modest). Must run on the GL thread. [onGroundTapped] fires with a (possibly non-integer)
     * world tile position whenever a tap misses every entity -- the host app only acts on it while
     * a decoration is armed for placement (see `GdxVillageBoard`).
     */
    fun rebuild(
        tiles: List<TileSnapshot>,
        sprites: Map<String, TextureRegion>,
        onTap: (Int) -> Unit,
        onZoneMoved: (String, Float, Float) -> Unit,
        onDecorationMoved: (Int, Float, Float) -> Unit,
        onGroundTapped: (Float, Float) -> Unit,
    ) {
        this.onTap = onTap
        this.onZoneMoved = onZoneMoved
        this.onDecorationMoved = onDecorationMoved
        this.onGroundTapped = onGroundTapped

        entities.clear()
        groundInstances.clear()

        tiles.forEach { tile ->
            val assetPath = Model3DAssets.assetFor(tile)
            val instance = if (assetPath != null) {
                runCatching { ModelInstance(model3DCache.get(assetPath)) }.getOrElse { billboardInstanceFor(tile, sprites) }
            } else {
                billboardInstanceFor(tile, sprites)
            } ?: return@forEach

            entities += Entity3D(
                tileId = tile.id,
                tileX = tile.tileX,
                tileY = tile.tileY,
                instance = instance,
                draggable = tile.draggable,
                zoneId = tile.zoneId,
                decorationId = tile.decorationId,
                growthInfo = tile.growthInfo,
                rotationDegrees = tile.rotationDegrees,
                flippedX = tile.flippedX,
            )

            groundInstances += ModelInstance(GroundModelBuilder.get(tile.groundKind)).apply {
                transform.setToTranslation(Grid3D.tileToWorld(tile.tileX, tile.tileY))
            }
        }
    }

    private fun billboardInstanceFor(tile: TileSnapshot, sprites: Map<String, TextureRegion>): ModelInstance? {
        val region = sprites[tile.spriteKey] ?: return null
        val model = billboardCache.getOrPut(tile.spriteKey) { BillboardModelBuilder.build(region, BILLBOARD_SIZE) }
        return ModelInstance(model)
    }

    /** A plain copy of the camera's current state -- see [Camera3DSnapshot]. */
    fun cameraSnapshot(): Camera3DSnapshot = Camera3DSnapshot(
        position = camera.position.cpy(),
        direction = camera.direction.cpy(),
        up = camera.up.cpy(),
        fieldOfViewY = camera.fieldOfView,
        near = camera.near,
        far = camera.far,
        viewportWidth = Gdx.graphics.width,
        viewportHeight = Gdx.graphics.height,
    )

    /** Instantly jumps the camera to center on world tile ([tileX], [tileY]) at default zoom -- used by quick-nav. */
    fun centerCameraOn(tileX: Float, tileY: Float) {
        Grid3D.tileToWorld(tileX, tileY, cameraTarget)
        distance = DEFAULT_DISTANCE
        updateCameraTransform()
    }

    fun resize(width: Int, height: Int) {
        camera.viewportWidth = width.toFloat()
        camera.viewportHeight = height.toFloat()
        camera.update()
    }

    fun render() {
        Gdx.gl.glViewport(0, 0, Gdx.graphics.width, Gdx.graphics.height)
        Gdx.gl.glClearColor(0.663f, 0.851f, 0.478f, 1f)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT or GL20.GL_DEPTH_BUFFER_BIT)
        Gdx.gl.glEnable(GL20.GL_DEPTH_TEST)

        modelBatch.begin(camera)
        groundInstances.forEach { modelBatch.render(it, environment) }
        entities.forEach { modelBatch.render(it.instance, environment) }
        modelBatch.end()
    }

    fun dispose() {
        modelBatch.dispose()
        model3DCache.dispose()
        billboardCache.values.forEach { it.dispose() }
        billboardCache.clear()
        GroundModelBuilder.disposeAll()
    }
}
