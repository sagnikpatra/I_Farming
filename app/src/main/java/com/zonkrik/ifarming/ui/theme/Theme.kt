package com.zonkrik.ifarming.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = Saffron,
    onPrimary = Color.White,
    primaryContainer = SaffronDark,
    onPrimaryContainer = Color.White,
    secondary = FieldGreen,
    onSecondary = Color.White,
    secondaryContainer = FieldGreenLight,
    background = CreamBackground,
    onBackground = SoilBrownDark,
    surface = CreamSurface,
    onSurface = SoilBrownDark,
    error = DangerRed,
)

private val DarkColors = darkColorScheme(
    primary = Saffron,
    onPrimary = Color.Black,
    primaryContainer = SoilBrown,
    onPrimaryContainer = Color.White,
    secondary = FieldGreenLight,
    onSecondary = Color.Black,
    background = SoilBrownDark,
    onBackground = CreamBackground,
    surface = SoilBrown,
    onSurface = CreamBackground,
    error = DangerRed,
)

@Composable
fun KisanKhetTheme(content: @Composable () -> Unit) {
    val colors = if (isSystemInDarkTheme()) DarkColors else LightColors
    MaterialTheme(colorScheme = colors, content = content)
}
