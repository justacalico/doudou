package gitlab.openlyst.doudou.wear

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class WearMessageListenerService : WearableListenerService() {
    
    override fun onMessageReceived(messageEvent: MessageEvent) {
        super.onMessageReceived(messageEvent)
        
        when (messageEvent.path) {
            "/music/state_update" -> {
                val data = String(messageEvent.data)
                // Handle playback state updates from phone
                handlePlaybackStateUpdate(data)
            }
            "/music/track_info" -> {
                val trackInfo = String(messageEvent.data)
                // Handle track information updates
                handleTrackInfoUpdate(trackInfo)
            }
        }
    }
    
    private fun handlePlaybackStateUpdate(data: String) {
        // Parse JSON data and update UI accordingly
        // This would typically involve updating a shared state or sending broadcasts
    }
    
    private fun handleTrackInfoUpdate(trackInfo: String) {
        // Update current track information
        // This could involve updating a local database or shared preferences
    }
}