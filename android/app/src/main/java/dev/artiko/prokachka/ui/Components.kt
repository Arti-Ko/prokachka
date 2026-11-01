package dev.artiko.prokachka.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.artiko.prokachka.core.Assessment
import dev.artiko.prokachka.core.Fmt
import dev.artiko.prokachka.core.Skill
import dev.artiko.prokachka.core.Step

/** Цветной квадрат с символом, как иконки в настройках iOS. */
@Composable
fun IconSquare(icon: String, color: Color, size: Dp = 28.dp) {
    Box(
        Modifier.size(size).clip(RoundedCornerShape(size * 0.27f))
            .background(Brush.verticalGradient(listOf(color.copy(alpha = 0.85f), color))),
        contentAlignment = Alignment.Center,
    ) { Ico(icon, Color.White, size * 0.62f) }
}

@Composable
fun SkillIcon(skill: Skill, size: Dp = 28.dp) = IconSquare(Icons.skill(skill), P.skill(skill), size)

@Composable
fun LevelRing(progress: Double, level: Int, size: Dp = 72.dp, line: Dp = 7.dp) {
    val p by animateFloatAsState(progress.toFloat().coerceIn(0f, 1f), label = "ring")
    val track = P.fill
    val accent = P.accent
    Box(Modifier.size(size), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(size)) {
            val w = line.toPx()
            val inset = w / 2
            val arcSize = androidx.compose.ui.geometry.Size(this.size.width - w, this.size.height - w)
            drawArc(track, 0f, 360f, false, Offset(inset, inset), arcSize, style = Stroke(w))
            if (p > 0.001f) drawArc(accent, -90f, 360f * p, false, Offset(inset, inset), arcSize, style = Stroke(w, cap = StrokeCap.Round))
        }
        Txt("$level", size = (size.value * 0.34f).sp, weight = FontWeight.Bold, tabular = true)
    }
}

@Composable
fun Bar(progress: Double, color: Color = P.accent, height: Dp = 6.dp, modifier: Modifier = Modifier) {
    val p by animateFloatAsState(progress.toFloat().coerceIn(0f, 1f), label = "bar")
    Box(modifier.fillMaxWidth().height(height).clip(CircleShape).background(P.fill)) {
        Box(Modifier.fillMaxWidth(p).height(height).clip(CircleShape).background(color))
    }
}

/** Секция в духе «Настроек»: заголовок над скруглённой карточкой. */
@Composable
fun Group(title: String? = null, trailing: String? = null, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth()) {
        if (title != null) {
            Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, bottom = 6.dp, top = 18.dp)) {
                Txt(title.uppercase(), size = Type.footnote, color = P.label2, modifier = Modifier.weight(1f))
                if (trailing != null) Txt(trailing, size = Type.footnote, color = P.label2, tabular = true)
            }
        } else {
            Spacer(Modifier.height(14.dp))
        }
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(P.cell), content = content)
        if (footer != null) Txt(footer, size = Type.footnote, color = P.label2, modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp))
    }
}

/** Разделитель внутри группы с отступом под иконку. */
@Composable
fun Separator(inset: Dp = 56.dp) {
    Box(Modifier.padding(start = inset).fillMaxWidth().height(0.5.dp).background(P.separator))
}

@Composable
fun Pressable(onClick: (() -> Unit)?, content: @Composable () -> Unit) {
    if (onClick == null) {
        content()
        return
    }
    Box(Modifier.clickable(remember { MutableInteractionSource() }, indication = androidx.compose.foundation.LocalIndication.current, onClick = onClick)) { content() }
}

@Composable
fun XP(xp: Int, size: androidx.compose.ui.unit.TextUnit = Type.body) {
    Txt(Fmt.signed(xp), size = size, weight = FontWeight.SemiBold, color = if (xp < 0) P.minus else P.plus, tabular = true)
}

@Composable
fun Chip(text: String, icon: String? = null, tint: Color = P.label2) {
    Row(
        Modifier.clip(CircleShape).background(P.fill).padding(horizontal = 9.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        if (icon != null) Ico(icon, tint, 13.dp)
        Txt(text, size = Type.caption, color = P.label, tabular = true)
    }
}

@Composable
fun FactorChip(step: Step) {
    Row(Modifier.clip(RoundedCornerShape(7.dp)).background(P.fill).padding(horizontal = 7.dp, vertical = 2.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Txt(step.name, size = Type.caption, color = P.label2)
        Txt(step.`val`, size = Type.caption, weight = FontWeight.SemiBold, tabular = true)
    }
}

/** Оценка до отправки: опыт, навык, множители; если навык не распознан — кнопки выбора. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AssessmentPreview(a: Assessment?, isPlan: Boolean, hasText: Boolean, compact: Boolean, onPick: (Skill) -> Unit) {
    when {
        a != null -> FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Txt("${Fmt.signed(a.xp)} XP", size = Type.subhead, weight = FontWeight.Bold, color = if (a.xp < 0) P.minus else P.plus, tabular = true)
            Chip(a.skill.title, Icons.skill(a.skill), P.skill(a.skill))
            val facs = a.steps.drop(1)
            (if (compact) facs.take(2) else facs).forEach { FactorChip(it) }
            if (compact && facs.size > 2) Txt("и ещё ${facs.size - 2}", size = Type.caption, color = P.label3)
            if (!a.sure) {
                Txt("Какой это навык?", size = Type.caption, color = P.label2)
                Skill.trained.forEach { s ->
                    Box(Modifier.clip(CircleShape).background(P.skill(s).copy(alpha = 0.15f)).clickable { onPick(s) }.padding(horizontal = 10.dp, vertical = 4.dp)) {
                        Txt(s.title, size = Type.caption, weight = FontWeight.Medium, color = P.skill(s))
                    }
                }
            }
        }
        isPlan -> Txt("Похоже на план. Запиши, когда сделаешь — тогда и будет опыт.", size = Type.caption, color = P.label2)
        hasText -> Txt("Опиши чуть подробнее: что сделал и сколько", size = Type.caption, color = P.label2)
    }
}

/** Медаль достижения по редкости: бронза, серебро, золото, платина. */
fun tierColor(tier: Int): Color = when (tier) {
    1 -> Color(0xFFC7804A)
    2 -> Color(0xFF8C99AD)
    3 -> Color(0xFFF2B21A)
    else -> Color(0xFF738CF2)
}

fun tierName(tier: Int): String = listOf("Бронза", "Серебро", "Золото", "Платина")[(tier - 1).coerceIn(0, 3)]

@Composable
fun Medal(icon: String, color: Color?, size: Dp = 52.dp) {
    Box(
        Modifier.size(size).clip(CircleShape).background(
            if (color != null) Brush.radialGradient(listOf(color.copy(alpha = 0.75f), color)) else Brush.linearGradient(listOf(P.fill, P.fill)),
        ),
        contentAlignment = Alignment.Center,
    ) { Ico(icon, if (color != null) Color.White else P.label3, size * 0.46f) }
}

@Composable
fun Centered(text: String) {
    Txt(text, color = P.label2, size = Type.subhead, align = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(20.dp))
}

@Composable
fun HSpace(w: Dp) = Spacer(Modifier.width(w))
