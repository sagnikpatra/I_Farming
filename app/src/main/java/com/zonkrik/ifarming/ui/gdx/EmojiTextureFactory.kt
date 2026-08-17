package com.zonkrik.ifarming.ui.gdx

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import com.badlogic.gdx.graphics.Pixmap
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.g2d.TextureRegion

/**
 * Rasterizes an emoji (or any short string) into a LibGDX [Pixmap]/[TextureRegion] using Android's
 * own text rendering -- keeps the exact same visual identity as the Compose board (which just
 * draws these emoji as `Text`) without needing any external art assets, so there's zero new
 * licensing surface. `core` never touches Android APIs directly; it only ever sees the resulting
 * [TextureRegion]s.
 *
 * Split into a CPU-only [createPixmap] and a GPU-uploading [create]: LibGDX `Texture`s must only be
 * created on the GL thread, but the `Bitmap`/`Canvas` rasterization itself is safe from any thread
 * -- see [EmojiTextureCache], which uses [createPixmap] from the main thread and defers the
 * `Texture` upload to the GL thread.
 */
object EmojiTextureFactory {
    private const val SIZE_PX = 96

    fun createPixmap(emoji: String): Pixmap {
        val bitmap = Bitmap.createBitmap(SIZE_PX, SIZE_PX, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = SIZE_PX * 0.8f
            textAlign = Paint.Align.CENTER
        }
        val metrics = paint.fontMetrics
        val baselineY = SIZE_PX / 2f - (metrics.ascent + metrics.descent) / 2f
        canvas.drawText(emoji, SIZE_PX / 2f, baselineY, paint)

        val pixels = IntArray(SIZE_PX * SIZE_PX)
        bitmap.getPixels(pixels, 0, SIZE_PX, 0, 0, SIZE_PX, SIZE_PX)
        bitmap.recycle()

        val pixmap = Pixmap(SIZE_PX, SIZE_PX, Pixmap.Format.RGBA8888)
        for (y in 0 until SIZE_PX) {
            for (x in 0 until SIZE_PX) {
                // Android packs ARGB (0xAARRGGBB); LibGDX's RGBA8888 drawPixel wants RGBA order.
                val argb = pixels[y * SIZE_PX + x]
                val a = (argb ushr 24) and 0xFF
                val r = (argb ushr 16) and 0xFF
                val g = (argb ushr 8) and 0xFF
                val b = argb and 0xFF
                val rgba = (r shl 24) or (g shl 16) or (b shl 8) or a
                pixmap.drawPixel(x, y, rgba)
            }
        }
        return pixmap
    }

    /** Convenience for one-off use (creates and uploads immediately); must be called on the GL thread. */
    fun create(emoji: String): TextureRegion {
        val pixmap = createPixmap(emoji)
        val texture = Texture(pixmap)
        pixmap.dispose()
        return TextureRegion(texture)
    }
}
