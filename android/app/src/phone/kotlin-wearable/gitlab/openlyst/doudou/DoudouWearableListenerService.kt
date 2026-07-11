package gitlab.openlyst.doudou

import android.content.Intent
import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Receives messages from the Wear OS app even when the phone app is
 * backgrounded or killed. When a message arrives on the watch_connectivity
 * channel, we bring the MainActivity to the foreground so the Flutter engine
 * can respond immediately instead of waiting for the OS to wake the process.
 */
class DoudouWearableListenerService : WearableListenerService() {

    companion object {
        private const val TAG = "DoudouWearable"
        private const val CHANNEL_PATH = "watch_connectivity"
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != CHANNEL_PATH) return

        Log.d(TAG, "Received watch message, waking app")

        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
        }
        startActivity(intent)
    }
}
