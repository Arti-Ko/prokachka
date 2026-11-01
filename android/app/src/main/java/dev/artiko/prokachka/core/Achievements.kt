package dev.artiko.prokachka.core

/** Описание достижения из каталога (spec/reference/achievements.mjs). tier: 1 бронза … 4 платина. */
data class AchievementDef(
    val id: String,
    val group: String,
    val metric: String,
    val goal: Int,
    val tier: Int,
    val title: String,
    val text: String,
    val hidden: Boolean,
)

data class AchievementState(val def: AchievementDef, val progress: Int) {
    val id: String get() = def.id
    val done: Boolean get() = progress >= def.goal
}

internal object Achievements {
    fun states(metrics: Map<String, Int>): List<AchievementState> =
        AchievementCatalog.all.map { AchievementState(it, minOf(metrics[it.metric] ?: 0, it.goal)) }

    /** Счётчики, на которые ссылается каталог. Имена совпадают со Swift-версией. */
    fun metrics(
        entries: List<Entry>, total: Int, level: Int, skills: Map<Skill, SkillState>, dayTotals: Map<String, Int>,
        positiveDays: Set<String>, edits: Int, spends: List<Event>, clock: DayClock,
    ): Map<String, Int> {
        val acts = entries.filter { !it.isQuest }
        val plus = acts.filter { it.xp > 0 }
        val minusDays = acts.filter { it.xp < 0 }.map { it.day }.toSet()
        fun steps(name: String) = acts.count { e -> e.steps.any { it.name == name } }

        var km = 0.0
        var pages = 0.0
        var focus = 0.0
        for (e in plus) {
            if (e.skill !in setOf(Skill.BODY, Skill.MIND, Skill.WORK, Skill.CRAFT)) continue
            val q = Quantities(Assessor.prepare(e.text))
            if (e.skill == Skill.BODY) km += q.km ?: 0.0
            if (e.skill == Skill.MIND) pages += q.pages ?: 0.0
            if (e.skill != Skill.BODY) focus += q.minutes ?: 0.0
        }
        val skillsPerDay = plus.filter { it.skill in Skill.trained }.groupBy { it.day }.mapValues { (_, v) -> v.map { it.skill }.toSet() }
        val weekends = positiveDays.count { DayClock.isSaturday(it) && DayClock.shift(it, 1) in positiveDays }

        val m = mutableMapOf(
            "level" to level,
            "xpTotal" to total,
            "streakBest" to Ledger.bestRun(positiveDays),
            "daysActive" to positiveDays.size,
            "cleanBest" to Ledger.bestRun(acts.map { it.day }.toSet() - minusDays),
            "comebacks" to steps("С возвращением"),
            "weekends" to weekends,
            "acts" to plus.size,
            "xpDayBest" to (dayTotals.values.maxOrNull() ?: 0),
            "bigAct" to (plus.maxOfOrNull { it.xp } ?: 0),
            "skillsInDayBest" to (skillsPerDay.values.maxOfOrNull { it.size } ?: 0),
            "km" to km.toInt(),
            "pages" to pages.toInt(),
            "focusMinutes" to focus.toInt(),
            "selfMade" to steps("Сам"),
            "hard" to acts.count { e -> e.steps.any { it.name == "Сложно" || it.name == "Рекорд" } },
            "records" to steps("Рекорд"),
            "abstains" to steps("Удержался"),
            "minuses" to acts.count { it.xp < 0 },
            "disputes" to edits,
            "early" to plus.count { clock.hour(it.ts) in 4 until 8 },
            "night" to plus.count { clock.hour(it.ts) in 0 until 4 },
            "questsDone" to entries.count { it.isQuest },
            "rewardsTaken" to spends.size,
            "spentTotal" to spends.sumOf { it.cost ?: 0 },
        )
        for (s in Skill.trained) {
            m["skillActs.${s.key}"] = plus.count { it.skill == s }
            m["skillLevel.${s.key}"] = skills[s]?.info?.level ?: 1
        }
        return m
    }
}
