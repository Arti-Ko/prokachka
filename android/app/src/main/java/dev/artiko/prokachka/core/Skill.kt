package dev.artiko.prokachka.core

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Навык записи. MISC — не распознан, QUEST — награда за квест. */
@Serializable
enum class Skill(val title: String, val base: Double, val about: String) {
    @SerialName("body") BODY("Тело", 40.0, "Тренировки, бег, прогулки, зарядка"),
    @SerialName("mind") MIND("Ум", 30.0, "Книги, курсы, языки, разбор новой темы"),
    @SerialName("work") WORK("Дело", 45.0, "Работа, код, ТЗ, отчёты, свои проекты"),
    @SerialName("home") HOME("Быт", 20.0, "Уборка, готовка, ремонт, покупки"),
    @SerialName("people") PEOPLE("Связи", 25.0, "Семья, друзья, помощь, встречи"),
    @SerialName("craft") CRAFT("Творчество", 35.0, "Рисование, музыка, видео, посты"),
    @SerialName("rest") REST("Режим", 15.0, "Сон, вода, медитация, отказ от вредного"),
    @SerialName("misc") MISC("Прочее", 10.0, ""),
    @SerialName("quest") QUEST("Квест", 0.0, "");

    /** Имя в журнале и спецификации: «body», «mind»… */
    val key: String get() = name.lowercase()

    /** Сколько минут дела дают объём ×1: работа длиннее медитации. */
    val minuteNorm: Double
        get() = when (this) {
            WORK -> 60.0
            CRAFT -> 45.0
            REST -> 15.0
            else -> 30.0
        }

    companion object {
        /** Семь навыков, у которых есть свой уровень. */
        val trained = listOf(BODY, MIND, WORK, HOME, PEOPLE, CRAFT, REST)
        fun of(key: String): Skill? = entries.firstOrNull { it.key == key }
    }
}
