package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.graphics.GL20
import com.badlogic.gdx.graphics.Pixmap
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.VertexAttributes.Usage
import com.badlogic.gdx.graphics.g3d.Material
import com.badlogic.gdx.graphics.g3d.Model
import com.badlogic.gdx.graphics.g3d.attributes.TextureAttribute
import com.badlogic.gdx.graphics.g3d.utils.ModelBuilder
import com.badlogic.gdx.math.Vector3
import kotlin.random.Random

/**
 * One large tiled ground plane covering the whole pannable area, with a procedurally speckled
 * texture -- sun-baked olive farmland with soft flecks of bare soil showing through, not a flat
 * solid green. The board previously had nothing here at all beyond the GL clear color, which read
 * as an empty, textureless void once buildings were made appropriately large/CoC-scaled -- most of
 * the screen is this plane, not the small per-tile [GroundModelBuilder] quads (those only cover
 * actual farm plots).
 */
object TerrainModelBuilder {
    private var cachedModel: Model? = null

    // Comfortably covers the pannable area (PAN_BOUNDS in Village3DStage) plus visible margin at
    // any zoom level, so the plane's edge is never visible on-screen.
    private const val TERRAIN_HALF_SIZE = 70f
    private const val UV_REPEAT = 14f
    private const val TEXTURE_SIZE = 128

    fun get(): Model = cachedModel ?: build().also { cachedModel = it }

    private fun build(): Model {
        val texture = buildTexture()
        texture.setWrap(Texture.TextureWrap.Repeat, Texture.TextureWrap.Repeat)
        // Pixmap-backed textures default to nearest-neighbour filtering, which made the noise
        // pattern look like blocky TV static once magnified on screen -- linear filtering blends
        // it into soft, organic-looking mottling instead.
        texture.setFilter(Texture.TextureFilter.Linear, Texture.TextureFilter.Linear)
        val material = Material(TextureAttribute.createDiffuse(texture))
        val attrs = (Usage.Position or Usage.Normal or Usage.TextureCoordinates).toLong()
        val builder = ModelBuilder()
        builder.begin()
        val part = builder.part("terrain", GL20.GL_TRIANGLES, attrs, material)
        part.setUVRange(0f, 0f, UV_REPEAT, UV_REPEAT)
        part.rect(
            Vector3(-TERRAIN_HALF_SIZE, 0f, TERRAIN_HALF_SIZE), Vector3(TERRAIN_HALF_SIZE, 0f, TERRAIN_HALF_SIZE),
            Vector3(TERRAIN_HALF_SIZE, 0f, -TERRAIN_HALF_SIZE), Vector3(-TERRAIN_HALF_SIZE, 0f, -TERRAIN_HALF_SIZE),
            Vector3(0f, 1f, 0f),
        )
        val model = builder.end()
        model.manageDisposable(texture)
        return model
    }

    private fun buildTexture(): Texture {
        // Fixed seed -- a stable, non-flickering pattern every time the model is (re)built, not
        // fresh random noise each launch.
        val random = Random(42)

        // Generate raw per-pixel variation first, then box-blur it -- sharp per-pixel noise reads
        // as "static"; blurred noise reads as soft, organic mottling (clumps of slightly
        // darker/lighter grass, the way a real field actually looks from above).
        val raw = FloatArray(TEXTURE_SIZE * TEXTURE_SIZE) { random.nextFloat() }
        val soilMask = FloatArray(TEXTURE_SIZE * TEXTURE_SIZE) { if (random.nextFloat() < 0.05f) 1f else 0f }

        fun blur(src: FloatArray, radius: Int): FloatArray {
            val out = FloatArray(src.size)
            for (y in 0 until TEXTURE_SIZE) {
                for (x in 0 until TEXTURE_SIZE) {
                    var sum = 0f
                    var count = 0
                    for (dy in -radius..radius) {
                        for (dx in -radius..radius) {
                            // Wrap at the edges so the tiled texture has no visible seam.
                            val sx = (x + dx + TEXTURE_SIZE) % TEXTURE_SIZE
                            val sy = (y + dy + TEXTURE_SIZE) % TEXTURE_SIZE
                            sum += src[sy * TEXTURE_SIZE + sx]
                            count++
                        }
                    }
                    out[y * TEXTURE_SIZE + x] = sum / count
                }
            }
            return out
        }

        val grassNoise = blur(raw, radius = 2)
        val soilBlobs = blur(soilMask, radius = 3)

        val pixmap = Pixmap(TEXTURE_SIZE, TEXTURE_SIZE, Pixmap.Format.RGBA8888)
        // Warm, sun-baked farmland base -- olive-green with brown/tan blotches of bare soil.
        val baseR = 0.55f
        val baseG = 0.62f
        val baseB = 0.32f
        for (y in 0 until TEXTURE_SIZE) {
            for (x in 0 until TEXTURE_SIZE) {
                val idx = y * TEXTURE_SIZE + x
                val variation = (grassNoise[idx] - 0.5f) * 0.16f
                val soilAmount = (soilBlobs[idx] * 2.2f).coerceIn(0f, 1f) // sharpen the blurred mask back up a bit
                val r = (baseR + variation + soilAmount * 0.12f).coerceIn(0.2f, 0.8f)
                val g = (baseG + variation - soilAmount * 0.14f).coerceIn(0.25f, 0.8f)
                val b = (baseB + variation * 0.6f - soilAmount * 0.08f).coerceIn(0.12f, 0.55f)
                pixmap.setColor(r, g, b, 1f)
                pixmap.drawPixel(x, y)
            }
        }
        val texture = Texture(pixmap)
        pixmap.dispose()
        return texture
    }

    fun dispose() {
        cachedModel?.dispose()
        cachedModel = null
    }
}
