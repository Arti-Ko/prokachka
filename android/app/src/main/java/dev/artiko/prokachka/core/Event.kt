package dev.artiko.prokachka.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.UUID

/**
 * Запись журнала. Журнал только дописывается: правка и удаление — тоже события,
 * поэтому слияние журналов двух устройств — объединение по id. Формат совпадает с Mac (events.jsonl).
 */
@Serializable
data class Event(
    val id: String,
    val kind: Kind,
    /** Миллисекунды с 1970-01-01. */
    val ts: Long,
    /** Учётный день «гггг-мм-дд» с началом в 04:00. */
    val day: String,
    val device: String,
    val text: String? = null,
    val skill: Skill? = null,
    val xp: Int? = null,
    val steps: List<Step>? = null,
    val target: String? = null,
    val tune: Tune? = null,
    val cost: Int? = null,
) {
    @Serializable
    enum class Kind {
        @SerialName("act") ACT, @SerialName("quest") QUEST, @SerialName("edit") EDIT,
        @SerialName("delete") DELETE, @SerialName("spend") SPEND,
    }

    /** Правка оценки: «мало» поднимает и запись, и навык; «много» опускает; «строго» смягчает минус. */
    @Serializable
    enum class Tune(val factor: Double, val calibration: Double?, val label: String) {
        @SerialName("up") UP(1.25, 1.1, "Твоя правка: мало"),
        @SerialName("down") DOWN(0.8, 0.9, "Твоя правка: много"),
        @SerialName("soft") SOFT(0.5, null, "Твоя правка: строго"),
    }

    companion object {
        fun act(text: String, a: Assessment, ts: Long, day: String, device: String, id: String = UUID.randomUUID().toString().uppercase()) =
            Event(id, Kind.ACT, ts, day, device, text = text, skill = a.skill, xp = a.xp, steps = a.steps)

        fun edit(target: String, tune: Tune, ts: Long, day: String, device: String) =
            Event(UUID.randomUUID().toString().uppercase(), Kind.EDIT, ts, day, device, target = target, tune = tune)

        fun delete(target: String, ts: Long, day: String, device: String) =
            Event(UUID.randomUUID().toString().uppercase(), Kind.DELETE, ts, day, device, target = target)

        fun spend(title: String, cost: Int, ts: Long, day: String, device: String) =
            Event(UUID.randomUUID().toString().uppercase(), Kind.SPEND, ts, day, device, text = title, cost = cost)

        /** Порядок журнала: по времени, при равенстве по id — одинаково на всех устройствах. */
        val chronological: Comparator<Event> = compareBy<Event> { it.ts }.thenBy { it.id }
    }
}

/** Учётные дни. День начинается в 04:00: дело в час ночи засчитывается вчерашнему дню. */
class DayClock(val zone: ZoneId = ZoneId.systemDefault(), val startHour: Int = 4) {
    fun key(ms: Long): String =
        Instant.ofEpochMilli(ms).atZone(zone).minusHours(startHour.toLong()).toLocalDate().toString()

    fun hour(ms: Long): Int = Instant.ofEpochMilli(ms).atZone(zone).hour

    companion object {
        fun shift(key: String, days: Int): String = LocalDate.parse(key).plusDays(days.toLong()).toString()
        fun daysBetween(a: String, b: String): Int = ChronoUnit.DAYS.between(LocalDate.parse(a), LocalDate.parse(b)).toInt()
        fun isSaturday(key: String): Boolean = LocalDate.parse(key).dayOfWeek == DayOfWeek.SATURDAY
        /** Понедельник недели, к которой относится день. */
        fun weekStart(key: String): String = LocalDate.parse(key).with(DayOfWeek.MONDAY).toString()
    }
}
