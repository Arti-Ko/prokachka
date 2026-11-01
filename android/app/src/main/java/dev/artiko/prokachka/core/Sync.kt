package dev.artiko.prokachka.core

import kotlinx.serialization.Serializable
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/** Синхронизация по локальной сети (spec/sync.md). Mac — сервер, телефон — клиент. */
object SyncProtocol {
    const val SERVICE_TYPE = "_prokachka._tcp."
}

@Serializable data class PairRequest(val code: String, val device: String, val name: String)
/** key — общий ключ синхронизации, base64 от 32 байт. */
@Serializable data class PairResponse(val key: String, val device: String, val name: String)
@Serializable data class SyncRequest(val device: String, val ids: List<String>)
@Serializable data class SyncResponse(val events: List<Event>, val need: List<String>)
@Serializable data class PushRequest(val device: String, val events: List<Event>)
@Serializable data class PushResponse(val accepted: Int)

/** AES-256-GCM: nonce (12 байт) + шифротекст + тег (16 байт) — тот же формат, что у CryptoKit на Mac. */
object SyncCrypto {
    private val random = SecureRandom()

    fun seal(plain: ByteArray, key: ByteArray, nonce: ByteArray = ByteArray(12).also(random::nextBytes)): ByteArray {
        require(key.size == 32) { "ключ должен быть 32 байта" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
        return nonce + cipher.doFinal(plain)
    }

    fun open(combined: ByteArray, key: ByteArray): ByteArray {
        require(key.size == 32 && combined.size > 28) { "повреждённое сообщение" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, combined.copyOfRange(0, 12)))
        return cipher.doFinal(combined, 12, combined.size - 12)
    }
}
