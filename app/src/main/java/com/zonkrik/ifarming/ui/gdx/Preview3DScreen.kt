package com.zonkrik.ifarming.ui.gdx

import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentContainerView
import com.zonkrik.ifarming.ui.ChunkyTile
import com.zonkrik.ifarming.ui.theme.SoilBrownDark
import com.zonkrik.ifarming.ui.theme.WoodBrownLight

/**
 * Full-screen host for [Preview3DFragment] -- a "does the real 3D pipeline actually work on
 * device" sneak peek, reached from a "🧊 3D Preview" HUD button in `FarmScreen`. Deliberately not
 * wired into any GameState/ViewModel; it just proves `ModelBatch`/`ObjLoader`/lighting render a
 * bundled Kenney model correctly, ahead of the much larger (separately scoped) interaction rewrite
 * that swapping the production board over to 3D would need.
 */
@Composable
fun Preview3DScreen(onClose: () -> Unit, modifier: Modifier = Modifier) {
    val activity = LocalContext.current as FragmentActivity
    var fragment by remember { mutableStateOf<Preview3DFragment?>(null) }

    Box(modifier = modifier.fillMaxSize()) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { context ->
                FragmentContainerView(context).apply { id = View.generateViewId() }
            },
            update = { container ->
                val fragmentManager = activity.supportFragmentManager
                val existing = fragmentManager.findFragmentById(container.id) as? Preview3DFragment
                fragment = existing ?: Preview3DFragment().also {
                    fragmentManager.beginTransaction().replace(container.id, it).commitNowAllowingStateLoss()
                }
            },
        )

        ChunkyTile(
            modifier = Modifier.align(Alignment.TopStart).padding(16.dp),
            topColor = WoodBrownLight,
            bottomColor = SoilBrownDark,
            cornerRadius = 12.dp,
            elevation = 4.dp,
            onClick = onClose,
        ) {
            Box(modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)) {
                Text("✕ Close preview", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp)
            }
        }
    }
}
