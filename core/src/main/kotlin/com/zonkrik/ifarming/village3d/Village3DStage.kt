package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.graphics.GL20
import com.badlogic.gdx.graphics.OrthographicCamera
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
import com.zonkrik.ifarming.village.GroundKind
import com.zonkrik.ifarming.village.TileSnapshot
import kotlin.math.roundToInt

private const val MIN_DISTANCE = 3f
private const val MAX_DISTANCE = 18f
private const val DEFAULT_DISTANCE = 7f
private const val LONG_PRESS_SECONDS = 0.45f
private const val BILLBOARD_SIZE = 1f

/** Loose clamp on how far the camera target can pan from the village's center, in world units. */
private const val PAN_BOUNDS = 40f

/**
 * The 3D counterpart of the old 2D board's `VillageStage`: owns the camera, lighting, and every
 * tile's [Entity3D], and drives all touch interaction.
 *
 * Modified to use [OrthographicCamera] for a clean, "Clash of Clans" style isometric look.
 */
class Village3DStage {
    val camera = OrthographicCamera(24f, 24f * (Gdx.graphics.height.toFloat() / Gdx.graphics.width.toFloat()))
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
        // High-contrast, game-like lighting.
        environment.set(ColorAttribute(ColorAttribute.AmbientLight, 0.45f, 0.45f, 0.5f, 1f))
        environment.add(DirectionalLight().set(0.9f, 0.88f, 0.8f, -0.6f, -1f, -0.4f)) // Key (warm)
        environment.add(DirectionalLight().set(0.25f, 0.3f, 0.4f, 0.6f, -0.3f, 0.5f))  // Fill (cool)
        camera.near = 0.1f
        camera.far = 500f
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
                // Also moves the entity's shadow (Entity3D.refreshTransform keeps both in sync),
                // so the shadow now visibly follows the drag instead of staying behind.
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
        val panScale = (camera.viewportWidth * camera.zoom) / Gdx.graphics.width
        cameraTarget.mulAdd(CameraRig.groundRight, -deltaX * panScale)
        cameraTarget.mulAdd(CameraRig.groundForward, deltaY * panScale)
        cameraTarget.x = cameraTarget.x.coerceIn(-PAN_BOUNDS, PAN_BOUNDS)
        cameraTarget.z = cameraTarget.z.coerceIn(-PAN_BOUNDS, PAN_BOUNDS)
        updateCameraTransform()
    }

    private fun updateCameraTransform() {
        camera.zoom = distance / DEFAULT_DISTANCE
        camera.position.set(cameraTarget).mulAdd(CameraRig.offsetDir, 100f)
        camera.up.set(CameraRig.worldUp)
        camera.lookAt(cameraTarget)
        camera.update()
    }

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
                // Owned by the Entity3D itself (not a parallel list here) so it can never drift
                // out of sync with the entity's own position -- see Entity3D's doc comment.
                shadowInstance = ModelInstance(ShadowBlobBuilder.get()),
                draggable = tile.draggable,
                zoneId = tile.zoneId,
                decorationId = tile.decorationId,
                growthInfo = tile.growthInfo,
                rotationDegrees = tile.rotationDegrees,
                flippedX = tile.flippedX,
            )

            // Structures and decorations sit directly on the open grass (matching CoC's look);
            // only actual farm-plot ground states (tilled soil, growing, ready, water, the
            // land-expansion ghost) get a ground quad. Paths are special decorations that also
            // get a ground quad.
            val isStructureOrDecoration = tile.zoneId != null || tile.decorationId != null
            val isPath = tile.groundKind == GroundKind.PATH
            
            if (!isStructureOrDecoration || isPath) {
                groundInstances += ModelInstance(GroundModelBuilder.get(tile.groundKind)).apply {
                    transform.setToTranslation(Grid3D.tileToWorld(tile.tileX, tile.tileY))
                    if (isPath) transform.translate(0f, 0.01f, 0f) // Avoid z-fighting
                }
            }
        }
    }

    private fun billboardInstanceFor(tile: TileSnapshot, sprites: Map<String, TextureRegion>): ModelInstance? {
        val region = sprites[tile.spriteKey] ?: return null
        val model = billboardCache.getOrPut(tile.spriteKey) { BillboardModelBuilder.build(region, BILLBOARD_SIZE) }
        return ModelInstance(model)
    }

    fun cameraSnapshot(): Camera3DSnapshot = Camera3DSnapshot(
        position = camera.position.cpy(),
        direction = camera.direction.cpy(),
        up = camera.up.cpy(),
        fieldOfViewY = 0f, 
        near = camera.near,
        far = camera.far,
        viewportWidth = camera.viewportWidth,
        viewportHeight = camera.viewportHeight,
        pixelWidth = Gdx.graphics.width,
        pixelHeight = Gdx.graphics.height,
        isOrthographic = true,
        zoom = camera.zoom,
    )

    fun centerCameraOn(tileX: Float, tileY: Float) {
        Grid3D.tileToWorld(tileX, tileY, cameraTarget)
        distance = DEFAULT_DISTANCE
        updateCameraTransform()
    }

    fun resize(width: Int, height: Int) {
        val aspect = height.toFloat() / width.toFloat()
        camera.viewportWidth = 24f
        camera.viewportHeight = 24f * aspect
        camera.update()
    }

    fun render() {
        Gdx.gl.glViewport(0, 0, Gdx.graphics.width, Gdx.graphics.height)
        // Soft, natural grass green (original color)
        Gdx.gl.glClearColor(0.663f, 0.851f, 0.478f, 1f)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT or GL20.GL_DEPTH_BUFFER_BIT)
        Gdx.gl.glEnable(GL20.GL_DEPTH_TEST)

        modelBatch.begin(camera)
        groundInstances.forEach { modelBatch.render(it, environment) }
        entities.forEach { modelBatch.render(it.shadowInstance, environment) }
        entities.forEach { modelBatch.render(it.instance, environment) }
        modelBatch.end()
    }

    fun dispose() {
        modelBatch.dispose()
        model3DCache.dispose()
        billboardCache.values.forEach { it.dispose() }
        billboardCache.clear()
        GroundModelBuilder.disposeAll()
        ShadowBlobBuilder.dispose()
    }
}
