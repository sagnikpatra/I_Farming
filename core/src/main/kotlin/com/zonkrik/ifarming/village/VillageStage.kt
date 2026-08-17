package com.zonkrik.ifarming.village

import com.badlogic.gdx.graphics.OrthographicCamera
import com.badlogic.gdx.graphics.g2d.TextureRegion
import com.badlogic.gdx.scenes.scene2d.InputEvent
import com.badlogic.gdx.scenes.scene2d.Stage
import com.badlogic.gdx.scenes.scene2d.utils.ActorGestureListener
import com.badlogic.gdx.utils.viewport.ScreenViewport

private const val MIN_ZOOM = 0.5f
private const val MAX_ZOOM = 2.5f

/** Loose clamp on how far the camera can pan from the village's center, in world px. */
private const val PAN_BOUNDS = 1400f

/**
 * Owns the Scene2D Stage that renders and handles input for the whole village grid: tile taps (via
 * the Stage's own actor hit-testing) plus pan/pinch-zoom (via an [ActorGestureListener] on the
 * Stage's root actor -- the idiomatic Scene2D way to add camera gestures alongside clickable
 * actors, since touch events bubble from a hit child up through its ancestors, so a drag that
 * starts on a tile still reaches the root listener as a pan).
 */
class VillageStage {
    val camera = OrthographicCamera()
    val stage = Stage(ScreenViewport(camera))
    val isoMath = IsoMath()

    private val buildings = mutableListOf<Building>()
    private var zoomAtGestureStart = 1f

    /** Shared with every draggable [Building] -- see [DragCoordinator]'s doc for why this is needed. */
    private val dragCoordinator = DragCoordinator()

    init {
        stage.root.addListener(
            object : ActorGestureListener() {
                override fun touchDown(event: InputEvent?, x: Float, y: Float, pointer: Int, button: Int) {
                    zoomAtGestureStart = camera.zoom
                    super.touchDown(event, x, y, pointer, button)
                }

                override fun pan(event: InputEvent?, x: Float, y: Float, deltaX: Float, deltaY: Float) {
                    if (dragCoordinator.isDraggingBuilding) return
                    camera.position.x -= deltaX * camera.zoom
                    camera.position.y -= deltaY * camera.zoom
                    clampCamera()
                    camera.update()
                }

                override fun zoom(event: InputEvent?, initialDistance: Float, distance: Float) {
                    camera.zoom = (zoomAtGestureStart * initialDistance / distance).coerceIn(MIN_ZOOM, MAX_ZOOM)
                    camera.update()
                }
            },
        )
    }

    /**
     * Replaces every tile with a fresh set built from [tiles] -- simple full-rebuild reconciliation
     * rather than diffing (Compose recomposition does the equivalent diffing automatically for the
     * Compose board; Scene2D needs it done by hand, and a full rebuild is far simpler to get right
     * for the modest tile counts here). Must be called from the GL thread, since [sprites] lookups
     * and [DiamondTextures] may create Textures.
     */
    fun rebuild(
        tiles: List<TileSnapshot>,
        sprites: Map<String, TextureRegion>,
        onTap: (Int) -> Unit,
        onZoneMoved: (String, Float, Float) -> Unit,
        onDecorationMoved: (Int, Float, Float) -> Unit,
    ) {
        stage.clear()
        buildings.clear()
        tiles.forEach { tile ->
            val sprite = sprites[tile.spriteKey] ?: return@forEach
            val diamond = DiamondTextures.get(tile.groundKind)
            val building = Building(
                id = tile.id,
                tileX = tile.tileX,
                tileY = tile.tileY,
                diamond = diamond,
                sprite = sprite,
                isoMath = isoMath,
                groundKind = tile.groundKind,
                growthInfo = tile.growthInfo,
                draggable = tile.draggable,
                dragCoordinator = dragCoordinator,
                rotationDegrees = tile.rotationDegrees,
                flippedX = tile.flippedX,
                onTap = { onTap(tile.id) },
                onMoved = { newTileX, newTileY ->
                    val decorationId = tile.decorationId
                    if (decorationId != null) {
                        onDecorationMoved(decorationId, newTileX, newTileY)
                    } else {
                        tile.zoneId?.let { onZoneMoved(it, newTileX, newTileY) }
                    }
                },
            )
            buildings += building
            stage.addActor(building)
        }
        resortDepth()
    }

    /** Re-orders actors so ones further "forward" on the grid draw on top of ones further "back". */
    private fun resortDepth() {
        buildings.sortedBy { it.depthKey() }.forEach { it.toFront() }
    }

    /** A plain copy of the camera's current state -- see [CameraSnapshot]. */
    fun cameraSnapshot(): CameraSnapshot = CameraSnapshot(
        worldX = camera.position.x,
        worldY = camera.position.y,
        zoom = camera.zoom,
        viewportWidth = stage.viewport.screenWidth,
        viewportHeight = stage.viewport.screenHeight,
    )

    /** Instantly jumps the camera to center on world tile ([tileX], [tileY]) at default zoom -- used by quick-nav. */
    fun centerCameraOn(tileX: Float, tileY: Float) {
        val (screenX, screenY) = isoMath.gridToScreen(tileX, tileY)
        camera.position.set(screenX, screenY, 0f)
        camera.zoom = 1f
        clampCamera()
        camera.update()
    }

    private fun clampCamera() {
        camera.position.x = camera.position.x.coerceIn(-PAN_BOUNDS, PAN_BOUNDS)
        camera.position.y = camera.position.y.coerceIn(-PAN_BOUNDS, PAN_BOUNDS)
    }

    fun resize(width: Int, height: Int) {
        stage.viewport.update(width, height, true)
        // `core` deliberately doesn't know which world tile counts as "home" (the Farmhouse can be
        // dragged anywhere -- see the drag-to-reposition feature) -- the host app is responsible for
        // calling `centerCameraOn` once it knows the Farmhouse's actual position (see
        // `ui/gdx/GdxVillageBoard`'s initial-centering logic). Until then this just leaves whatever
        // position/zoom the camera already has (ScreenViewport's own viewport-midpoint default on
        // the very first call).
        camera.update()
    }

    fun render(delta: Float) {
        stage.act(delta)
        stage.draw()
    }

    fun dispose() {
        stage.dispose()
    }
}
