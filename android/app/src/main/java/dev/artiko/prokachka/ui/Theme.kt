package dev.artiko.prokachka.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import dev.artiko.prokachka.core.Skill

/** Системные цвета iOS: интерфейс в языке Apple, как на Mac. */
data class Palette(
    val dark: Boolean,
    val background: Color,
    val cell: Color,
    val label: Color,
    val label2: Color,
    val label3: Color,
    val separator: Color,
    val fill: Color,
    val accent: Color,
    val plus: Color,
    val minus: Color,
    val bar: Color,
    val pink: Color,
    val indigo: Color,
    val blue: Color,
    val teal: Color,
    val green: Color,
    val purple: Color,
    val mint: Color,
    val gray: Color,
    val orange: Color,
) {
    fun skill(s: Skill): Color = when (s) {
        Skill.BODY -> pink
        Skill.MIND -> indigo
        Skill.WORK -> blue
        Skill.HOME -> teal
        Skill.PEOPLE -> green
        Skill.CRAFT -> purple
        Skill.REST -> mint
        Skill.MISC -> gray
        Skill.QUEST -> orange
    }
}

private val Light = Palette(
    dark = false, background = Color(0xFFF2F2F7), cell = Color.White, label = Color.Black,
    label2 = Color(0x993C3C43), label3 = Color(0x4D3C3C43), separator = Color(0x2E3C3C43), fill = Color(0x1F787880),
    accent = Color(0xFF007AFF), plus = Color(0xFF248A3D), minus = Color(0xFFD70015), bar = Color(0xFAFBFBFD),
    pink = Color(0xFFFF2D55), indigo = Color(0xFF5856D6), blue = Color(0xFF007AFF), teal = Color(0xFF30B0C7),
    green = Color(0xFF34C759), purple = Color(0xFFAF52DE), mint = Color(0xFF00C7BE), gray = Color(0xFF8E8E93), orange = Color(0xFFFF9500),
)

private val Dark = Palette(
    dark = true, background = Color.Black, cell = Color(0xFF1C1C1E), label = Color.White,
    label2 = Color(0x99EBEBF5), label3 = Color(0x4DEBEBF5), separator = Color(0x99545458), fill = Color(0x3D787880),
    accent = Color(0xFF0A84FF), plus = Color(0xFF30D158), minus = Color(0xFFFF453A), bar = Color(0xFA232325),
    pink = Color(0xFFFF375F), indigo = Color(0xFF5E5CE6), blue = Color(0xFF0A84FF), teal = Color(0xFF40C8E0),
    green = Color(0xFF30D158), purple = Color(0xFFBF5AF2), mint = Color(0xFF63E6E2), gray = Color(0xFF98989D), orange = Color(0xFFFF9F0A),
)

val LocalPalette = staticCompositionLocalOf { Light }

val P: Palette @Composable get() = LocalPalette.current

@Composable
fun ProkachkaTheme(content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalPalette provides if (isSystemInDarkTheme()) Dark else Light, content = content)
}

/** Размеры шрифта по шкале iOS. */
object Type {
    val largeTitle = 32.sp
    val title = 22.sp
    val headline = 17.sp
    val body = 16.sp
    val subhead = 15.sp
    val footnote = 13.sp
    val caption = 12.sp
}

@Composable
fun Txt(
    text: String,
    modifier: Modifier = Modifier,
    size: TextUnit = Type.body,
    weight: FontWeight = FontWeight.Normal,
    color: Color = P.label,
    maxLines: Int = Int.MAX_VALUE,
    align: TextAlign? = null,
    tabular: Boolean = false,
) {
    BasicText(
        text = text,
        modifier = modifier,
        style = TextStyle(
            fontSize = size, fontWeight = weight, color = color, textAlign = align ?: TextAlign.Unspecified,
            fontFeatureSettings = if (tabular) "tnum" else null, letterSpacing = if (size >= Type.title) (-0.4).sp else TextUnit.Unspecified,
        ),
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis,
    )
}
