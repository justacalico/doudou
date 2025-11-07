package gitlab.openlyst.doudou

import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class WearMessageListenerService : WearableListenerService() {
    
    override fun onMessageReceived(messageEvent: MessageEvent) {
        super.onMessageReceived(messageEvent)
        
        Log.d(TAG, "Received message on path: ${messageEvent.path}")
        
        when (messageEvent.path) {
            "/music-state" -> {
                handleMusicStateMessage(messageEvent)
            }
            else -> {
                Log.d(TAG, "Unknown message path: ${messageEvent.path}")
            }
        }
    }
    
    private fun handleMusicStateMessage(messageEvent: MessageEvent) {
        try {
            val message = String(messageEvent.data)
            Log.d(TAG, "Received music state: $message")
            
            // The MusicControlManager will handle this through the DataClient listener
            // This service is mainly for logging and potential future expansion
        } catch (e: Exception) {
            Log.e(TAG, "Error handling music state message", e)
        }
    }
    
    companion object {
        private const val TAG = "WearMessageListener"
    }
}