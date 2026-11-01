package dev.artiko.prokachka

import android.app.Application
import dev.artiko.prokachka.data.EventStore
import dev.artiko.prokachka.data.SyncClient

class ProkachkaApp : Application() {
    val store: EventStore by lazy { EventStore(this) }
    val sync: SyncClient by lazy { SyncClient(this, store) }
}
