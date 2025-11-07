package gitlab.openlyst.doudou

import android.content.Context
import android.util.Log
import com.google.android.gms.tasks.Task
import com.google.android.gms.wearable.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import org.json.JSONObject

data class TrackInfo(
    val title: String,
    val artist: String,
    val album: String,
    val imageUrl: String? = null
)

data class MusicState(
    val isPlaying: Boolean = false,
    val currentTrack: TrackInfo? = null,
    val volume: Float = 1.0f,
    val position: Long = 0,
    val duration: Long = 0
)

open class MusicControlManager(private val context: Context?) {
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    private val _musicState = MutableStateFlow(MusicState())
    open val musicState: StateFlow<MusicState> = _musicState
    
    private var dataClient: DataClient? = null
    private var messageClient: MessageClient? = null
    
    init {
        context?.let { ctx ->
            dataClient = Wearable.getDataClient(ctx)
            messageClient = Wearable.getMessageClient(ctx)
            
            // Listen for data changes from the phone
            dataClient?.addListener(dataListener)
            
            // Request initial state
            requestMusicState()
        }
    }
    
    private val dataListener = DataClient.OnDataChangedListener { dataEvents ->
        scope.launch {
            for (event in dataEvents) {
                if (event.type == DataEvent.TYPE_CHANGED) {
                    val dataItem = event.dataItem
                    if (dataItem.uri.path == "/music-state") {
                        handleMusicStateUpdate(dataItem)
                    }
                }
            }
        }
    }
    
    private fun handleMusicStateUpdate(dataItem: DataItem) {
        try {
            val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
            val jsonString = dataMap.getString("data") ?: return
            val jsonObject = JSONObject(jsonString)
            
            val currentTrack = if (jsonObject.has("current_track") && !jsonObject.isNull("current_track")) {
                val trackObj = jsonObject.getJSONObject("current_track")
                TrackInfo(
                    title = trackObj.optString("title", "Unknown"),
                    artist = trackObj.optString("artist", "Unknown Artist"),
                    album = trackObj.optString("album", "Unknown Album"),
                    imageUrl = trackObj.optString("image_url", null)
                )
            } else null
            
            _musicState.value = _musicState.value.copy(
                isPlaying = jsonObject.optBoolean("is_playing", false),
                currentTrack = currentTrack,
                volume = jsonObject.optDouble("volume", 1.0).toFloat(),
                position = jsonObject.optLong("position", 0),
                duration = jsonObject.optLong("duration", 0)
            )
            
            Log.d(TAG, "Updated music state: ${_musicState.value}")
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing music state update", e)
        }
    }
    
    fun sendCommand(action: String) {
        scope.launch {
            try {
                val json = JSONObject()
                json.put("action", action)
                
                sendMessageToPhone(json.toString(), "/music-control")
                Log.d(TAG, "Sent command: $action")
            } catch (e: Exception) {
                Log.e(TAG, "Error sending command: $action", e)
            }
        }
    }
    
    fun sendVolumeCommand(volume: Float) {
        scope.launch {
            try {
                val json = JSONObject()
                json.put("action", "set_volume")
                json.put("volume", volume.toDouble())
                
                sendMessageToPhone(json.toString(), "/music-control")
                Log.d(TAG, "Sent volume command: $volume")
            } catch (e: Exception) {
                Log.e(TAG, "Error sending volume command", e)
            }
        }
    }
    
    fun requestMusicState() {
        scope.launch {
            try {
                val json = JSONObject()
                json.put("action", "request_state")
                
                sendMessageToPhone(json.toString(), "/music-control")
                Log.d(TAG, "Requested music state")
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting music state", e)
            }
        }
    }
    
    private suspend fun sendMessageToPhone(message: String, path: String) {
        try {
            val nodeClient = context?.let { Wearable.getNodeClient(it) } ?: return
            
            nodeClient.connectedNodes.addOnSuccessListener { nodes ->
                for (node in nodes) {
                    messageClient?.sendMessage(node.id, path, message.toByteArray())
                        ?.addOnSuccessListener {
                            Log.d(TAG, "Message sent successfully to ${node.displayName}")
                        }
                        ?.addOnFailureListener { e ->
                            Log.e(TAG, "Failed to send message to ${node.displayName}", e)
                        }
                }
            }.addOnFailureListener { e ->
                Log.e(TAG, "Failed to get connected nodes", e)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in sendMessageToPhone", e)
        }
    }
    
    fun cleanup() {
        dataClient?.removeListener(dataListener)
    }
    
    companion object {
        private const val TAG = "MusicControlManager"
    }
}