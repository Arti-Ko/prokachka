package dev.artiko.prokachka.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneId

class LedgerTest {
    private val moscow = DayClock(ZoneId.of("Europe/Moscow"))
    private var seq = 0L

    private fun act(day: String, skill: Skill, xp: Int, text: String? = null, steps: List<Step> = emptyList(), device: String = "mac"): Event {
        seq++
        return Event.act(text ?: "дело $seq", Assessment(skill, xp, steps, true), 1_700_000_000_000 + seq * 1000, day, device, "a$seq")
    }

    @Test
    fun dayStartsAtFourInTheMorning() {
        assertEquals("2026-10-31", moscow.key(java.time.OffsetDateTime.parse("2026-11-01T00:30:00+03:00").toInstant().toEpochMilli()))
        assertEquals("2026-11-01", moscow.key(java.time.OffsetDateTime.parse("2026-11-01T04:00:00+03:00").toInstant().toEpochMilli()))
        assertEquals("2026-10-26", DayClock.weekStart("2026-11-01"))
    }

    @Test
    fun minusNeverDropsBelowLevelStart() {
        val s = Ledger.snapshot(listOf(act("2026-11-01", Skill.WORK, 120), act("2026-11-01", Skill.REST, -60)), "2026-11-01", moscow)
        assertEquals(2, s.level.level)
        assertEquals(100, s.total)
    }

    @Test
    fun editChangesEntryAndCalibration() {
        val a = act("2026-11-01", Skill.WORK, 100)
        val s = Ledger.snapshot(listOf(a, Event.edit(a.id, Event.Tune.UP, a.ts + 1, a.day, "mac")), "2026-11-01", moscow)
        assertEquals(125, s.entries.first().xp)
        assertEquals(1.1, s.calibration[Skill.WORK]!!, 1e-9)
    }

    @Test
    fun questRewardIsDueOnceAndMergesToOne() {
        val today = "2026-11-01"
        val events = (0 until 5).map { act(today, Skill.WORK, 45) }
        val due = Ledger.snapshot(events, today, moscow).dueQuestEvents(1, "phone")
        assertTrue(due.any { it.id == "q-day-five-2026-11-01" && it.xp == 60 })
        val merged = Ledger.merge(events + due, due.map { it.copy(device = "mac", ts = 2) })
        assertEquals(1, merged.count { it.id == "q-day-five-2026-11-01" })
    }

    @Test
    fun contextKnowsHistoryForVarietyAndComeback() {
        val ctx = Ledger.snapshot(listOf(act("2026-10-25", Skill.BODY, 40), act("2026-10-28", Skill.MIND, 30), act("2026-11-01", Skill.WORK, 45)), "2026-11-01", moscow).context()
        assertEquals(7, ctx.lastTrained[Skill.BODY])
        assertEquals(4, ctx.lastTrained[Skill.MIND])
        assertNull(ctx.lastTrained[Skill.WORK])
        assertEquals(4, ctx.daysSinceAny)
    }

    @Test
    fun metricsCountDistanceWeekendsAndSkills() {
        val events = listOf(
            act("2026-10-31", Skill.BODY, 70, "Пробежал пять километров"), act("2026-11-01", Skill.BODY, 78, "Проехал 20 км на велосипеде"),
            act("2026-11-01", Skill.MIND, 47, "Прочитал 30 страниц"), act("2026-11-01", Skill.WORK, 60, "Работал 2 часа"),
            act("2026-11-01", Skill.REST, -25, "Курил", listOf(Step("Курение", "−25"))),
        )
        val m = Ledger.snapshot(events, "2026-11-01", moscow).metrics
        assertEquals(25, m["km"])
        assertEquals(30, m["pages"])
        assertEquals(120, m["focusMinutes"])
        assertEquals(1, m["weekends"])
        assertEquals(3, m["skillsInDayBest"])
        assertEquals(2, m["skillActs.body"])
    }
}
