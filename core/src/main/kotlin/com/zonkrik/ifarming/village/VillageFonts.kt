package com.zonkrik.ifarming.village

import com.badlogic.gdx.graphics.g2d.BitmapFont

/**
 * A single shared, lazily-created LibGDX default embedded font -- no asset files needed (it ships
 * inside the LibGDX jar), keeping this free/open-source with zero new licensing surface. Used for
 * the growth countdown label; crop/building icons still come from [com.zonkrik.ifarming.ui.gdx.
 * EmojiTextureCache] since a bitmap font can't render color emoji.
 */
object VillageFonts {
    private var font: BitmapFont? = null

    fun get(): BitmapFont = font ?: BitmapFont().also {
        it.data.setScale(0.9f)
        font = it
    }

    fun dispose() {
        font?.dispose()
        font = null
    }
}
