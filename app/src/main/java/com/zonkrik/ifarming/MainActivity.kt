package com.zonkrik.ifarming

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import com.zonkrik.ifarming.game.GameViewModel
import com.zonkrik.ifarming.game.GameViewModelFactory
import com.zonkrik.ifarming.ui.FarmScreen
import com.zonkrik.ifarming.ui.theme.KisanKhetTheme

class MainActivity : ComponentActivity() {

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
}
