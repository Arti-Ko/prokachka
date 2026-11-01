package dev.artiko.prokachka.core

/** Шаблоны приходят из эталона уже с явными границами слов: \b по-разному ведёт себя на кириллице. */
internal class Rx(pattern: String) {
    private val re = Regex(pattern)

    fun test(s: String): Boolean = re.containsMatchIn(s)

    /** Группы первого совпадения; null, если совпадения нет. */
    fun groups(s: String): List<String?>? = re.find(s)?.groups?.map { it?.value }

    /** Замена всех совпадений, как `String.replace(/…/g, fn)` в JS. */
    fun replace(s: String, transform: (List<String?>) -> String): String =
        re.replace(s) { m -> transform(m.groups.map { it?.value }) }
}

internal data class Minus(
    val rx: Rx,
    val xp: Double,
    val skill: Skill,
    val label: String,
    val perHour: Boolean = false,
)
