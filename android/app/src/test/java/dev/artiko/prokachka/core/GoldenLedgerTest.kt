package dev.artiko.prokachka.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.ZoneId

/** Тот же журнал, что проверяет Mac (spec/vectors/ledger.json): итоги обязаны совпасть до единицы. */
class GoldenLedgerTest {
    @Serializable data class Quest(val id: String, val progress: Int, val rewarded: Boolean)
    @Serializable data class Expect(
        val total: Int, val level: Int, val streak: Int, val coins: Int, val todayXP: Int,
        val calibration: Map<String, Double>, val quests: List<Quest>, val metrics: Map<String, Int>, val achievementsDone: List<String>,
    )
    @Serializable data class Golden(val today: String, val zone: String, val events: List<Event>, val expect: Expect)

    @Test
    fun ledgerMatchesMac() {
        val spec = File(System.getProperty("spec.dir") ?: "../../spec")
        val g = Json { ignoreUnknownKeys = true }.decodeFromString<Golden>(File(spec, "vectors/ledger.json").readText())
        assertTrue(g.events.size > 50)
        val s = Ledger.snapshot(g.events, g.today, DayClock(ZoneId.of(g.zone)))
        val e = g.expect
        assertEquals(e.metrics, s.metrics)
        assertEquals(e.quests, s.quests.map { Quest(it.id, it.progress, it.rewarded) })
        assertEquals(e.calibration, s.calibration.mapKeys { it.key.key })
        assertEquals(e.achievementsDone, s.achievements.filter { it.done }.map { it.id })
        assertEquals(listOf(e.total, e.level, e.streak, e.coins, e.todayXP), listOf(s.total, s.level.level, s.streak, s.coins, s.todayXP))
    }
}
