package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.graphics.GL20
import com.badlogic.gdx.graphics.VertexAttributes.Usage
import com.badlogic.gdx.graphics.g3d.Material
import com.badlogic.gdx.graphics.g3d.Model
import com.badlogic.gdx.graphics.g3d.attributes.BlendingAttribute
import com.badlogic.gdx.graphics.g3d.attributes.ColorAttribute
import com.badlogic.gdx.graphics.g3d.utils.ModelBuilder
import com.badlogic.gdx.math.Vector3

/**
 * A fully transparent stand-in for [ShadowBlobBuilder], used by [Entity3D]s that already lie flat
 * on the ground (e.g. a [RangoliModelBuilder] decal) -- every entity needs a non-null
 * `shadowInstance` (see [Entity3D]), but a soft dark ground-shadow rendered directly underneath a
 * flat painted pattern would just muddy its colors rather than "ground" anything.
 */
object NoShadowBuilder {
    private var cachedModel: Model? = null

    fun get(): Model = cachedModel ?: build().also { cachedModel = it }

    private fun build(): Model {
        val material = Material(
            ColorAttribute(ColorAttribute.Diffuse, 0f, 0f, 0f, 0f),
            BlendingAttribute(true, GL20.GL_SRC_ALPHA, GL20.GL_ONE_MINUS_SRC_ALPHA, 0f),
        )
        val attrs = (Usage.Position or Usage.Normal).toLong()
        val builder = ModelBuilder()
        builder.begin()
        val part = builder.part("no-shadow", GL20.GL_TRIANGLES, attrs, material)
        part.rect(
            Vector3(-0.01f, 0f, 0.01f), Vector3(0.01f, 0f, 0.01f),
            Vector3(0.01f, 0f, -0.01f), Vector3(-0.01f, 0f, -0.01f),
            Vector3(0f, 1f, 0f),
        )
        return builder.end()
    }

    fun dispose() {
        cachedModel?.dispose()
        cachedModel = null
    }
}
