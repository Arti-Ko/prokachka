package dev.artiko.prokachka.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Сверка с эталоном: spec/vectors генерирует spec/reference/gen-vectors.mjs. */
class VectorTest {
    private val spec = File(System.getProperty("spec.dir") ?: "../../spec")
    private val json = Json { ignoreUnknownKeys = true }

    @Serializable data class Act(val cat: String, val xp: Int, val text: String, val label: String)
    @Serializable data class Ctx(val dayActs: List<Act>, val streak: Int, val cal: Map<String, Double>, val lastTrained: Map<String, Int>, val daysSinceAny: Int? = null)
    @Serializable data class Expect(val cat: String, val xp: Int, val steps: List<Step>, val sure: Boolean)
    @Serializable data class Case(val text: String, val context: String, val override: String? = null, val expect: Expect? = null)
    @Serializable data class Hint(val text: String, val hint: String? = null)
    @Serializable data class Prepared(val text: String, val prepared: String)
    @Serializable data class AssessFile(val contexts: Map<String, Ctx>, val cases: List<Case>, val hints: List<Hint>, val prepared: List<Prepared>)
    @Serializable data class Info(val level: Int, val start: Int, val into: Int, val need: Int)
    @Serializable data class LevelCase(val total: Int, val level: Info, val skill: Info)
    @Serializable data class Def(val id: String, val goal: Int, val metric: String)

    private val file by lazy { json.decodeFromString<AssessFile>(File(spec, "vectors/assess.json").readText()) }

    @Test
    fun assessMatchesReference() {
        assertTrue(file.cases.size > 600)
        for (c in file.cases) {
            val raw = file.contexts.getValue(c.context)
            val ctx = AssessContext(
                dayActs = raw.dayActs.map { DayAct(Skill.of(it.cat)!!, it.xp, it.text, it.label) },
                streak = raw.streak,
                calibration = raw.cal.mapKeys { Skill.of(it.key)!! },
                lastTrained = raw.lastTrained.mapKeys { Skill.of(it.key)!! },
                daysSinceAny = raw.daysSinceAny,
                override = c.override?.let { Skill.of(it) },
            )
            val where = "«${c.text}» в контексте ${c.context}${c.override?.let { " +$it" } ?: ""}"
            val got = Assessor.assess(c.text, ctx)
            val expect = c.expect
            if (expect == null) {
                assertNull(where, got)
                continue
            }
            requireNotNull(got) { "null для $where" }
            assertEquals(where, expect.cat, got.skill.key)
            assertEquals(where, expect.steps, got.steps)
            assertEquals(where, expect.xp, got.xp)
            assertEquals(where, expect.sure, got.sure)
        }
    }

    @Test
    fun hintsAndNumberWordsMatchReference() {
        for (h in file.hints) assertEquals(h.text, h.hint, Assessor.hint(h.text)?.name?.lowercase())
        for (p in file.prepared) assertEquals(p.prepared, Assessor.prepare(p.text))
    }

    @Test
    fun levelsMatchReference() {
        for (c in json.decodeFromString<List<LevelCase>>(File(spec, "vectors/levels.json").readText())) {
            val l = Levels.info(c.total)
            val s = Levels.skill(c.total)
            assertEquals("уровень ${c.total}", listOf(c.level.level, c.level.start, c.level.into, c.level.need), listOf(l.level, l.start, l.into, l.need))
            assertEquals("навык ${c.total}", listOf(c.skill.level, c.skill.start, c.skill.into, c.skill.need), listOf(s.level, s.start, s.into, s.need))
        }
    }

    @Test
    fun catalogMatchesSpec() {
        val defs = json.decodeFromString<List<Def>>(File(spec, "achievements.json").readText())
        assertEquals(defs.map { it.id }, AchievementCatalog.all.map { it.id })
        assertEquals(defs.map { it.metric }, AchievementCatalog.all.map { it.metric })
    }
}
