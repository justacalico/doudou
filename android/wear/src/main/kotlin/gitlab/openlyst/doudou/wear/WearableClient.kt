package gitlab.openlyst.doudou.wear

import android.content.Context
import com.google.android.gms.tasks.Task
import com.google.android.gms.wearable.*

class WearableClient(private val context: Context) {
    
    private val dataClient: DataClient = Wearable.getDataClient(context)
    private val messageClient: MessageClient = Wearable.getMessageClient(context)
    private val capabilityClient: CapabilityClient = Wearable.getCapabilityClient(context)
    
    companion object {
        private const val DOUDOU_CAPABILITY = "doudou_music_app"
        private const val MUSIC_CONTROL_PATH = "/music/control"
        private const val PLAYBACK_STATE_PATH = "/music/state"
    }
    
    fun checkConnection(callback: (Boolean) -> Unit) {
        capabilityClient.getCapability(DOUDOU_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
            .addOnSuccessListener { capabilityInfo ->
                val connectedNodes = capabilityInfo.nodes
                callback(connectedNodes.isNotEmpty())
            }
            .addOnFailureListener {
                callback(false)
            }
    }
    
    fun sendMessage(command: String) {
        capabilityClient.getCapability(DOUDOU_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
            .addOnSuccessListener { capabilityInfo ->
                val connectedNodes = capabilityInfo.nodes
                if (connectedNodes.isNotEmpty()) {
                    connectedNodes.forEach { node ->
                        messageClient.sendMessage(
                            node.id,
                            MUSIC_CONTROL_PATH,
                            command.toByteArray()
                        )
                    }
                }
            }
    }
    
    fun requestPlaybackState(callback: (Map<String, Any>) -> Unit) {
        capabilityClient.getCapability(DOUDOU_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
            .addOnSuccessListener { capabilityInfo ->
                val connectedNodes = capabilityInfo.nodes
                if (connectedNodes.isNotEmpty()) {
                    connectedNodes.forEach { node ->
                        messageClient.sendMessage(
                            node.id,
                            PLAYBACK_STATE_PATH,
                            "get_state".toByteArray()
                        )
                    }
                }
            }
    }
}