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
        setContent { ProkachkaTheme { ProkachkaRoot(store) } }
    }

    override fun onResume() {
        super.onResume()
        (application as ProkachkaApp).store.refreshDay()
    }
}
