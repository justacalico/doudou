package gitlab.openlyst.doudou.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.*
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import com.google.android.gms.wearable.Wearable

class MainActivity : ComponentActivity() {
    
    private lateinit var wearableClient: WearableClient
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        wearableClient = WearableClient(this)
        
        setContent {
            WearApp(wearableClient)
        }
    }
}

@Composable
fun WearApp(wearableClient: WearableClient) {
    val navController = rememberSwipeDismissableNavController()
    
    MaterialTheme {
        SwipeDismissableNavHost(
            navController = navController,
            startDestination = "main"
        ) {
            composable("main") {
                MainScreen(
                    onNavigateToPlayer = { navController.navigate("player") },
                    wearableClient = wearableClient
                )
            }
            composable("player") {
                PlayerScreen(wearableClient = wearableClient)
            }
        }
    }
}

@Composable
fun MainScreen(
    onNavigateToPlayer: () -> Unit,
    wearableClient: WearableClient
) {
    var connectionStatus by remember { mutableStateOf("Connecting...") }
    
    LaunchedEffect(Unit) {
        wearableClient.checkConnection { isConnected ->
            connectionStatus = if (isConnected) "Connected to phone" else "Phone not connected"
        }
    }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Doudou",
            style = MaterialTheme.typography.title1,
            color = Color.White,
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = connectionStatus,
            style = MaterialTheme.typography.caption1,
            color = Color.Gray,
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Chip(
            onClick = onNavigateToPlayer,
            label = {
                Text(
                    text = "Music Player",
                    color = Color.White
                )
            },
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
fun PlayerScreen(wearableClient: WearableClient) {
    var isPlaying by remember { mutableStateOf(false) }
    var currentTrack by remember { mutableStateOf("No track playing") }
    
    LaunchedEffect(Unit) {
        wearableClient.requestPlaybackState { playbackData ->
            isPlaying = playbackData["isPlaying"] as? Boolean ?: false
            currentTrack = playbackData["track"] as? String ?: "Unknown track"
        }
    }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = currentTrack,
            style = MaterialTheme.typography.body1,
            color = Color.White,
            textAlign = TextAlign.Center,
            maxLines = 2
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Chip(
                onClick = { wearableClient.sendMessage("previous") },
                label = { Text("⏮") },
                modifier = Modifier.size(48.dp)
            )
            
            Chip(
                onClick = { 
                    wearableClient.sendMessage(if (isPlaying) "pause" else "play")
                    isPlaying = !isPlaying
                },
                label = { Text(if (isPlaying) "⏸" else "▶") },
                modifier = Modifier.size(56.dp)
            )
            
            Chip(
                onClick = { wearableClient.sendMessage("next") },
                label = { Text("⏭") },
                modifier = Modifier.size(48.dp)
            )
        }
    }
}