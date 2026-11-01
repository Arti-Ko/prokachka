package dev.artiko.prokachka

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.quicksettings.TileService
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import dev.artiko.prokachka.ui.Composer
import dev.artiko.prokachka.ui.P
import dev.artiko.prokachka.ui.ProkachkaTheme
import dev.artiko.prokachka.ui.Txt
import dev.artiko.prokachka.ui.Type
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Панель быстрой записи поверх всего: поле, оценка, «+XP» — и закрылась. */
class QuickEntryActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val store = (application as ProkachkaApp).store
        store.refreshDay()
        setContent {
            ProkachkaTheme {
                Box(Modifier.fillMaxSize().clickable(remember { MutableInteractionSource() }, null) { finish() }, contentAlignment = Alignment.BottomCenter) {
                    Column(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(topStart = 26.dp, topEnd = 26.dp)).background(P.background)
                            .clickable(remember { MutableInteractionSource() }, null) {}.navigationBarsPadding().imePadding().padding(16.dp),
                    ) {
                        Txt("Что сделал?", size = Type.headline, weight = FontWeight.SemiBold, modifier = Modifier.padding(start = 4.dp, bottom = 10.dp))
                        Composer(store, autofocus = true) {
                            lifecycleScope.launch { delay(900); finish() }
                        }
                    }
                }
            }
        }
    }
}

/** Плитка «Записать дело» в шторке быстрых настроек. */
class QuickTileService : TileService() {
    override fun onClick() {
        val intent = Intent(this, QuickEntryActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
