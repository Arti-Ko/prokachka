package dev.artiko.prokachka.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.File
import java.util.Base64

class SyncTest {
    @Serializable data class Vector(val key: String, val nonce: String, val plain: String, val combined: String)

    /** Тот же вектор, что создаёт Mac: ключ и nonce дают те же байты, Mac и телефон понимают друг друга. */
    @Test
    fun cryptoMatchesMac() {
        val spec = File(System.getProperty("spec.dir") ?: "../../spec")
        val v = Json.decodeFromString<Vector>(File(spec, "vectors/sync.json").readText())
        val b64 = Base64.getDecoder()
        val key = b64.decode(v.key)
        val sealed = SyncCrypto.seal(v.plain.toByteArray(), key, b64.decode(v.nonce))
        assertEquals(v.combined, Base64.getEncoder().encodeToString(sealed))
        assertEquals(v.plain, String(SyncCrypto.open(b64.decode(v.combined), key)))
    }

    @Test
    fun tamperedMessageIsRejected() {
        val key = ByteArray(32) { it.toByte() }
        val sealed = SyncCrypto.seal("привет".toByteArray(), key)
        assertArrayEquals("привет".toByteArray(), SyncCrypto.open(sealed, key))
        sealed[sealed.size - 1] = (sealed.last().toInt() xor 0xFF).toByte()
        assertThrows(Exception::class.java) { SyncCrypto.open(sealed, key) }
    }

    @Test
    fun eventsSurviveJsonBothWays() {
        val json = Json { ignoreUnknownKeys = true; explicitNulls = false }
        // Так событие пишет Mac (JSONEncoder, без пустых полей).
        val mac = """{"day":"2026-11-01","device":"mac-1","id":"A","kind":"edit","target":"B","ts":5,"tune":"up"}"""
        val e = json.decodeFromString<Event>(mac)
        assertEquals(Event.Tune.UP, e.tune)
        assertEquals(e, json.decodeFromString<Event>(json.encodeToString(Event.serializer(), e)))
    }
}
