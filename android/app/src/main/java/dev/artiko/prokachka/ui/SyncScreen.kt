package dev.artiko.prokachka.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.artiko.prokachka.data.FoundMac
import dev.artiko.prokachka.data.SyncClient
import dev.artiko.prokachka.data.SyncState
import kotlinx.coroutines.launch
import java.text.DateFormat
import java.util.Date

/** «Mac · синхронизировано в 12:40» под датой на экране «Сегодня». */
fun syncLine(s: SyncState): String? = when {
    !s.paired -> null
    s.busy -> "${s.macName ?: "Mac"} · обмен…"
    s.status == "Синхронизировано" && s.lastSync != null ->
        "${s.macName ?: "Mac"} · синхронизировано в ${DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(s.lastSync))}"
    else -> "${s.macName ?: "Mac"} · ${s.status.lowercase()}"
}

fun LazyListScope.syncScreen(s: SyncState, client: SyncClient, back: () -> Unit) {
    item {
        Row(Modifier.clickable(onClick = back).padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Ico("back", P.accent, 22.dp)
            Txt("Сегодня", color = P.accent, size = Type.headline)
        }
        ScreenHeader("Mac", if (s.paired) "Записи сами ходят между Mac и телефоном" else "Подключите Mac в этой сети Wi‑Fi")
    }
    item { if (s.paired) PairedCard(s, client) else PairCard(s, client) }
}

@Composable
private fun PairedCard(s: SyncState, client: SyncClient) {
    val scope = rememberCoroutineScope()
    Group(footer = "Обмен идёт, пока приложение открыто и Mac в той же сети Wi‑Fi: каждые 20 секунд и сразу после записи. Данные шифруются общим ключом.") {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            IconSquare("laptop", P.blue, 34.dp)
            HSpace(12.dp)
            Column(Modifier.weight(1f)) {
                Txt(s.macName ?: "Mac", weight = FontWeight.SemiBold)
                Txt(syncLine(s)?.substringAfter(" · ") ?: s.status, size = Type.footnote, color = P.label2)
                if (s.error != null && s.status != "Синхронизировано") Txt(s.error, size = Type.caption, color = P.minus, maxLines = 3)
            }
        }
        Separator(14.dp)
        ActionRow("Синхронизировать сейчас", P.accent) { scope.launch { client.syncNow() } }
        Separator(14.dp)
        ActionRow("Отключить Mac", P.minus) { client.unpair() }
    }
}

@Composable
private fun PairCard(s: SyncState, client: SyncClient) {
    val scope = rememberCoroutineScope()
    var chosen by remember { mutableStateOf<FoundMac?>(null) }
    var code by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val target = chosen ?: s.found.singleOrNull()

    Column {
        Group("Mac в этой сети", footer = if (s.found.isEmpty()) "Ищу… На Mac должна быть открыта Прокачка, и оба устройства — в одной сети Wi‑Fi." else null) {
            if (s.found.isEmpty()) Centered("Пока никого не видно")
            s.found.forEachIndexed { i, mac ->
                if (i > 0) Separator()
                Row(Modifier.fillMaxWidth().clickable { chosen = mac }.padding(horizontal = 14.dp, vertical = 11.dp), verticalAlignment = Alignment.CenterVertically) {
                    IconSquare("laptop", P.blue)
                    HSpace(12.dp)
                    Txt(mac.name, modifier = Modifier.weight(1f))
                    if (mac == target) Ico("check", P.accent, 20.dp)
                }
            }
        }
        Group("Код с Mac", footer = "На Mac: Прокачка → «Синхронизация». Там шесть цифр, они действуют 5 минут.") {
            Box(Modifier.fillMaxWidth().padding(vertical = 14.dp), contentAlignment = Alignment.Center) {
                BasicTextField(
                    value = code,
                    onValueChange = { v -> code = v.filter(Char::isDigit).take(6); error = null },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                    textStyle = TextStyle(fontSize = 34.sp, fontWeight = FontWeight.Bold, color = P.label, textAlign = TextAlign.Center, letterSpacing = 6.sp),
                    cursorBrush = SolidColor(P.accent),
                    modifier = Modifier.fillMaxWidth(),
                    decorationBox = { inner -> Box(contentAlignment = Alignment.Center) { if (code.isEmpty()) Txt("000000", size = Type.largeTitle, color = P.label3); inner() } },
                )
            }
        }
        val can = target != null && code.length == 6 && !busy
        Box(
            Modifier.padding(top = 16.dp).fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(if (can) P.accent else P.fill)
                .clickable(enabled = can) {
                    busy = true
                    scope.launch {
                        error = client.pair(target!!, code)
                        busy = false
                    }
                }
                .padding(vertical = 14.dp),
            contentAlignment = Alignment.Center,
        ) { Txt(if (busy) "Подключаю…" else "Подключить", weight = FontWeight.SemiBold, color = if (can) Color.White else P.label3) }
        error?.let { Txt(it, color = P.minus, size = Type.footnote, modifier = Modifier.padding(top = 10.dp, start = 4.dp)) }
    }
}

@Composable
private fun ActionRow(label: String, tint: Color, onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 13.dp)) { Txt(label, color = tint) }
}

@Composable
fun SyncChip(line: String, onClick: () -> Unit) {
    Row(
        Modifier.padding(top = 6.dp).clip(CircleShape).clickable(onClick = onClick).padding(vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Ico("sync", P.label2, 14.dp)
        Txt(line, size = Type.footnote, color = P.label2, maxLines = 1)
    }
}
