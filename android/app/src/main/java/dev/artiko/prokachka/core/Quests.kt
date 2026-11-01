package dev.artiko.prokachka.core

data class QuestState(
    /** Он же id события-награды: «q-day-body-2026-11-01». Одинаков на всех устройствах. */
    val id: String,
    val period: Period,
    val title: String,
    val skill: Skill?,
    val goal: Int,
    val progress: Int,
    val xp: Int,
    /** Награда уже в журнале. */
    val rewarded: Boolean,
) {
    enum class Period(val key: String) { DAY("day"), WEEK("week") }

    val done: Boolean get() = rewarded || progress >= goal
}

/**
 * Квесты подбираются под два самых отстающих навыка. Отставание считается по журналу до начала дня
 * или недели, поэтому набор не меняется в течение дня и совпадает на устройствах.
 */
internal object Quests {
    private val daily = mapOf(
        Skill.BODY to "Подвигаться", Skill.MIND to "Узнать новое", Skill.WORK to "Довести дело до конца",
        Skill.HOME to "Навести порядок", Skill.PEOPLE to "Связаться с близкими", Skill.CRAFT to "Создать что-нибудь",
        Skill.REST to "Позаботиться о режиме",
    )

    fun states(entries: List<Entry>, today: String, rewarded: Set<String>): List<QuestState> {
        val weekStart = DayClock.weekStart(today)
        val acts = entries.filter { !it.isQuest && it.xp > 0 }
        val todayActs = acts.filter { it.day == today }
        val weekActs = acts.filter { it.day >= weekStart && it.day <= today }
        val dayWeak = weakest(entries.filter { it.day < today })
        val weekWeak = weakest(entries.filter { it.day < weekStart })

        fun make(key: String, period: QuestState.Period, title: String, skill: Skill?, goal: Int, xp: Int, pool: List<Entry>): QuestState {
            val id = "q-${period.key}-$key-${if (period == QuestState.Period.DAY) today else weekStart}"
            val progress = minOf(goal, pool.count { skill == null || it.skill == skill })
            return QuestState(id, period, title, skill, goal, progress, xp, id in rewarded)
        }

        return dayWeak.take(2).map { make(it.key, QuestState.Period.DAY, daily.getValue(it), it, 1, 40, todayActs) } + listOf(
            make("five", QuestState.Period.DAY, "Пять дел за день", null, 5, 60, todayActs),
            make(weekWeak[0].key, QuestState.Period.WEEK, "Четыре раза «${weekWeak[0].title}»", weekWeak[0], 4, 120, weekActs),
            make("twenty", QuestState.Period.WEEK, "Двадцать дел за неделю", null, 20, 150, weekActs),
        )
    }

    /** Навыки от самого отстающего; при равенстве — в порядке Skill.trained. */
    fun weakest(entries: List<Entry>): List<Skill> {
        val totals = mutableMapOf<Skill, Int>()
        for (e in entries) totals[e.skill] = (totals[e.skill] ?: 0) + e.xp
        return Skill.trained.withIndex().sortedWith(compareBy({ totals[it.value] ?: 0 }, { it.index })).map { it.value }
    }
}
