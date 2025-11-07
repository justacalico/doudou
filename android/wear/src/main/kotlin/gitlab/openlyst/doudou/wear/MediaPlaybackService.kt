package gitlab.openlyst.doudou.wear

import android.app.*
import android.content.Intent
import android.os.IBinder
import androidx.media.session.MediaSessionCompat
import androidx.core.app.NotificationCompat

class MediaPlaybackService : Service() {
    
    private lateinit var mediaSession: MediaSessionCompat
    private val NOTIFICATION_ID = 1
    private val CHANNEL_ID = "doudou_wear_playback"
    
    override fun onCreate() {
        super.onCreate()
        
        createNotificationChannel()
        mediaSession = MediaSessionCompat(this, "DoudouWearMediaSession")
        
        // Set up media session callbacks for handling media button events
        mediaSession.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() {
                // Send play command to phone
                sendCommandToPhone("play")
            }
            
            override fun onPause() {
                // Send pause command to phone  
                sendCommandToPhone("pause")
            }
            
            override fun onSkipToNext() {
                // Send next command to phone
                sendCommandToPhone("next")
            }
            
            override fun onSkipToPrevious() {
                // Send previous command to phone
                sendCommandToPhone("previous")
            }
        })
        
        mediaSession.isActive = true
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        mediaSession.release()
    }
    
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Doudou Wear Playback",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Doudou")
            .setContentText("Music playback active")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()
    }
    
    private fun sendCommandToPhone(command: String) {
        // Use WearableClient to send command to phone app
        val wearableClient = WearableClient(this)
        wearableClient.sendMessage(command)
    }
}