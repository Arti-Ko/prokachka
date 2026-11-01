package dev.artiko.prokachka.ui

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import dev.artiko.prokachka.core.AchievementState
import dev.artiko.prokachka.core.DayClock
import dev.artiko.prokachka.core.Entry
import dev.artiko.prokachka.core.Fmt
import dev.artiko.prokachka.core.QuestState
import dev.artiko.prokachka.core.Skill
import dev.artiko.prokachka.core.Snapshot
import dev.artiko.prokachka.data.EventStore
import dev.artiko.prokachka.data.Reward
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private val ru = Locale.forLanguageTag("ru")

fun dayTitle(day: String, today: String): String = when (day) {
    today -> "Сегодня"
    DayClock.shift(today, -1) -> "Вчера"
    else -> LocalDate.parse(day).format(DateTimeFormatter.ofPattern("EEEE, d MMMM", ru)).replaceFirstChar { it.uppercase() }
}

fun longToday(): String = LocalDate.now().format(DateTimeFormatter.ofPattern("EEEE, d MMMM", ru)).replaceFirstChar { it.uppercase() }

@Composable
fun ScreenHeader(title: String, subtitle: String?, trailing: (@Composable () -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().padding(start = 4.dp, end = 4.dp, top = 8.dp), verticalAlignment = Alignment.Bottom) {
        Column(Modifier.weight(1f)) {
            Txt(title, size = Type.largeTitle, weight = FontWeight.Bold)
            if (subtitle != null) Txt(subtitle, size = Type.subhead, color = P.label2)
        }
        trailing?.invoke()
    }
}

@Composable
fun HeaderButton(icon: String, label: String, onClick: () -> Unit) {
    Row(
        Modifier.clip(CircleShape).background(P.cell).clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Ico(icon, P.accent, 16.dp)
        Txt(label, size = Type.subhead, color = P.accent, weight = FontWeight.Medium)
    }
}

@Composable
fun EntryRow(e: Entry, today: String, highlighted: Boolean, showDay: Boolean = false, onClick: (() -> Unit)?) {
    Pressable(onClick) {
        Row(
            Modifier.fillMaxWidth().background(if (highlighted) P.accent.copy(alpha = 0.08f) else P.cell).padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SkillIcon(e.skill)
            HSpace(12.dp)
            Column(Modifier.weight(1f)) {
                Txt(e.text, maxLines = 1)
                val time = Instant.ofEpochMilli(e.ts).atZone(ZoneId.systemDefault()).toLocalTime().format(DateTimeFormatter.ofPattern("HH:mm"))
                val from = if (e.device.startsWith("mac")) "Mac" else "телефон"
                val meta = listOfNotNull(if (showDay) dayTitle(e.day, today) else null, time, e.skill.title, from, if (e.edited) "поправлено" else null)
                Txt(meta.joinToString(" · "), size = Type.caption, color = P.label2, maxLines = 1)
            }
            HSpace(8.dp)
            XP(e.xp)
        }
    }
}

@Composable
fun QuestRow(q: QuestState) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 11.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier.size(22.dp).clip(CircleShape).background(if (q.done) P.plus else P.fill),
            contentAlignment = Alignment.Center,
        ) { if (q.done) Ico("check", androidx.compose.ui.graphics.Color.White, 14.dp) }
        HSpace(12.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Txt(q.title)
            if (q.goal > 1 && !q.done) Bar(q.progress.toDouble() / q.goal, q.skill?.let { P.skill(it) } ?: P.accent, 4.dp)
        }
        HSpace(10.dp)
        Column(horizontalAlignment = Alignment.End) {
            Txt("+${q.xp} XP", size = Type.subhead, weight = FontWeight.Medium, tabular = true)
            Txt(if (q.done) "Готово" else "${q.progress} из ${q.goal}", size = Type.caption, color = P.label2, tabular = true)
        }
    }
}

@Composable
fun LevelCard(s: Snapshot) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(P.cell).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            LevelRing(s.level.progress, s.level.level)
            HSpace(14.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.Bottom) {
                    Txt("Уровень ${s.level.level}", size = Type.headline, weight = FontWeight.SemiBold)
                    Txt(" · ${s.rank}", size = Type.headline, color = P.label2)
                }
                Bar(s.level.progress)
                Txt("${s.level.into} из ${s.level.need} XP · до ${s.level.level + 1}-го ${s.level.need - s.level.into}", size = Type.caption, color = P.label2, tabular = true)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Chip("${Fmt.days(s.streak)} подряд", "flame", P.orange)
            Chip("${Fmt.signed(s.todayXP)} сегодня", "bolt", P.accent)
            Chip("${s.coins}", "coin", P.orange)
        }
    }
}

fun LazyListScope.todayScreen(s: Snapshot, lastAdded: String?, openJournal: () -> Unit, openEntry: (Entry) -> Unit) {
    item { ScreenHeader("Сегодня", longToday()) { HeaderButton("list", "Журнал", openJournal) } }
    item { Spacer(Modifier.height(14.dp)); LevelCard(s) }
    item {
        Group("Записи", "${Fmt.signed(s.todayXP)} XP") {
            if (s.todayEntries.isEmpty()) Centered("Пока пусто. Напиши внизу, что сделал, — даже мелочь считается.")
            s.todayEntries.forEachIndexed { i, e ->
                if (i > 0) Separator()
                EntryRow(e, s.today, e.id == lastAdded) { openEntry(e) }
            }
        }
    }
    item {
        Group("Квесты дня") {
            s.quests.filter { it.period == QuestState.Period.DAY }.forEachIndexed { i, q ->
                if (i > 0) Separator(50.dp)
                QuestRow(q)
            }
        }
    }
}

fun LazyListScope.journalScreen(s: Snapshot, back: () -> Unit, openEntry: (Entry) -> Unit) {
    item {
        Row(Modifier.clickable(onClick = back).padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Ico("back", P.accent, 22.dp)
            Txt("Сегодня", color = P.accent, size = Type.headline)
        }
        ScreenHeader("Журнал", "Все дела по дням")
    }
    val days = s.entries.map { it.day }.distinct().sortedDescending()
    if (days.isEmpty()) item { Group { Centered("Журнал пуст.") } }
    days.forEach { day ->
        item(key = day) {
            Group(dayTitle(day, s.today), "${Fmt.signed(s.dayTotals[day] ?: 0)} XP") {
                s.entries.filter { it.day == day }.reversed().forEachIndexed { i, e ->
                    if (i > 0) Separator()
                    EntryRow(e, s.today, false) { openEntry(e) }
                }
            }
        }
    }
}

fun LazyListScope.skillsScreen(s: Snapshot) {
    item { ScreenHeader("Навыки", "Уровень ${s.level.level} · ${s.rank}") }
    item {
        Group(footer = "Квесты подбираются под два навыка, которые растут медленнее остальных.") {
            Skill.trained.forEachIndexed { i, k ->
                if (i > 0) Separator()
                val st = s.skills[k]!!
                Row(Modifier.padding(horizontal = 14.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                    SkillIcon(k)
                    HSpace(12.dp)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Row {
                            Txt(k.title, weight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                            Txt("ур. ${st.info.level}", size = Type.subhead, weight = FontWeight.SemiBold, color = P.label2, tabular = true)
                        }
                        Bar(st.info.progress, P.skill(k), 5.dp)
                        val cal = s.calibration[k]?.let { " · калибровка ×${Fmt.k(it)}" } ?: ""
                        Txt("${st.info.into} из ${st.info.need} · всего ${st.total}$cal", size = Type.caption, color = P.label2, tabular = true)
                    }
                }
            }
        }
    }
}

fun LazyListScope.questsScreen(s: Snapshot) {
    item { ScreenHeader("Квесты", "${s.quests.count { !it.done }} в работе") }
    item {
        Group("На сегодня") {
            s.quests.filter { it.period == QuestState.Period.DAY }.forEachIndexed { i, q -> if (i > 0) Separator(50.dp); QuestRow(q) }
        }
    }
    item {
        Group("На неделю", footer = "Награда начисляется сама. Набор подбирается под отстающие навыки и не меняется до конца дня или недели.") {
            s.quests.filter { it.period == QuestState.Period.WEEK }.forEachIndexed { i, q -> if (i > 0) Separator(50.dp); QuestRow(q) }
        }
    }
}

fun achievementIcon(metric: String): String = when {
    metric.startsWith("skill") -> Skill.of(metric.substringAfter('.'))?.let { Icons.skill(it) } ?: "star"
    metric == "level" -> "crown"
    metric in setOf("xpTotal", "xpDayBest", "bigAct") -> "bolt"
    metric in setOf("streakBest", "daysActive") -> "flame"
    metric in setOf("cleanBest", "abstains", "minuses") -> "shield"
    metric == "weekends" -> "calendar"
    metric == "km" -> "heart"
    metric == "pages" -> "book"
    metric == "questsDone" -> "target"
    metric in setOf("hard", "records") -> "trophy"
    metric in setOf("early", "night") -> "sun"
    metric in setOf("rewardsTaken", "spentTotal") -> "gift"
    else -> "star"
}

@Composable
fun AchievementCard(a: AchievementState, modifier: Modifier) {
    val secret = a.def.hidden && !a.done
    Column(
        modifier.clip(RoundedCornerShape(14.dp)).background(P.cell).padding(horizontal = 8.dp, vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Medal(if (a.done) achievementIcon(a.def.metric) else if (secret) "question" else "lock", if (a.done) tierColor(a.def.tier) else null)
        Txt(if (secret) "???" else a.def.title, size = Type.footnote, weight = FontWeight.SemiBold, align = TextAlign.Center, maxLines = 2)
        Txt(if (secret) "Секретное" else a.def.text, size = Type.caption, color = P.label2, align = TextAlign.Center, maxLines = 3)
        if (a.done) Txt(tierName(a.def.tier), size = Type.caption, weight = FontWeight.SemiBold, color = tierColor(a.def.tier))
        else if (!secret) {
            Bar(a.progress.toDouble() / a.def.goal, height = 4.dp)
            Txt("${a.progress} из ${a.def.goal}", size = Type.caption, color = P.label2, tabular = true)
        }
    }
}

fun LazyListScope.achievementsScreen(s: Snapshot) {
    val got = s.achievements.count { it.done }
    item {
        ScreenHeader("Достижения", "Получено $got из ${s.achievements.size}")
        Spacer(Modifier.height(10.dp))
        Bar(got.toDouble() / s.achievements.size)
    }
    s.achievements.groupBy { it.def.group }.forEach { (group, items) ->
        item(key = group) {
            Row(Modifier.fillMaxWidth().padding(start = 4.dp, top = 22.dp, bottom = 8.dp)) {
                Txt(group, size = Type.title, weight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Txt("${items.count { it.done }} из ${items.size}", size = Type.subhead, color = P.label2, tabular = true)
            }
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items.chunked(3).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { AchievementCard(it, Modifier.weight(1f)) }
                        repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
fun LazyListScope.rewardsScreen(s: Snapshot, rewards: List<Reward>, store: EventStore) {
    item { ScreenHeader("Награды", "${s.coins} ${Fmt.plural(s.coins, "монета", "монеты", "монет")} · 10% от каждого плюса") }
    item {
        Group("Магазин", footer = "Удалить награду — долгое нажатие.") {
            rewards.forEachIndexed { i, r ->
                if (i > 0) Separator()
                Row(
                    Modifier.fillMaxWidth().combinedClickable(onClick = {}, onLongClick = { store.removeReward(r) }).padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    IconSquare(r.icon, P.orange)
                    HSpace(12.dp)
                    Column(Modifier.weight(1f)) {
                        Txt(r.title, maxLines = 2)
                        Txt("${r.cost} монет", size = Type.caption, color = P.label2, tabular = true)
                    }
                    val can = s.coins >= r.cost
                    Box(
                        Modifier.clip(CircleShape).background(if (can) P.accent.copy(alpha = 0.14f) else P.fill)
                            .clickable(enabled = can) { store.take(r) }.padding(horizontal = 14.dp, vertical = 6.dp),
                    ) { Txt("Взять", size = Type.subhead, weight = FontWeight.SemiBold, color = if (can) P.accent else P.label3) }
                }
            }
        }
    }
    item { NewReward(store) }
    if (s.spends.isNotEmpty()) item {
        Group("Уже взято") {
            s.spends.reversed().forEachIndexed { i, e ->
                if (i > 0) Separator(14.dp)
                Row(Modifier.padding(horizontal = 14.dp, vertical = 11.dp)) {
                    Txt(e.text ?: "", modifier = Modifier.weight(1f), maxLines = 1)
                    Txt("−${e.cost}", color = P.label2, tabular = true)
                }
            }
        }
    }
}

@Composable
private fun NewReward(store: EventStore) {
    var title by rememberSaveable { mutableStateOf("") }
    var cost by rememberSaveable { mutableIntStateOf(100) }
    Group("Своя награда") {
        Box(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 12.dp)) {
            BasicTextField(
                title, { title = it }, singleLine = true, textStyle = TextStyle(fontSize = Type.body, color = P.label),
                cursorBrush = SolidColor(P.accent), modifier = Modifier.fillMaxWidth(),
                decorationBox = { inner -> Box { if (title.isEmpty()) Txt("Например, поход в кино", color = P.label3); inner() } },
            )
        }
        Separator(14.dp)
        Row(Modifier.padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Txt("Цена", modifier = Modifier.weight(1f))
            Stepper("−") { cost = (cost - 10).coerceAtLeast(10) }
            Txt("$cost", weight = FontWeight.SemiBold, tabular = true, modifier = Modifier.width(56.dp), align = TextAlign.Center)
            Stepper("+") { cost = (cost + 10).coerceAtMost(5000) }
        }
        Separator(14.dp)
        Box(
            Modifier.fillMaxWidth().clickable(enabled = title.isNotBlank()) { store.addReward(title, cost); title = "" }.padding(14.dp),
        ) { Txt("Добавить в магазин", color = if (title.isNotBlank()) P.accent else P.label3) }
    }
}

@Composable
private fun Stepper(sign: String, onClick: () -> Unit) {
    Box(Modifier.size(34.dp).clip(CircleShape).background(P.fill).clickable(onClick = onClick), contentAlignment = Alignment.Center) {
        Txt(sign, size = Type.headline, weight = FontWeight.SemiBold)
    }
}
