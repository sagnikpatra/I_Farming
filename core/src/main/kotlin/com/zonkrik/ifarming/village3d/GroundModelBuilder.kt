package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.graphics.GL20
import com.badlogic.gdx.graphics.VertexAttributes.Usage
import com.badlogic.gdx.graphics.g3d.Material
import com.badlogic.gdx.graphics.g3d.Model
import com.badlogic.gdx.graphics.g3d.attributes.ColorAttribute
import com.badlogic.gdx.graphics.g3d.utils.ModelBuilder
import com.badlogic.gdx.math.Vector3
import com.zonkrik.ifarming.village.GroundKind

/** Builds (and caches, one per [GroundKind]) a flat colored ground quad -- the 3D board's replacement for the 2D board's isometric diamond tile textures. */
object GroundModelBuilder {
    private val builder = ModelBuilder()
    private val cache = mutableMapOf<GroundKind, Model>()

    fun get(kind: GroundKind): Model = cache.getOrPut(kind) { build(kind) }

    private fun build(kind: GroundKind): Model {
        val material = Material(ColorAttribute.createDiffuse(kind.top))
        val attrs = (Usage.Position or Usage.Normal).toLong()
        builder.begin()
        val part = builder.part("ground", GL20.GL_TRIANGLES, attrs, material)
        // Slightly smaller than a full tile so adjacent tiles show a thin grid-line gap.
        val half = TILE_SPACING / 2f * 0.94f
        part.rect(
            Vector3(-half, 0f, half), Vector3(half, 0f, half),
            Vector3(half, 0f, -half), Vector3(-half, 0f, -half),
            Vector3(0f, 1f, 0f),
        )
        return builder.end()
    }

    fun disposeAll() {
        cache.values.forEach { it.dispose() }
        cache.clear()
    }
}
