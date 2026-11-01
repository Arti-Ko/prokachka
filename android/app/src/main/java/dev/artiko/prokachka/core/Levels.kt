package dev.artiko.prokachka.core

import kotlin.math.pow

data class LevelInfo(val level: Int, val start: Int, val into: Int, val need: Int) {
    val progress: Double get() = if (need > 0) into.toDouble() / need else 0.0
}

/** Кривая уровней. Общий: 100 × L^1,4 на переход, навыки: 60 × L^1,3. */
object Levels {
    fun req(level: Int): Int = Fmt.jsRound(100 * level.toDouble().pow(1.4)).toInt()
    fun skillReq(level: Int): Int = Fmt.jsRound(60 * level.toDouble().pow(1.3)).toInt()

    fun info(total: Int, req: (Int) -> Int = ::req): LevelInfo {
        var level = 1
        var start = 0
        while (total - start >= req(level)) {
            start += req(level)
            level++
        }
        return LevelInfo(level, start, total - start, req(level))
    }

    fun skill(total: Int): LevelInfo = info(total, ::skillReq)

    fun rank(level: Int): String = when {
        level >= 20 -> "Легенда"
        level >= 15 -> "Мастер"
        level >= 10 -> "Практик"
        level >= 5 -> "Ученик"
        else -> "Новичок"
    }
}
