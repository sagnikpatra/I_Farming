package com.zonkrik.ifarming

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.fragment.app.FragmentActivity
import com.badlogic.gdx.backends.android.AndroidFragmentApplication
import com.zonkrik.ifarming.game.GameViewModel
import com.zonkrik.ifarming.game.GameViewModelFactory
import com.zonkrik.ifarming.ui.FarmScreen
import com.zonkrik.ifarming.ui.theme.KisanKhetTheme

/**
 * A [FragmentActivity] (rather than a plain `ComponentActivity`) so it can host the LibGDX village
 * view as a Fragment (see `ui/gdx/GdxVillageBoard.kt`) -- `setContent`/`by viewModels()` keep
 * working exactly as before since `FragmentActivity` is itself a `ComponentActivity`.
 */
class MainActivity : FragmentActivity(), AndroidFragmentApplication.Callbacks {

    private val viewModel: GameViewModel by viewModels {
        GameViewModelFactory(applicationContext)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            KisanKhetTheme {
                FarmScreen(viewModel = viewModel)
            }
        }
    }

    override fun exit() {}
}
