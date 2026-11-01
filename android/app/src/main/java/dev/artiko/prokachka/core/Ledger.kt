package dev.artiko.prokachka.core

import kotlin.math.max

/** Дело или награда за квест после применения правок и удалений. */
data class Entry(
    val id: String,
    val isQuest: Boolean,
    val text: String,
    val skill: Skill,
    val xp: Int,
    val steps: List<Step>,
    val ts: Long,
    val day: String,
    val device: String,
    val edited: Boolean,
)

data class SkillState(val total: Int) {
    val info: LevelInfo = Levels.skill(total)
}

/** Всё, что показывает интерфейс, выведено из журнала одной функцией. */
data class Snapshot(
    val today: String,
    /** Дела и квесты в хронологическом порядке. */
    val entries: List<Entry>,
    val total: Int,
    val level: LevelInfo,
    val skills: Map<Skill, SkillState>,
    val calibration: Map<Skill, Double>,
    val coins: Int,
    val spends: List<Event>,
    val streak: Int,
    val dayTotals: Map<String, Int>,
    val quests: List<QuestState>,
    val achievements: List<AchievementState>,
    val metrics: Map<String, Int>,
) {
    val rank: String get() = Levels.rank(level.level)
    val todayEntries: List<Entry> get() = entries.filter { it.day == today }.reversed()
    val todayXP: Int get() = dayTotals[today] ?: 0

    /** Контекст для оценки следующего дела. */
    fun context(override: Skill? = null): AssessContext {
        val acts = entries.filter { it.day == today && !it.isQuest }
            .map { DayAct(it.skill, it.xp, Assessor.prepare(it.text), it.steps.firstOrNull()?.name ?: "") }
        val lastTrained = mutableMapOf<Skill, Int>()
        var lastAny: String? = null
        for (e in entries) {
            if (e.isQuest || e.xp <= 0 || e.day >= today) continue
            if (lastAny == null || e.day > lastAny) lastAny = e.day
            val ago = DayClock.daysBetween(e.day, today)
            if (e.skill in Skill.trained) lastTrained[e.skill] = minOf(lastTrained[e.skill] ?: Int.MAX_VALUE, ago)
        }
        return AssessContext(acts, streak, calibration, lastTrained, lastAny?.let { DayClock.daysBetween(it, today) }, override)
    }

    /** Награды за квесты, которые выполнены, но ещё не записаны в журнал. */
    fun dueQuestEvents(ts: Long, device: String): List<Event> =
        quests.filter { it.progress >= it.goal && !it.rewarded }.map {
            Event(it.id, Event.Kind.QUEST, ts, today, device, text = "Квест «${it.title}»", skill = Skill.QUEST,
                xp = it.xp, steps = listOf(Step("Награда за квест", "+${it.xp}")))
        }
}

object Ledger {
    fun snapshot(events: List<Event>, today: String, clock: DayClock = DayClock()): Snapshot {
        val log = dedupe(events).sortedWith(Event.chronological)

        val deleted = mutableSetOf<String>()
        val edits = mutableMapOf<String, MutableList<Event.Tune>>()
        val calibration = mutableMapOf<Skill, Double>()
        val spends = mutableListOf<Event>()
        val targets = log.filter { it.kind == Event.Kind.ACT }.associate { it.id to it.skill }
        for (e in log) when (e.kind) {
            Event.Kind.DELETE -> e.target?.let { deleted += it }
            Event.Kind.EDIT -> {
                val t = e.target ?: continue
                val tune = e.tune ?: continue
                edits.getOrPut(t) { mutableListOf() } += tune
                val k = tune.calibration
                val skill = targets[t]
                if (k != null && skill != null) calibration[skill] = Fmt.jsRound((calibration[skill] ?: 1.0) * k * 100) / 100
            }
            Event.Kind.SPEND -> spends += e
            else -> Unit
        }

        val entries = log.mapNotNull { e ->
            if ((e.kind != Event.Kind.ACT && e.kind != Event.Kind.QUEST) || e.id in deleted) return@mapNotNull null
            val skill = e.skill ?: return@mapNotNull null
            var xp = (e.xp ?: return@mapNotNull null).toDouble()
            val steps = (e.steps ?: emptyList()).toMutableList()
            for (tune in edits[e.id].orEmpty()) {
                xp = Fmt.jsRound(xp * tune.factor)
                steps += Step(tune.label, "×${Fmt.k(tune.factor)}")
            }
            Entry(e.id, e.kind == Event.Kind.QUEST, e.text ?: "", skill, xp.toInt(), steps, e.ts, e.day, e.device, e.id in edits)
        }

        // Уровень не теряется: минус не опускает ниже начала текущего уровня.
        val total = entries.fold(0) { t, e -> max(t + e.xp, Levels.info(t).start) }
        val skillTotals = mutableMapOf<Skill, Int>()
        for (e in entries) if (e.skill in Skill.trained) skillTotals[e.skill] = (skillTotals[e.skill] ?: 0) + e.xp
        val skills = Skill.trained.associateWith { SkillState(max(0, skillTotals[it] ?: 0)) }

        val dayTotals = mutableMapOf<String, Int>()
        for (e in entries) dayTotals[e.day] = (dayTotals[e.day] ?: 0) + e.xp
        val earned = entries.filter { it.xp > 0 }.sumOf { it.xp }
        val coins = earned / 10 - spends.sumOf { it.cost ?: 0 }

        val positiveDays = entries.filter { !it.isQuest && it.xp > 0 }.map { it.day }.toSet()
        var streak = if (today in positiveDays) 1 else 0
        var cursor = DayClock.shift(today, -1)
        while (cursor in positiveDays) {
            streak++
            cursor = DayClock.shift(cursor, -1)
        }

        val quests = Quests.states(entries, today, log.filter { it.kind == Event.Kind.QUEST }.map { it.id }.toSet())
        val level = Levels.info(total)
        val metrics = Achievements.metrics(entries, total, level.level, skills, dayTotals, positiveDays,
            log.count { it.kind == Event.Kind.EDIT }, spends, clock)
        return Snapshot(today, entries, total, level, skills, calibration, coins, spends, streak, dayTotals, quests,
            Achievements.states(metrics), metrics)
    }

    /** Объединение журналов: одинаковый id — одна запись. */
    fun merge(a: List<Event>, b: List<Event>): List<Event> = dedupe(a + b).sortedWith(Event.chronological)

    private fun dedupe(events: List<Event>): List<Event> {
        val seen = mutableSetOf<String>()
        return events.filter { seen.add(it.id) }
    }

    /** Самая длинная серия подряд идущих дней из множества. */
    internal fun bestRun(days: Set<String>): Int {
        var best = 0
        for (d in days) {
            if (DayClock.shift(d, -1) in days) continue
            var run = 1
            var cursor = DayClock.shift(d, 1)
            while (cursor in days) {
                run++
                cursor = DayClock.shift(cursor, 1)
            }
            best = max(best, run)
        }
        return best
    }
}
