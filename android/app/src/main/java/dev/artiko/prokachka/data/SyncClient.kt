package dev.artiko.prokachka.data

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.provider.Settings
import android.util.Base64
import dev.artiko.prokachka.core.PairRequest
import dev.artiko.prokachka.core.PairResponse
import dev.artiko.prokachka.core.PushRequest
import dev.artiko.prokachka.core.PushResponse
import dev.artiko.prokachka.core.SyncCrypto
import dev.artiko.prokachka.core.SyncProtocol
import dev.artiko.prokachka.core.SyncRequest
import dev.artiko.prokachka.core.SyncResponse
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.Inet4Address
import java.net.URL
import kotlin.coroutines.resume

/** Mac, найденный в сети через Bonjour/NSD. */
data class FoundMac(val name: String, val host: String, val port: Int, val device: String)

data class SyncState(
    val paired: Boolean = false,
    val macName: String? = null,
    val found: List<FoundMac> = emptyList(),
    val status: String = "",
    val lastSync: Long? = null,
    val busy: Boolean = false,
    val error: String? = null,
)

/**
 * Клиент синхронизации (spec/sync.md). Пока приложение открыто, ищет свой Mac в Wi‑Fi и обменивается
 * журналом каждые 20 секунд и сразу после записи. Всё, кроме сопряжения, шифруется общим ключом.
 */
class SyncClient(private val context: Context, private val store: EventStore) {
    private val prefs = context.getSharedPreferences("sync", Context.MODE_PRIVATE)
    private val nsd = context.getSystemService(NsdManager::class.java)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }
    private val syncLock = Mutex()
    private val resolveLock = Mutex()
    private var discovery: NsdManager.DiscoveryListener? = null
    private var loop: Job? = null

    private val _state = MutableStateFlow(
        SyncState(
            paired = prefs.contains("key"),
            macName = prefs.getString("macName", null),
            lastSync = prefs.getLong("lastSync", 0).takeIf { it > 0 },
            status = if (prefs.contains("key")) "Ищу Mac в этой сети…" else "Не подключено",
        ),
    )
    val state: StateFlow<SyncState> = _state.asStateFlow()

    private val deviceName: String =
        Settings.Global.getString(context.contentResolver, Settings.Global.DEVICE_NAME)?.takeIf { it.isNotBlank() } ?: Build.MODEL

    @OptIn(FlowPreview::class)
    fun resume() {
        startDiscovery()
        if (loop?.isActive == true) return
        loop = scope.launch {
            launch { store.changes.debounce(700).collect { syncNow() } }
            while (isActive) {
                syncNow()
                delay(20_000)
            }
        }
    }

    fun pause() {
        loop?.cancel()
        loop = null
        stopDiscovery()
    }

    /** null — подключились; иначе текст ошибки для экрана. */
    suspend fun pair(mac: FoundMac, code: String): String? {
        val body = json.encodeToString(PairRequest.serializer(), PairRequest(code.filter(Char::isDigit), store.deviceId, deviceName))
        return try {
            val (status, answer) = post(mac.host, mac.port, "/pair", body.toByteArray(), null)
            if (status != 200) return String(answer).ifBlank { "Mac ответил ошибкой $status" }
            val r = json.decodeFromString(PairResponse.serializer(), String(answer))
            prefs.edit().putString("key", r.key).putString("macDevice", r.device).putString("macName", r.name)
                .putString("host", mac.host).putInt("port", mac.port).apply()
            _state.update { it.copy(paired = true, macName = r.name, error = null, status = "Подключено") }
            // Экран с кодом сейчас закроется вместе со своей корутиной — первый обмен идёт в области клиента.
            scope.launch { syncNow() }
            null
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            "Не получилось связаться с Mac: ${e.message ?: e.javaClass.simpleName}"
        }
    }

    fun unpair() {
        prefs.edit().clear().apply()
        _state.update { SyncState(found = it.found, status = "Не подключено") }
    }

    suspend fun syncNow() {
        val key = prefs.getString("key", null)?.let { Base64.decode(it, Base64.NO_WRAP) } ?: return
        if (!syncLock.tryLock()) return
        try {
            _state.update { it.copy(busy = true) }
            val (host, port) = target() ?: run {
                _state.update { it.copy(status = "Mac не найден в этой сети Wi‑Fi") }
                return
            }
            val me = store.deviceId
            val ask = json.encodeToString(SyncRequest.serializer(), SyncRequest(me, store.allEvents.map { it.id }))
            val (s1, b1) = post(host, port, "/sync", SyncCrypto.seal(ask.toByteArray(), key), me)
            if (s1 != 200) return failed(s1, b1)
            val resp = json.decodeFromString(SyncResponse.serializer(), String(SyncCrypto.open(b1, key)))
            store.importEvents(resp.events, _state.value.macName ?: "Mac")
            if (resp.need.isNotEmpty()) {
                val need = resp.need.toSet()
                val push = json.encodeToString(PushRequest.serializer(), PushRequest(me, store.allEvents.filter { it.id in need }))
                val (s2, b2) = post(host, port, "/push", SyncCrypto.seal(push.toByteArray(), key), me)
                if (s2 != 200) return failed(s2, b2)
                json.decodeFromString(PushResponse.serializer(), String(SyncCrypto.open(b2, key)))
            }
            val now = System.currentTimeMillis()
            prefs.edit().putLong("lastSync", now).apply()
            _state.update { it.copy(status = "Синхронизировано", lastSync = now, error = null) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            _state.update { it.copy(status = "Не удалось связаться с Mac", error = e.message ?: e.javaClass.simpleName) }
        } finally {
            _state.update { it.copy(busy = false) }
            syncLock.unlock()
        }
    }

    private fun failed(status: Int, body: ByteArray) {
        val text = String(body).ifBlank { "ошибка $status" }
        _state.update { it.copy(status = if (status == 401 || status == 403) "Mac не узнал телефон — подключите заново" else "Mac ответил: $text", error = text) }
    }

    /** Адрес своего Mac: свежий из поиска в сети, иначе последний известный. */
    private fun target(): Pair<String, Int>? {
        val device = prefs.getString("macDevice", null)
        _state.value.found.firstOrNull { it.device == device }?.let { return it.host to it.port }
        val host = prefs.getString("host", null) ?: return null
        return host to prefs.getInt("port", 0)
    }

    /** Один повтор: первая попытка после паузы иногда натыкается на закрытый сокет. */
    private suspend fun post(host: String, port: Int, path: String, body: ByteArray, device: String?): Pair<Int, ByteArray> =
        try {
            postOnce(host, port, path, body, device)
        } catch (e: java.io.IOException) {
            delay(400)
            postOnce(host, port, path, body, device)
        }

    private suspend fun postOnce(host: String, port: Int, path: String, body: ByteArray, device: String?): Pair<Int, ByteArray> =
        withContext(Dispatchers.IO) {
            val conn = URL("http", host, port, path).openConnection() as HttpURLConnection
            try {
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.connectTimeout = 3000
                conn.readTimeout = 15000
                conn.setRequestProperty("Content-Type", "application/octet-stream")
                // Mac закрывает соединение после ответа — не держать его в пуле.
                conn.setRequestProperty("Connection", "close")
                device?.let { conn.setRequestProperty("X-Device", it) }
                conn.setFixedLengthStreamingMode(body.size)
                conn.outputStream.use { it.write(body) }
                val status = conn.responseCode
                val stream = if (status in 200..299) conn.inputStream else conn.errorStream
                status to (stream?.use { it.readBytes() } ?: ByteArray(0))
            } finally {
                conn.disconnect()
            }
        }

    // ---------- поиск Mac в сети ----------

    private fun startDiscovery() {
        if (discovery != null) return
        val listener = object : NsdManager.DiscoveryListener {
            override fun onServiceFound(info: NsdServiceInfo) {
                scope.launch { resolve(info) }
            }

            override fun onServiceLost(info: NsdServiceInfo) {
                scope.launch { _state.update { s -> s.copy(found = s.found.filter { it.name != cleanName(info.serviceName) }) } }
            }

            override fun onDiscoveryStarted(serviceType: String) = Unit
            override fun onDiscoveryStopped(serviceType: String) = Unit
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                discovery = null
                scope.launch { _state.update { it.copy(error = "Поиск в сети не запустился (код $errorCode)") } }
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) = Unit
        }
        discovery = listener
        nsd.discoverServices(SyncProtocol.SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    private fun stopDiscovery() {
        discovery?.let { runCatching { nsd.stopServiceDiscovery(it) } }
        discovery = null
    }

    @Suppress("DEPRECATION")
    private suspend fun resolve(info: NsdServiceInfo) = resolveLock.withLock {
        val r = suspendCancellableCoroutine<NsdServiceInfo?> { cont ->
            nsd.resolveService(info, object : NsdManager.ResolveListener {
                override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                    if (cont.isActive) cont.resume(null)
                }

                override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                    if (cont.isActive) cont.resume(serviceInfo)
                }
            })
        } ?: return@withLock
        val v4 = if (Build.VERSION.SDK_INT >= 34) r.hostAddresses.firstOrNull { it is Inet4Address } else null
        val host = (v4 ?: r.host)?.hostAddress ?: return@withLock
        val mac = FoundMac(cleanName(r.serviceName), host, r.port, r.attributes["device"]?.toString(Charsets.UTF_8) ?: "")
        _state.update { s -> s.copy(found = s.found.filter { it.device != mac.device } + mac) }
        if (mac.device == prefs.getString("macDevice", null)) prefs.edit().putString("host", mac.host).putInt("port", mac.port).apply()
    }

    private fun cleanName(name: String) = name.removePrefix("Прокачка · ")
}
