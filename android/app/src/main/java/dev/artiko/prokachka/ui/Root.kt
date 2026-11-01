package dev.artiko.prokachka.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.artiko.prokachka.core.Assessment
import dev.artiko.prokachka.core.Assessor
import dev.artiko.prokachka.core.AssessHint
import dev.artiko.prokachka.core.Entry
import dev.artiko.prokachka.core.Event
import dev.artiko.prokachka.core.Fmt
import dev.artiko.prokachka.core.Skill
import dev.artiko.prokachka.data.EventStore
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

enum class Tab(val title: String, val icon: String) {
    TODAY("Сегодня", "sun"), SKILLS("Навыки", "star"), QUESTS("Квесты", "target"),
    ACHIEVEMENTS("Достижения", "trophy"), REWARDS("Награды", "gift"),
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ProkachkaRoot(store: EventStore) {
    val s by store.snapshot.collectAsStateWithLifecycle()
    val rewards by store.rewards.collectAsStateWithLifecycle()
    val lastAdded by store.lastAdded.collectAsStateWithLifecycle()
    var tab by rememberSaveable { mutableStateOf(Tab.TODAY) }
    var journal by rememberSaveable { mutableStateOf(false) }
    var openId by rememberSaveable { mutableStateOf<String?>(null) }
    val list = rememberLazyListState()
    val open = openId?.let { id -> s.entries.firstOrNull { it.id == id } }

    BackHandler(enabled = open != null || journal) { if (open != null) openId = null else journal = false }

    Box(Modifier.fillMaxSize().background(P.background)) {
        LazyColumn(
            state = list,
            modifier = Modifier.fillMaxSize().statusBarsPadding(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 200.dp),
        ) {
            when {
                tab == Tab.TODAY && journal -> journalScreen(s, back = { journal = false }) { openId = it.id }
                tab == Tab.TODAY -> todayScreen(s, lastAdded, openJournal = { journal = true }) { openId = it.id }
                tab == Tab.SKILLS -> skillsScreen(s)
                tab == Tab.QUESTS -> questsScreen(s)
                tab == Tab.ACHIEVEMENTS -> achievementsScreen(s)
                tab == Tab.REWARDS -> rewardsScreen(s, rewards, store)
            }
        }
        // Полоса под строкой состояния, чтобы список не просвечивал под часами.
        Box(Modifier.fillMaxWidth().windowInsetsTopHeight(WindowInsets.statusBars).background(P.background))

        Column(
            Modifier.align(Alignment.BottomCenter).fillMaxWidth().navigationBarsPadding().imePadding().padding(horizontal = 12.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Composer(store)
            // Как в iOS: пока открыта клавиатура, панели вкладок нет.
            if (!WindowInsets.isImeVisible) TabBar(tab) { tab = it; journal = false }
        }

        Banners(store, Modifier.align(Alignment.TopCenter).statusBarsPadding().padding(horizontal = 10.dp, vertical = 6.dp))
        EntrySheet(open, store) { openId = null }
        LevelUpSheet(store)
        Problem(store)
    }
}

@Composable
private fun TabBar(current: Tab, onSelect: (Tab) -> Unit) {
    Row(
        Modifier.fillMaxWidth().shadow(14.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.2f)).clip(CircleShape).background(P.bar).padding(4.dp),
    ) {
        Tab.entries.forEach { t ->
            val on = t == current
            Column(
                Modifier.weight(1f).clip(CircleShape).background(if (on) P.fill else Color.Transparent)
                    .clickable(remember { MutableInteractionSource() }, indication = null) { onSelect(t) }.padding(vertical = 6.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Ico(t.icon, if (on) P.accent else P.label, 21.dp)
                Txt(t.title, size = Type.caption * 0.85f, weight = FontWeight.Medium, color = if (on) P.accent else P.label, maxLines = 1)
            }
        }
    }
}

/** Поле «Что сделал?» с оценкой до отправки. То же самое — в панели быстрой записи. */
@Composable
fun Composer(store: EventStore, autofocus: Boolean = false, onSubmitted: (Assessment) -> Unit = {}) {
    val s by store.snapshot.collectAsStateWithLifecycle()
    var text by rememberSaveable { mutableStateOf("") }
    var override by remember { mutableStateOf<Skill?>(null) }
    var flash by remember { mutableStateOf<Int?>(null) }
    val scope = rememberCoroutineScope()
    val focus = remember { FocusRequester() }
    val a = remember(text, override, s) { store.preview(text, override) }

    fun submit() {
        val added = store.add(text, override) ?: return
        text = ""
        override = null
        flash = added.xp
        scope.launch { delay(1300); flash = null }
        onSubmitted(added)
    }

    LaunchedEffect(Unit) { if (autofocus) focus.requestFocus() }

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        AnimatedVisibility(flash != null, enter = fadeIn() + slideInVertically { it / 2 }, exit = fadeOut() + slideOutVertically { -it }) {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { flash?.let { XP(it, Type.title) } }
        }
        if (text.isNotBlank()) {
            Box(Modifier.fillMaxWidth().shadow(8.dp, RoundedCornerShape(16.dp)).clip(RoundedCornerShape(16.dp)).background(P.bar).padding(10.dp)) {
                AssessmentPreview(a, Assessor.hint(text) == AssessHint.PLAN, true, compact = true) { override = it }
            }
        }
        Row(
            Modifier.fillMaxWidth().shadow(14.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.2f)).clip(CircleShape).background(P.bar)
                .padding(start = 18.dp, end = 5.dp, top = 5.dp, bottom = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BasicTextField(
                value = text,
                onValueChange = { text = it; if (it.isBlank()) override = null },
                modifier = Modifier.weight(1f).focusRequester(focus),
                singleLine = true,
                textStyle = TextStyle(fontSize = Type.body, color = P.label),
                cursorBrush = SolidColor(P.accent),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { submit() }),
                decorationBox = { inner -> Box { if (text.isEmpty()) Txt("Что сделал?", color = P.label3); inner() } },
            )
            Box(
                Modifier.size(36.dp).clip(CircleShape).background(if (a != null) P.accent else P.fill).clickable(enabled = a != null) { submit() },
                contentAlignment = Alignment.Center,
            ) { Ico("up", if (a != null) Color.White else P.label3, 19.dp) }
        }
    }
}

@Composable
private fun Banners(store: EventStore, modifier: Modifier) {
    val banners by store.banners.collectAsStateWithLifecycle()
    Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        banners.forEach { b ->
            Row(
                Modifier.fillMaxWidth().shadow(10.dp, RoundedCornerShape(20.dp)).clip(RoundedCornerShape(20.dp)).background(P.bar)
                    .clickable { store.dismiss(b) }.padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconSquare("bolt", P.accent, 30.dp)
                HSpace(10.dp)
                Column {
                    Txt(b.title, size = Type.subhead, weight = FontWeight.SemiBold)
                    Txt(b.body, size = Type.footnote, color = P.label2, maxLines = 2)
                }
            }
        }
    }
}

/** Разбор оценки и правка: «Мало», «Много», «Удалить». */
@Composable
private fun EntrySheet(entry: Entry?, store: EventStore, close: () -> Unit) {
    AnimatedVisibility(entry != null, enter = fadeIn(), exit = fadeOut()) {
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.35f)).clickable(remember { MutableInteractionSource() }, null, onClick = close))
    }
    AnimatedVisibility(entry != null, enter = slideInVertically { it }, exit = slideOutVertically { it }, modifier = Modifier.fillMaxSize()) {
        val e = entry ?: return@AnimatedVisibility
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(topStart = 26.dp, topEnd = 26.dp)).background(P.background)
                    .clickable(remember { MutableInteractionSource() }, null) {}.navigationBarsPadding().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(Modifier.align(Alignment.CenterHorizontally).size(36.dp, 5.dp).clip(CircleShape).background(P.label3))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SkillIcon(e.skill, 34.dp)
                    HSpace(12.dp)
                    Txt(e.text, size = Type.headline, weight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                }
                Column(Modifier.clip(RoundedCornerShape(16.dp)).background(P.cell)) {
                    e.steps.forEachIndexed { i, st ->
                        if (i > 0) Separator(14.dp)
                        Row(Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
                            Txt(st.name, color = P.label2, modifier = Modifier.weight(1f))
                            Txt(st.`val`, tabular = true)
                        }
                    }
                    Separator(14.dp)
                    Row(Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
                        Txt("Итого", weight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                        XP(e.xp)
                    }
                }
                if (!e.isQuest) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (e.xp > 0) {
                            SheetButton("Мало", "up", P.accent, Modifier.weight(1f)) { store.tune(e, Event.Tune.UP); close() }
                            SheetButton("Много", "down", P.accent, Modifier.weight(1f)) { store.tune(e, Event.Tune.DOWN); close() }
                        } else {
                            SheetButton("Слишком строго", "up", P.accent, Modifier.weight(2f)) { store.tune(e, Event.Tune.SOFT); close() }
                        }
                        SheetButton("Удалить", "trash", P.minus, Modifier.weight(1f)) { store.delete(e); close() }
                    }
                    Txt("«Мало» и «Много» запоминаются: следующие дела этого навыка будут оцениваться иначе.", size = Type.footnote, color = P.label2)
                }
            }
        }
    }
}

@Composable
private fun SheetButton(label: String, icon: String, tint: Color, modifier: Modifier, onClick: () -> Unit) {
    Row(
        modifier.clip(RoundedCornerShape(14.dp)).background(P.cell).clickable(onClick = onClick).padding(vertical = 13.dp),
        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
    ) {
        Ico(icon, tint, 17.dp)
        HSpace(6.dp)
        Txt(label, color = tint, weight = FontWeight.Medium, maxLines = 1)
    }
}

@Composable
private fun LevelUpSheet(store: EventStore) {
    val up by store.levelUp.collectAsStateWithLifecycle()
    val l = up ?: return
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.4f)).clickable { store.levelUp.value = null }, contentAlignment = Alignment.Center) {
        Column(
            Modifier.padding(32.dp).clip(RoundedCornerShape(28.dp)).background(P.cell).padding(28.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            LevelRing(1.0, l.level, 96.dp, 10.dp)
            Txt("Уровень ${l.level}", size = Type.title, weight = FontWeight.Bold)
            Txt("Звание: ${l.rank}. Дальше — ${dev.artiko.prokachka.core.Levels.req(l.level)} XP до следующего.", color = P.label2, align = TextAlign.Center)
            Spacer(Modifier.height(4.dp))
            Box(Modifier.clip(CircleShape).background(P.accent).clickable { store.levelUp.value = null }.padding(horizontal = 28.dp, vertical = 11.dp)) {
                Txt("Отлично", color = Color.White, weight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun Problem(store: EventStore) {
    val p by store.problem.collectAsStateWithLifecycle()
    val text = p ?: return
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.4f)), contentAlignment = Alignment.Center) {
        Column(Modifier.padding(32.dp).clip(RoundedCornerShape(22.dp)).background(P.cell).padding(22.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Txt("Проблема с данными", size = Type.headline, weight = FontWeight.SemiBold)
            Txt(text, color = P.label2)
            Txt("Понятно", color = P.accent, weight = FontWeight.SemiBold, modifier = Modifier.align(Alignment.End).clickable { store.problem.value = null }.padding(6.dp))
        }
    }
}

