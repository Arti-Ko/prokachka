package dev.artiko.prokachka.ui

import androidx.compose.foundation.Image
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.size
import dev.artiko.prokachka.core.Skill

/** Иконки из макета (design/prototype.html): контурные пути 24×24, как SF Symbols. */
object Icons {
    private fun circle(cx: Float, cy: Float, r: Float) = "M${cx - r} ${cy}a$r $r 0 1 0 ${2 * r} 0a$r $r 0 1 0 ${-2 * r} 0"

    private val paths: Map<String, List<String>> = mapOf(
        "sun" to listOf(circle(12f, 12f, 4f), "M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"),
        "list" to listOf("M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01"),
        "star" to listOf("M12 3.5l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.8l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z"),
        "target" to listOf(circle(12f, 12f, 8.5f), circle(12f, 12f, 5f), circle(12f, 12f, 1.4f)),
        "trophy" to listOf("M7 4h10v4.5a5 5 0 0 1-10 0zM7 6H4v1.5A3 3 0 0 0 7.3 10.4M17 6h3v1.5a3 3 0 0 1-3.3 2.9M12 13.5V17M8.5 20.5h7M9.5 17h5v3.5h-5z"),
        "gift" to listOf("M3.5 8h17v4h-17zM5 12v8h14v-8M12 8v12M12 8c-1-3-5-4.5-5.5-2S10 8 12 8zm0 0c1-3 5-4.5 5.5-2S14 8 12 8z"),
        "chart" to listOf("M5 20v-8M10 20V5M15 20v-6M20 20V9"),
        "plus" to listOf("M12 5v14M5 12h14"),
        "check" to listOf("M5 12.5l4.5 4.5L19 7.5"),
        "coin" to listOf(circle(12f, 12f, 8.5f), circle(12f, 12f, 5.2f)),
        "trash" to listOf("M4.5 7h15M9.5 7V4.5h5V7M6.5 7l1 13h9l1-13"),
        "up" to listOf("M12 19V5M6 11l6-6 6 6"),
        "down" to listOf("M12 5v14M6 13l6 6 6-6"),
        "flame" to listOf("M12 21c-3.9 0-6.5-2.6-6.5-6 0-3.2 2.2-5 3.6-7.4.5 1.8 1.4 2.9 2.6 3.4.3-3.5 1.8-6.4 3.8-8 .2 3.3 3.5 6 3.5 11 0 3.6-2.6 7-7 7z"),
        "bolt" to listOf("M13 2.5L5 13.5h6l-1 8 8-11h-6z"),
        "heart" to listOf("M12 20s-7.5-4.4-7.5-10.2A4.2 4.2 0 0 1 12 7.3a4.2 4.2 0 0 1 7.5 2.5C19.5 15.6 12 20 12 20z"),
        "book" to listOf("M3 5.5c2.5-1 5.5-1 9 1 3.5-2 6.5-2 9-1v13c-2.5-1-5.5-1-9 1-3.5-2-6.5-2-9-1zM12 6.5v13"),
        "briefcase" to listOf("M5.5 7h13a2.5 2.5 0 0 1 2.5 2.5v8a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17.5v-8A2.5 2.5 0 0 1 5.5 7zM9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7M3 12.5h18"),
        "house" to listOf("M4 11l8-7 8 7M6 9.5V20h12V9.5M10 20v-5h4v5"),
        "people" to listOf(circle(9f, 8f, 3f), "M3.5 19c.6-3 2.8-5 5.5-5s4.9 2 5.5 5", circle(17f, 9f, 2.4f), "M15.6 14.2c2.4-.2 4.4 1.4 5 4.3"),
        "pencil" to listOf("M4 20l1-4L15.5 5.5a2.1 2.1 0 0 1 3 3L8 19zM13.5 7.5l3 3"),
        "moon" to listOf("M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"),
        "sparkles" to listOf("M11 3l1.8 5.2L18 10l-5.2 1.8L11 17l-1.8-5.2L4 10l5.2-1.8zM18.5 15l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z"),
        "cup" to listOf("M5 8.5h11V14a5 5 0 0 1-5 5h-1a5 5 0 0 1-5-5zM16 10.5h1.5a2.5 2.5 0 0 1 0 5H16M8.5 3.5v2.5M12 3.5v2.5"),
        "tv" to listOf("M5 5h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2zM8.5 20.5h7"),
        "game" to listOf("M7 8h10a4 4 0 0 1 4 4.5l-.6 3.6a2.3 2.3 0 0 1-4 1L15 15.5H9l-1.4 1.6a2.3 2.3 0 0 1-4-1L3 12.5A4 4 0 0 1 7 8zM7.5 11v3M6 12.5h3"),
        "lock" to listOf("M7 10.5h10a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-6a2 2 0 0 1 2-2zM8 10.5V8a4 4 0 0 1 8 0v2.5"),
        "crown" to listOf("M4 18.5h16M4.5 15.5L3 7.5l5 4 4-6.5 4 6.5 5-4-1.5 8z"),
        "back" to listOf("M15 5l-7 7 7 7"),
        "chevron" to listOf("M9 5l7 7-7 7"),
        "question" to listOf("M9 9a3 3 0 1 1 4.5 2.6c-.9.5-1.5 1.2-1.5 2.2V15M12 18.5h.01"),
        "calendar" to listOf("M5 5.5h14a1.5 1.5 0 0 1 1.5 1.5v12a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 19V7A1.5 1.5 0 0 1 5 5.5zM3.5 10h17M8 3.5v4M16 3.5v4"),
        "shield" to listOf("M12 3l7.5 3v5.5c0 4.5-3.2 8-7.5 9.5-4.3-1.5-7.5-5-7.5-9.5V6z"),
    )

    private val cache = mutableMapOf<String, ImageVector>()

    fun get(name: String): ImageVector = cache.getOrPut(name) {
        val b = ImageVector.Builder(name, 24.dp, 24.dp, 24f, 24f)
        for (d in paths[name] ?: paths.getValue("sparkles")) {
            b.addPath(
                pathData = addPathNodes(d), fill = null, stroke = SolidColor(Color.Black), strokeLineWidth = 1.8f,
                strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round,
            )
        }
        b.build()
    }

    fun skill(s: Skill): String = when (s) {
        Skill.BODY -> "heart"
        Skill.MIND -> "book"
        Skill.WORK -> "briefcase"
        Skill.HOME -> "house"
        Skill.PEOPLE -> "people"
        Skill.CRAFT -> "pencil"
        Skill.REST -> "moon"
        Skill.MISC -> "sparkles"
        Skill.QUEST -> "target"
    }
}

@Composable
fun Ico(name: String, tint: Color, size: Dp = 20.dp, modifier: Modifier = Modifier) {
    Image(Icons.get(name), contentDescription = null, modifier = modifier.size(size), colorFilter = ColorFilter.tint(tint))
}
