package com.zonkrik.ifarming.ui.gdx

import com.badlogic.gdx.graphics.Pixmap
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.g2d.TextureRegion

/**
 * Caches rasterized-emoji textures by string, split into two phases matching where each part is
 * safe to run:
 *  - [ensurePixmaps] -- CPU-only `Bitmap`/`Canvas` work, safe from any thread (call from Compose's
 *    main thread as soon as a snapshot's sprite keys are known).
 *  - [resolveTextures] -- uploads any pending Pixmaps to the GPU as Textures; must only run on the
 *    GL thread (call via `Gdx.app.postRunnable`).
 *
 * A small fixed set of strings for the zones ported so far (crop/host/farmhouse-level emoji, "+",
 * "🌍") -- cached for the process lifetime, matching how few distinct sprites Phase 1 needs.
 */
object EmojiTextureCache {
    private val pendingPixmaps = mutableMapOf<String, Pixmap>()
    private val textures = mutableMapOf<String, TextureRegion>()

    fun ensurePixmaps(keys: Set<String>) {
        for (key in keys) {
            if (key !in textures && key !in pendingPixmaps) {
                pendingPixmaps[key] = EmojiTextureFactory.createPixmap(key)
            }
        }
    }

    fun resolveTextures(keys: Set<String>): Map<String, TextureRegion> {
        for (key in keys) {
            if (key !in textures) {
                val pixmap = pendingPixmaps.remove(key) ?: continue
                val texture = Texture(pixmap)
                pixmap.dispose()
                textures[key] = TextureRegion(texture)
            }
        }
        return keys.mapNotNull { key -> textures[key]?.let { key to it } }.toMap()
    }
}
