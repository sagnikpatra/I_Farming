package com.zonkrik.ifarming.village

import com.badlogic.gdx.ApplicationAdapter
import com.badlogic.gdx.Gdx
import com.badlogic.gdx.graphics.GL20
import com.badlogic.gdx.graphics.g2d.TextureRegion

/**
 * Entry point for the village view's GL rendering. [onTap] fires with a tile's id whenever it's
 * tapped (see `TileSnapshot`/`FARMHOUSE_TILE_ID`/`LAND_GHOST_TILE_ID`); [onZoneMoved] fires with a
 * zone id + its new tile position after a long-press-drag (see `Building`/`ZONE_ID_*`). The host
 * app (`ui/gdx/GdxVillageBoard`) is responsible for marshaling both back onto the main thread
 * before touching any Compose state or the ViewModel, since both fire from Scene2D's input
 * handling on the GL thread.
 */
class VillageGame(
    private val onTap: (Int) -> Unit,
    private val onZoneMoved: (String, Float, Float) -> Unit,
    private val onDecorationMoved: (Int, Float, Float) -> Unit,
) : ApplicationAdapter() {

    private lateinit var villageStage: VillageStage

    /**
     * Written once per frame (GL thread, end of [render]), read by the host app's Compose overlay
     * (main thread) to track the selected tile's on-screen position for the info card. `@Volatile`
     * guarantees the main thread sees the latest value without needing its own lock/queue.
     */
    @Volatile
    var cameraSnapshot: CameraSnapshot? = null
        private set

    override fun create() {
        villageStage = VillageStage()
        Gdx.input.inputProcessor = villageStage.stage
    }

    /** Must be called from the GL thread (e.g. via `Gdx.app.postRunnable`) -- may create Textures. */
    fun applySnapshot(tiles: List<TileSnapshot>, sprites: Map<String, TextureRegion>) {
        if (::villageStage.isInitialized) villageStage.rebuild(tiles, sprites, onTap, onZoneMoved, onDecorationMoved)
    }

    /** Must be called from the GL thread -- used by the quick-nav bar. */
    fun centerCameraOn(tileX: Float, tileY: Float) {
        if (::villageStage.isInitialized) villageStage.centerCameraOn(tileX, tileY)
    }

    override fun resize(width: Int, height: Int) {
        if (::villageStage.isInitialized) villageStage.resize(width, height)
    }

    override fun render() {
        // Grass green, matching the Compose board's ground color (GrassGreenTop).
        Gdx.gl.glClearColor(0.663f, 0.851f, 0.478f, 1f)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT)
        if (::villageStage.isInitialized) {
            villageStage.render(Gdx.graphics.deltaTime)
            cameraSnapshot = villageStage.cameraSnapshot()
        }
    }

    override fun dispose() {
        if (::villageStage.isInitialized) villageStage.dispose()
        DiamondTextures.disposeAll()
        SolidTextures.disposeAll()
        VillageFonts.dispose()
    }
}
