package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.ApplicationAdapter
import com.badlogic.gdx.Gdx
import com.badlogic.gdx.graphics.g2d.TextureRegion
import com.zonkrik.ifarming.village.TileSnapshot

/**
 * Entry point for the 3D village view's GL rendering -- the real-3D counterpart of the old 2D
 * board's `VillageGame`, same shape/callback signatures plus one addition ([onGroundTapped], since
 * a 3D scene's empty ground needs its own ray-picked tap report for decoration placement; the 2D
 * board handled that case in Compose instead, via `GdxVillageBoard`'s own inverse-projection math).
 */
class Village3DGame(
    private val onTap: (Int) -> Unit,
    private val onZoneMoved: (String, Float, Float) -> Unit,
    private val onDecorationMoved: (Int, Float, Float) -> Unit,
    private val onGroundTapped: (Float, Float) -> Unit,
) : ApplicationAdapter() {

    private lateinit var villageStage: Village3DStage

    /** Written once per frame (GL thread, end of [render]), read by the host app's Compose overlay (main thread) to project world positions to screen pixels for the info card. `@Volatile` guarantees the main thread sees the latest value without needing its own lock/queue. */
    @Volatile
    var cameraSnapshot: Camera3DSnapshot? = null
        private set

    override fun create() {
        villageStage = Village3DStage()
        Gdx.input.inputProcessor = villageStage.gestureDetector
    }

    /** Must be called from the GL thread (e.g. via `Gdx.app.postRunnable`) -- may create Models/Textures. */
    fun applySnapshot(tiles: List<TileSnapshot>, sprites: Map<String, TextureRegion>) {
        if (::villageStage.isInitialized) {
            villageStage.rebuild(tiles, sprites, onTap, onZoneMoved, onDecorationMoved, onGroundTapped)
        }
    }

    /** Must be called from the GL thread -- used by the quick-nav bar. */
    fun centerCameraOn(tileX: Float, tileY: Float) {
        if (::villageStage.isInitialized) villageStage.centerCameraOn(tileX, tileY)
    }

    override fun resize(width: Int, height: Int) {
        if (::villageStage.isInitialized) villageStage.resize(width, height)
    }

    override fun render() {
        if (::villageStage.isInitialized) {
            villageStage.render()
            cameraSnapshot = villageStage.cameraSnapshot()
        }
    }

    override fun dispose() {
        if (::villageStage.isInitialized) villageStage.dispose()
    }
}
