package dev.artiko.prokachka

import android.app.Application
import dev.artiko.prokachka.data.EventStore

class ProkachkaApp : Application() {
    val store: EventStore by lazy { EventStore(this) }
}
