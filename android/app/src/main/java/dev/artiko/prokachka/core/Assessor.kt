package dev.artiko.prokachka.core

import kotlinx.serialization.Serializable
import kotlin.math.min
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sqrt

/** Одна строка разбора оценки: «Сам» → «×1,5». */
@Serializable
data class Step(val name: String, val `val`: String)

data class Assessment(val skill: Skill, val xp: Int, val steps: List<Step>, val sure: Boolean)

/** Дело, уже записанное в этот день. text — после [Assessor.prepare], label — первая строка разбора. */
data class DayAct(val skill: Skill, val xp: Int, val text: String = "", val label: String = "")

data class AssessContext(
    val dayActs: List<DayAct> = emptyList(),
    /** Дни подряд, считая сегодня, если сегодня уже был плюс. */
    val streak: Int = 0,
    val calibration: Map<Skill, Double> = emptyMap(),
    /** Сколько дней назад навык качался последний раз (только дни до сегодняшнего). */
    val lastTrained: Map<Skill, Int> = emptyMap(),
    /** Сколько дней назад был последний день с плюсом; null — истории нет. */
    val daysSinceAny: Int? = null,
    /** Навык, выбранный вручную, когда текст не распознан. */
    val override: Skill? = null,
)

/** Почему текст не оценён. */
enum class AssessHint { SHORT, PLAN }

/**
 * Формула (spec/reference/engine.mjs): База × Объём × Сам/с помощью × Рекорд/сложность × Интенсивность
 * × Стрик × Разнообразие × Повтор × Калибровка × Усталость + Бонусы.
 */
object Assessor {
    private val word = Rx("[а-я]+")
    private val tensUnits = Rx("(?<![\\d.,])([2-9]0) ([1-9])(?![\\d.,])")
    private val hundreds = Rx("(?<![\\d.,])([1-9]00) ([1-9]\\d?)(?![\\d.,])")
    private val half = Rx("(?<![а-я])пол (?=час|км|литр|стакан)")
    private val ignored = Regex("[\\s\\d.,!?-]")

    /** Нижний регистр, ё → е, числа словами → цифры. */
    fun prepare(raw: String): String {
        var t = raw.lowercase().replace('ё', 'е')
        t = word.replace(t) { g -> Rules.numberWords[g[0]!!]?.let(Fmt::plain) ?: g[0]!! }
        t = tensUnits.replace(t) { g -> (g[1]!!.toInt() + g[2]!!.toInt()).toString() }
        t = hundreds.replace(t) { g -> (g[1]!!.toInt() + g[2]!!.toInt()).toString() }
        t = half.replace(t) { "0.5 " }
        return t
    }

    private fun meaningful(t: String) = t.replace(ignored, "").length
    private fun isPlan(t: String) = Rules.plan.test(t) && !Rules.past.test(t)

    fun hint(raw: String): AssessHint? {
        val t = prepare(raw)
        if (t.isBlank()) return null
        if (meaningful(t) < 3) return AssessHint.SHORT
        return if (isPlan(t)) AssessHint.PLAN else null
    }

    /** Множитель стрика: +3% за день до 10 дней, дальше +1% до +50% на 30-й день. */
    internal fun streakK(s: Int): Double = 1 + min(s, 10) * 0.03 + max(0, min(s, 30) - 10) * 0.01

    fun assess(raw: String, ctx: AssessContext): Assessment? {
        val t = prepare(raw)
        if (meaningful(t) < 3 || isPlan(t)) return null
        val steps = mutableListOf<Step>()
        val q = Quantities(t)
        val positiveToday = ctx.dayActs.filter { it.xp > 0 }
        val abstain = Rules.abstain.test(t)

        if (!abstain) minusRule(t)?.let { m ->
            var xp = m.xp
            steps += Step(m.label, Fmt.signed(m.xp))
            if (m.perHour) {
                val h = clamp((q.minutes ?: 60.0) / 60, 0.5, 6.0)
                xp *= h
                steps += Step("Время · ${Fmt.duration(h * 60)}", "×${Fmt.k(h)}")
            }
            val again = ctx.dayActs.count { it.xp < 0 && it.label == m.label }
            if (again > 0) {
                val k = min(2.0, 1 + 0.5 * again)
                xp *= k
                steps += Step("Снова · ${again + 1}-й раз за день", "×${Fmt.k(k)}")
            }
            return Assessment(m.skill, Fmt.jsRound(xp).toInt(), steps, true)
        }

        val skill: Skill
        var xp: Double
        if (abstain) {
            skill = Skill.REST
            xp = 20.0
            steps += Step("Удержался", "20")
        } else {
            skill = ctx.override ?: detectSkill(t)
            xp = skill.base
            steps += Step("База · ${skill.title}", Fmt.plain(xp))
        }
        fun mul(name: String, k: Double) {
            xp *= k
            steps += Step(name, "×${Fmt.k(k)}")
        }

        if (!abstain) {
            q.effort(skill, t)?.let { (k, label) -> mul("Объём · $label", k) }
            if (Rules.selfMade.test(t)) mul("Сам", 1.5) else if (Rules.helped.test(t)) mul("С помощью", 0.8)
            if (Rules.record.test(t)) mul("Рекорд", 1.5) else if (Rules.hard.test(t)) mul("Сложно", 1.3) else if (Rules.easy.test(t)) mul("Легко", 0.7)
            if (Rules.intense.test(t)) mul("Интенсивно", 1.2)
        }
        if (ctx.streak > 0) mul("Стрик · ${Fmt.days(ctx.streak)}", streakK(ctx.streak))
        if (!abstain && skill in Skill.trained && positiveToday.none { it.skill == skill }) {
            val ago = ctx.lastTrained[skill]
            if (ago == null) mul("Новый навык", 1.2) else if (ago >= 3) mul("Давно не качал · ${Fmt.days(ago)}", 1.2)
        }
        val same = positiveToday.count { it.text == t }
        val repeats = positiveToday.count { it.skill == skill }
        if (same > 0) mul("Повтор того же · ${same + 1}-й раз", 0.5.pow(same))
        else if (repeats > 0) mul("Повтор · ${repeats + 1}-й раз за день", 0.85.pow(repeats))
        val cal = ctx.calibration[skill] ?: 1.0
        if (kotlin.math.abs(cal - 1) > 0.001) mul("Твоя калибровка", cal)
        val dayXP = positiveToday.sumOf { it.xp }
        if (dayXP >= 800) mul("Усталость дня · больше 800 XP", 0.5)
        else if (dayXP >= 500) mul("Усталость дня · больше 500 XP", 0.75)

        xp = Fmt.jsRound(xp)
        if (positiveToday.isEmpty()) {
            xp += 10
            steps += Step("Первое дело за день", "+10")
            val d = ctx.daysSinceAny
            if (d != null && d >= 3) {
                xp += 20
                steps += Step("С возвращением", "+20")
            }
        }
        return Assessment(skill, xp.toInt(), steps, skill != Skill.MISC)
    }

    /** Минус из словаря или «не пошёл в зал» — минус тому навыку, о котором речь. */
    private fun minusRule(t: String): Minus? {
        Rules.minuses.firstOrNull { it.rx.test(t) }?.let { return it }
        if (!Rules.negated.test(t)) return null
        val s = detectSkill(t)
        return Minus(Rules.negated, -15.0, if (s == Skill.MISC) Skill.WORK else s, "Не сделал")
    }

    internal fun detectSkill(t: String): Skill {
        val score = mutableMapOf<Skill, Int>()
        for ((skill, weight, rx) in Rules.cues) if (rx.test(t)) score[skill] = (score[skill] ?: 0) + weight
        var best = Skill.MISC
        var top = 0
        for (s in Skill.trained) {
            val v = score[s] ?: 0
            if (v > top) { best = s; top = v }
        }
        return best
    }
}

internal fun clamp(v: Double, lo: Double, hi: Double) = min(hi, max(lo, v))

/** Числа из текста (после [Assessor.prepare]): минуты, километры, шаги, страницы, главы, повторы, задачи, слова. */
class Quantities(t: String) {
    var minutes: Double? = null
    var km: Double? = null
    var steps: Double? = null
    var pages: Double? = null
    var chapters: Double? = null
    var reps: Double? = null
    var tasks: Double? = null
    var words: Double? = null

    init {
        fun n(s: String?) = (s ?: "0").replace(',', '.').toDoubleOrNull() ?: 0.0
        val hm = hoursMinutes.groups(t)
        val h = hours.groups(t)
        val m = mins.groups(t)
        minutes = when {
            hm != null -> n(hm[1]) * 60 + n(hm[2])
            h != null -> n(h[1]) * 60
            m != null -> n(m[1])
            "полчаса" in t -> 30.0
            "час с половиной" in t -> 90.0
            "весь день" in t || "целый день" in t -> 300.0
            "весь вечер" in t || "целый вечер" in t -> 180.0
            hourWord.test(t) -> 60.0
            else -> null
        }
        km = kmRx.groups(t)?.let { n(it[1]) } ?: metersRx.groups(t)?.let { n(it[1]) / 1000 }
        steps = stepsRx.groups(t)?.let { n(it[1]) }
        pages = pagesRx.groups(t)?.let { n(it[1]) }
        chapters = chaptersRx.groups(t)?.let { n(it[1]) }
        reps = setsRx.groups(t)?.let { n(it[1]) * n(it[2]) } ?: repsRx.groups(t)?.let { n(it[1]) }
        tasks = tasksRx.groups(t)?.let { n(it[1]) }
        words = wordsRx.groups(t)?.let { n(it[1]) }
    }

    /** Первая найденная мера по порядку эталона. Объём идёт под корнем, от ×0,5 до ×3. */
    internal fun effort(skill: Skill, t: String): Pair<Double, String>? {
        val distanceNorm = Rules.distance.firstOrNull { it.first.test(t) }?.second ?: 3.0
        val minuteNorm = if (skill == Skill.REST && Rules.sleep.test(t)) 480.0 else skill.minuteNorm
        val norms: List<Triple<Double?, Double, (Double) -> String>> = listOf(
            Triple(km, distanceNorm) { v -> "${Fmt.k(v)} км" },
            Triple(steps, 8000.0) { v -> "${Fmt.plain(v)} шагов" },
            Triple(pages, 20.0) { v -> "${Fmt.plain(v)} стр." },
            Triple(chapters, 1.0) { v -> "${Fmt.plain(v)} ${Fmt.plural(v.toInt(), "глава", "главы", "глав")}" },
            Triple(reps, 30.0) { v -> "${Fmt.plain(v)} повт." },
            Triple(tasks, 2.0) { v -> "${Fmt.plain(v)} ${Fmt.plural(v.toInt(), "задача", "задачи", "задач")}" },
            Triple(words, 20.0) { v -> "${Fmt.plain(v)} слов" },
            Triple(minutes, minuteNorm) { v -> Fmt.duration(v) },
        )
        for ((value, norm, label) in norms) if (value != null) return clamp(sqrt(value / norm), 0.5, 3.0) to label(value)
        return null
    }

    private companion object {
        val hoursMinutes = Rx("(\\d+(?:[.,]\\d+)?)\\s*(?:ч|час)[а-я]*\\s*(\\d+)\\s*м")
        val hours = Rx("(\\d+(?:[.,]\\d+)?)\\s*(?:ч(?![а-я])|час)")
        val mins = Rx("(\\d+)\\s*мин")
        val hourWord = Rx("(?<![а-я])час(?![а-я])")
        val kmRx = Rx("(\\d+(?:[.,]\\d+)?)\\s*(?:км|килом)")
        val metersRx = Rx("(?<![ч\\d.,])(\\d+)\\s*(?:м(?![а-я])|метр)")
        val stepsRx = Rx("(\\d+)\\s*шаг")
        val pagesRx = Rx("(\\d+)\\s*стр")
        val chaptersRx = Rx("(\\d+)\\s*глав")
        val setsRx = Rx("(\\d+)\\s*подход[а-я]*\\s*по\\s*(\\d+)")
        val repsRx = Rx("(\\d+)\\s*(?:раз(?:а|ов)?(?![а-я])|отжим|подтяг|присед|повтор)")
        val tasksRx = Rx("(\\d+)\\s*(?:задач|тикет|баг)")
        val wordsRx = Rx("(\\d+)\\s*слов")
    }
}
