package dev.artiko.prokachka.core

import java.util.Locale
import kotlin.math.abs
import kotlin.math.floor

/** Числа и подписи ровно как в эталоне (ru-RU, JS Math.round): от них зависят тест-векторы. */
object Fmt {
    /** Math.round из JS: половина всегда вверх, в том числе для отрицательных. */
    fun jsRound(x: Double): Double = floor(x + 0.5)

    /** Целое с разрядами по-русски: 1000 → «1000», 10000 → «10 000». */
    fun int(n: Double): String {
        val v = jsRound(n).toLong()
        val digits = abs(v).toString()
        val grouped = if (digits.length < 5) digits else buildString {
            digits.forEachIndexed { i, ch ->
                if (i > 0 && (digits.length - i) % 3 == 0) append(' ')
                append(ch)
            }
        }
        return if (v < 0) "-$grouped" else grouped
    }

    /** «+12», «−20», «0» — с типографским минусом. */
    fun signed(n: Double): String = (if (n > 0) "+" else if (n < 0) "−" else "") + int(abs(n))
    fun signed(n: Int): String = signed(n.toDouble())

    /** Множитель: два знака после запятой без хвостовых нулей. 1.5 → «1,5». */
    fun k(x: Double): String {
        val r = jsRound(x * 100) / 100
        var s = String.format(Locale.US, "%.2f", r)
        while (s.endsWith("0")) s = s.dropLast(1)
        if (s.endsWith(".")) s = s.dropLast(1)
        return s.replace('.', ',')
    }

    fun duration(minutes: Double): String =
        if (minutes >= 60) "${k(jsRound(minutes / 6) / 10)} ч" else "${int(minutes)} мин"

    /** Число как его печатает JS: 30 → «30», 2.5 → «2.5». */
    fun plain(x: Double): String = if (x == floor(x) && abs(x) < 1e15) x.toLong().toString() else x.toString()

    fun plural(n: Int, one: String, few: String, many: String): String {
        val m10 = n % 10
        val m100 = n % 100
        return when {
            m10 == 1 && m100 != 11 -> one
            m10 in 2..4 && (m100 < 12 || m100 > 14) -> few
            else -> many
        }
    }

    fun days(n: Int): String = "$n ${plural(n, "день", "дня", "дней")}"
}
