package dev.artiko.prokachka

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import dev.artiko.prokachka.ui.ProkachkaRoot
import dev.artiko.prokachka.ui.ProkachkaTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val store = (application as ProkachkaApp).store
        val sync = (application as ProkachkaApp).sync
        setContent { ProkachkaTheme { ProkachkaRoot(store, sync) } }
    }

    override fun onResume() {
        super.onResume()
        (application as ProkachkaApp).store.refreshDay()
        (application as ProkachkaApp).sync.resume()
    }

    override fun onPause() {
        super.onPause()
        (application as ProkachkaApp).sync.pause()
    }
}
