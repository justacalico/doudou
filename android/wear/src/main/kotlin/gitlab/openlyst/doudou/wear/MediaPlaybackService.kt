package gitlab.openlyst.doudou.wear

import android.app.*
import android.content.Intent
import android.os.IBinder

class MediaPlaybackService : Service() {
    
    private val NOTIFICATION_ID = 1
    private val CHANNEL_ID = "doudou_wear_playback"
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Doudou Wear Playback",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}