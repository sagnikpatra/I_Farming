package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.graphics.GL20
import com.badlogic.gdx.graphics.Pixmap
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.VertexAttributes.Usage
import com.badlogic.gdx.graphics.g3d.Material
import com.badlogic.gdx.graphics.g3d.Model
import com.badlogic.gdx.graphics.g3d.attributes.BlendingAttribute
import com.badlogic.gdx.graphics.g3d.attributes.IntAttribute
import com.badlogic.gdx.graphics.g3d.attributes.TextureAttribute
import com.badlogic.gdx.graphics.g3d.utils.ModelBuilder
import com.badlogic.gdx.math.Vector3
import kotlin.math.sqrt

/**
 * A soft, blurred, dark radial-gradient decal on the ground beneath an entity -- the classic
 * mobile-game "grounding" cue (Clash of Clans and nearly everything in its genre use this exact
 * blob-shadow trick rather than real shadow mapping) that the board was missing entirely, making
 * every building/decoration look like it was floating rather than standing on the grass.
 */
object ShadowBlobBuilder {
    private var cachedModel: Model? = null

    fun get(): Model = cachedModel ?: build().also { cachedModel = it }

    private fun build(): Model {
        val texture = buildSoftCircleTexture()
        val material = Material(
            TextureAttribute.createDiffuse(texture),
            BlendingAttribute(true, GL20.GL_SRC_ALPHA, GL20.GL_ONE_MINUS_SRC_ALPHA, 1f),
            IntAttribute.createCullFace(GL20.GL_NONE),
        )
        val attrs = (Usage.Position or Usage.Normal or Usage.TextureCoordinates).toLong()
        val builder = ModelBuilder()
        builder.begin()
        val part = builder.part("shadow", GL20.GL_TRIANGLES, attrs, material)
        val half = TILE_SPACING * 0.62f
        // Sits a hair above the ground plane to avoid z-fighting with it.
        part.rect(
            Vector3(-half, 0.02f, half), Vector3(half, 0.02f, half),
            Vector3(half, 0.02f, -half), Vector3(-half, 0.02f, -half),
            Vector3(0f, 1f, 0f),
        )
        val model = builder.end()
        model.manageDisposable(texture)
        return model
    }

    private fun buildSoftCircleTexture(): Texture {
        val size = 64
        val pixmap = Pixmap(size, size, Pixmap.Format.RGBA8888)
        val center = (size - 1) / 2f
        for (y in 0 until size) {
            for (x in 0 until size) {
                val dx = (x - center) / center
                val dy = (y - center) / center
                val dist = sqrt(dx * dx + dy * dy).coerceIn(0f, 1f)
                val alpha = ((1f - dist) * (1f - dist) * 0.6f).coerceIn(0f, 0.6f)
                pixmap.setColor(0f, 0f, 0f, alpha)
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
