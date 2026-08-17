package com.zonkrik.ifarming.ui.gdx

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import com.badlogic.gdx.backends.android.AndroidApplicationConfiguration
import com.badlogic.gdx.backends.android.AndroidFragmentApplication
import com.zonkrik.ifarming.preview3d.Preview3DGame

/**
 * Hosts [Preview3DGame]'s GL view as a Fragment -- same embedding pattern as [GdxVillageFragment],
 * kept as a separate class (rather than reusing that one) since it wraps a completely different
 * `ApplicationAdapter` with no relation to the production village board.
 */
class Preview3DFragment : AndroidFragmentApplication() {

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val config = AndroidApplicationConfiguration().apply {
            useAccelerometer = false
            useCompass = false
            // The model has real depth (a fountain basin) -- a depth buffer is required for faces
            // to occlude each other correctly, unlike the 2D board which never needed one.
            depth = 16
        }
        return initializeForView(Preview3DGame(), config)
    }
}
