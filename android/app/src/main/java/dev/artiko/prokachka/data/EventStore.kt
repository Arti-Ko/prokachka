package dev.artiko.prokachka.data

import android.content.Context
import dev.artiko.prokachka.core.Assessment
import dev.artiko.prokachka.core.DayClock
import dev.artiko.prokachka.core.Entry
import dev.artiko.prokachka.core.Event
import dev.artiko.prokachka.core.Fmt
import dev.artiko.prokachka.core.Ledger
import dev.artiko.prokachka.core.Skill
import dev.artiko.prokachka.core.Snapshot
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.util.UUID

/** Уведомление внутри приложения: квест, достижение, рост навыка. */
data class Banner(val title: String, val body: String, val id: String = UUID.randomUUID().toString())

data class LevelUp(val level: Int, val rank: String)

/** Награда из своего магазина. Каталог — настройка, а не журнал. */
@Serializable
data class Reward(val id: String = UUID.randomUUID().toString(), val title: String, val cost: Int, val icon: String)

/**
 * Журнал событий на диске и снимок, выведенный из него. events.jsonl только дописывается
 * и по формату совпадает с Mac — его же будет сливать синхронизация.
 */
class EventStore(context: Context) {
    private val dir: File = context.filesDir
    private val eventsFile = File(dir, "events.jsonl")
    private val rewardsFile = File(dir, "rewards.json")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

    val clock = DayClock()
    val deviceId: String = context.getSharedPreferences("prokachka", Context.MODE_PRIVATE).let { prefs ->
        prefs.getString("deviceId", null) ?: ("phone-" + UUID.randomUUID().toString().take(8)).also {
            prefs.edit().putString("deviceId", it).apply()
        }
    }

    private var events: List<Event> = emptyList()
    private val _snapshot = MutableStateFlow(Ledger.snapshot(emptyList(), today(), clock))
    val snapshot: StateFlow<Snapshot> = _snapshot.asStateFlow()
    private val _rewards = MutableStateFlow(DEFAULT_REWARDS)
    val rewards: StateFlow<List<Reward>> = _rewards.asStateFlow()
    private val _banners = MutableStateFlow<List<Banner>>(emptyList())
    val banners: StateFlow<List<Banner>> = _banners.asStateFlow()
    val levelUp = MutableStateFlow<LevelUp?>(null)
    /** Последняя ошибка чтения или записи — показывается на экране, а не теряется. */
    val problem = MutableStateFlow<String?>(null)
    /** Последнее добавленное дело: подсветить строку. */
    val lastAdded = MutableStateFlow<String?>(null)
    private val _changes = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    /** Журнал изменился на этом устройстве — пора синхронизироваться. */
    val changes: SharedFlow<Unit> = _changes

    val allEvents: List<Event> get() = events

    /** Принять события с другого устройства: только новые id, журнал по-прежнему только дописывается. */
    fun importEvents(incoming: List<Event>, from: String): Int {
        val known = events.map { it.id }.toMutableSet()
        val fresh = incoming.filter { known.add(it.id) }
        if (fresh.isEmpty()) return 0
        val before = _snapshot.value
        if (!append(fresh)) return 0
        // Вместе дела двух устройств могли закрыть квест: награда с тем же id, дубля не будет.
        val due = _snapshot.value.dueQuestEvents(System.currentTimeMillis(), deviceId)
        if (due.isNotEmpty()) append(due)
        val acts = fresh.filter { it.kind == Event.Kind.ACT }
        if (acts.isNotEmpty()) {
            val xp = acts.sumOf { it.xp ?: 0 }
            val last = acts.maxByOrNull { it.ts }?.text ?: ""
            post("С $from · ${acts.size} ${Fmt.plural(acts.size, "запись", "записи", "записей")}", "${Fmt.signed(xp)} XP · последняя: «$last»")
        }
        val after = _snapshot.value
        if (after.level.level > before.level.level) levelUp.value = LevelUp(after.level.level, after.rank)
        return fresh.size
    }

    init {
        load()
    }

    fun today(): String = clock.key(System.currentTimeMillis())

    /** В 04:00 начинается новый день: пересчитать стрик и квесты при возвращении в приложение. */
    fun refreshDay() {
        if (_snapshot.value.today != today()) recompute()
    }

    fun preview(text: String, override: Skill?): Assessment? =
        dev.artiko.prokachka.core.Assessor.assess(text, _snapshot.value.context(override))

    /** Записать дело. Возвращает оценку, если текст удалось разобрать. */
    fun add(raw: String, override: Skill? = null): Assessment? {
        refreshDay()
        val text = raw.trim()
        val a = preview(text, override) ?: return null
        val before = _snapshot.value
        val ts = System.currentTimeMillis()
        val act = Event.act(text, a, ts, today(), deviceId)
        if (!append(listOf(act))) return null
        val due = _snapshot.value.dueQuestEvents(ts + 1, deviceId)
        if (due.isNotEmpty()) append(due)
        lastAdded.value = act.id
        announce(before, due)
        _changes.tryEmit(Unit)
        return a
    }

    fun tune(entry: Entry, tune: Event.Tune) {
        val before = _snapshot.value.calibration[entry.skill]
        append(listOf(Event.edit(entry.id, tune, System.currentTimeMillis(), today(), deviceId)))
        val after = _snapshot.value.calibration[entry.skill]
        if (after != null && after != before) post("Учту на будущее", "«${entry.skill.title}» теперь оценивается ×${Fmt.k(after)}")
        _changes.tryEmit(Unit)
    }

    fun delete(entry: Entry) {
        append(listOf(Event.delete(entry.id, System.currentTimeMillis(), today(), deviceId)))
        _changes.tryEmit(Unit)
    }

    fun take(reward: Reward) {
        if (_snapshot.value.coins < reward.cost) return
        if (append(listOf(Event.spend(reward.title, reward.cost, System.currentTimeMillis(), today(), deviceId)))) {
            post("Награда твоя", "${reward.title} · −${reward.cost} монет")
            _changes.tryEmit(Unit)
        }
    }

    fun addReward(title: String, cost: Int) {
        val t = title.trim()
        if (t.isEmpty() || cost <= 0) return
        _rewards.update { it + Reward(title = t, cost = cost, icon = "gift") }
        saveRewards()
    }

    fun removeReward(reward: Reward) {
        _rewards.update { list -> list.filter { it.id != reward.id } }
        saveRewards()
    }

    fun dismiss(banner: Banner) = _banners.update { list -> list.filter { it.id != banner.id } }

    // ---------- журнал на диске ----------

    private fun load() {
        try {
            if (eventsFile.exists()) {
                var broken = 0
                events = eventsFile.readLines().filter { it.isNotBlank() }.mapNotNull { line ->
                    runCatching { json.decodeFromString<Event>(line) }.onFailure { broken++ }.getOrNull()
                }
                if (broken > 0) problem.value = "$broken ${Fmt.plural(broken, "строка", "строки", "строк")} журнала не прочитаны и пропущены."
            }
            if (rewardsFile.exists()) _rewards.value = json.decodeFromString(rewardsFile.readText())
        } catch (e: Exception) {
            problem.value = "Не удалось прочитать данные: ${e.message}"
        }
        recompute()
    }

    /** Сначала диск, потом память: если запись не удалась, экран не покажет несохранённое. */
    private fun append(new: List<Event>): Boolean = try {
        eventsFile.appendText(new.joinToString("") { json.encodeToString(Event.serializer(), it) + "\n" })
        events = events + new
        recompute()
        true
    } catch (e: Exception) {
        problem.value = "Не удалось сохранить запись: ${e.message}"
        false
    }

    private fun saveRewards() {
        try {
            rewardsFile.writeText(json.encodeToString(_rewards.value))
        } catch (e: Exception) {
            problem.value = "Не удалось сохранить награды: ${e.message}"
        }
    }

    private fun recompute() {
        _snapshot.value = Ledger.snapshot(events, today(), clock)
    }

    // ---------- оповещения ----------

    private fun announce(before: Snapshot, quests: List<Event>) {
        val after = _snapshot.value
        quests.forEach { post("Квест выполнен", "${it.text} · +${it.xp} XP") }
        val was = before.achievements.associate { it.id to it.done }
        after.achievements.filter { it.done && was[it.id] == false }
            .forEach { post("Новое достижение", "${it.def.title}: ${it.def.text.lowercase()}") }
        for (s in Skill.trained) {
            val l = after.skills[s]?.info?.level ?: 1
            if (l > (before.skills[s]?.info?.level ?: 1)) post("${s.title}: уровень $l", "Навык вырос")
        }
        if (after.level.level > before.level.level) levelUp.value = LevelUp(after.level.level, after.rank)
    }

    private fun post(title: String, body: String) {
        val b = Banner(title, body)
        _banners.update { (listOf(b) + it).take(3) }
        scope.launch {
            delay(4000)
            dismiss(b)
        }
    }

    private companion object {
        val DEFAULT_REWARDS = listOf(
            Reward(title = "Серия сериала без чувства вины", cost = 40, icon = "tv"),
            Reward(title = "Кофе в любимой кофейне", cost = 60, icon = "cup"),
            Reward(title = "Вечер игр", cost = 150, icon = "game"),
            Reward(title = "Выходной без планов", cost = 500, icon = "sun"),
            Reward(title = "Новая игра", cost = 900, icon = "gift"),
        )
    }
}
