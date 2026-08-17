package com.zonkrik.ifarming.village

import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.Pixmap
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.g2d.TextureRegion

/**
 * Two shared, lazily-created procedural textures -- a 1x1 white pixel (stretched/tinted for
 * progress-bar tracks/fills) and a filled circle (for the Aquaculture water-ripple effect). Pure
 * LibGDX `Pixmap` drawing, same as [DiamondTextures]; must only be touched from the GL thread.
 */
object SolidTextures {
    private var whiteRegion: TextureRegion? = null
    private var circleRegion: TextureRegion? = null

    fun white(): TextureRegion = whiteRegion ?: run {
        val pixmap = Pixmap(1, 1, Pixmap.Format.RGBA8888)
        pixmap.setColor(Color.WHITE)
        pixmap.fill()
        val texture = Texture(pixmap)
        pixmap.dispose()
        TextureRegion(texture).also { whiteRegion = it }
    }

    fun circle(): TextureRegion = circleRegion ?: run {
        val size = 64
        val pixmap = Pixmap(size, size, Pixmap.Format.RGBA8888)
        pixmap.setColor(Color.WHITE)
        pixmap.fillCircle(size / 2, size / 2, size / 2 - 2)
        val texture = Texture(pixmap)
        pixmap.dispose()
        TextureRegion(texture).also { circleRegion = it }
    }

    fun disposeAll() {
        whiteRegion?.texture?.dispose()
        circleRegion?.texture?.dispose()
        whiteRegion = null
        circleRegion = null
    }
}
