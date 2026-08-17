package com.zonkrik.ifarming.village

import com.badlogic.gdx.graphics.Pixmap
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.g2d.TextureRegion

/**
 * Procedurally draws (and caches) one diamond ground-tile texture per [GroundKind] -- two filled
 * triangles via `Pixmap`, a simplified stand-in for the Compose board's full gradient bevel. Pure
 * LibGDX (no Android dependency needed, unlike the emoji sprites), but still a GPU resource: must
 * only be touched from the GL thread, same as any `Texture`.
 */
object DiamondTextures {
    private const val WIDTH = 128
    private const val HEIGHT = 64

    private val cache = mutableMapOf<GroundKind, TextureRegion>()

    fun get(kind: GroundKind): TextureRegion = cache.getOrPut(kind) { build(kind) }

    private fun build(kind: GroundKind): TextureRegion {
        val pixmap = Pixmap(WIDTH, HEIGHT, Pixmap.Format.RGBA8888)
        pixmap.setColor(kind.top)
        pixmap.fillTriangle(WIDTH / 2, 0, WIDTH, HEIGHT / 2, WIDTH / 2, HEIGHT)
        pixmap.setColor(kind.bottom)
        pixmap.fillTriangle(WIDTH / 2, HEIGHT, 0, HEIGHT / 2, WIDTH / 2, 0)
        val texture = Texture(pixmap)
        pixmap.dispose()
        return TextureRegion(texture)
    }

    fun disposeAll() {
        cache.values.forEach { it.texture.dispose() }
        cache.clear()
    }
}
