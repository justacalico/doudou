package gitlab.openlyst.doudou

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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Devices
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.material.*
import androidx.wear.compose.material.icons.*
import androidx.wear.compose.material.icons.filled.*

class MainActivity : ComponentActivity() {
    private lateinit var musicControlManager: MusicControlManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        musicControlManager = MusicControlManager(this)

        setContent {
            WearApp(musicControlManager)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        musicControlManager.cleanup()
    }
}

@Composable
fun WearApp(musicControlManager: MusicControlManager) {
    val musicState by musicControlManager.musicState.collectAsState()

    MaterialTheme {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colors.background),
            contentAlignment = Alignment.Center
        ) {
            ScalingLazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(
                    top = 32.dp,
                    start = 8.dp,
                    end = 8.dp,
                    bottom = 32.dp
                ),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                item {
                    // Current track info
                    if (musicState.currentTrack != null) {
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp),
                            backgroundColor = MaterialTheme.colors.surface
                        ) {
                            Column(
                                modifier = Modifier.padding(8.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = musicState.currentTrack!!.title,
                                    style = MaterialTheme.typography.body1,
                                    textAlign = TextAlign.Center,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                                Text(
                                    text = musicState.currentTrack!!.artist,
                                    style = MaterialTheme.typography.body2,
                                    color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f),
                                    textAlign = TextAlign.Center,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                        }
                    }
                }
                
                item {
                    // Play/Pause button
                    Button(
                        onClick = { 
                            musicControlManager.sendCommand("play_pause")
                        },
                        modifier = Modifier
                            .size(52.dp)
                            .padding(vertical = 4.dp),
                        colors = ButtonDefaults.buttonColors(
                            backgroundColor = MaterialTheme.colors.primary
                        )
                    ) {
                        Icon(
                            imageVector = if (musicState.isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                            contentDescription = if (musicState.isPlaying) "Pause" else "Play",
                            tint = MaterialTheme.colors.onPrimary
                        )
                    }
                }
                
                item {
                    // Previous/Next buttons row
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceEvenly
                    ) {
                        Button(
                            onClick = { 
                                musicControlManager.sendCommand("previous")
                            },
                            modifier = Modifier.size(40.dp),
                            colors = ButtonDefaults.buttonColors(
                                backgroundColor = MaterialTheme.colors.surface
                            )
                        ) {
                            Icon(
                                imageVector = Icons.Default.SkipPrevious,
                                contentDescription = "Previous",
                                tint = MaterialTheme.colors.onSurface
                            )
                        }
                        
                        Button(
                            onClick = { 
                                musicControlManager.sendCommand("next")
                            },
                            modifier = Modifier.size(40.dp),
                            colors = ButtonDefaults.buttonColors(
                                backgroundColor = MaterialTheme.colors.surface
                            )
                        ) {
                            Icon(
                                imageVector = Icons.Default.SkipNext,
                                contentDescription = "Next",
                                tint = MaterialTheme.colors.onSurface
                            )
                        }
                    }
                }
                
                item {
                    // Volume controls
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        backgroundColor = MaterialTheme.colors.surface
                    ) {
                        Column(
                            modifier = Modifier.padding(8.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Volume",
                                style = MaterialTheme.typography.caption
                            )
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceEvenly,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Button(
                                    onClick = { 
                                        val newVolume = (musicState.volume - 0.1f).coerceAtLeast(0.0f)
                                        musicControlManager.sendVolumeCommand(newVolume)
                                    },
                                    modifier = Modifier.size(32.dp),
                                    colors = ButtonDefaults.buttonColors(
                                        backgroundColor = Color.Transparent
                                    )
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.VolumeDown,
                                        contentDescription = "Volume Down",
                                        tint = MaterialTheme.colors.onSurface
                                    )
                                }
                                
                                Text(
                                    text = "${(musicState.volume * 100).toInt()}%",
                                    style = MaterialTheme.typography.body2
                                )
                                
                                Button(
                                    onClick = { 
                                        val newVolume = (musicState.volume + 0.1f).coerceAtMost(1.0f)
                                        musicControlManager.sendVolumeCommand(newVolume)
                                    },
                                    modifier = Modifier.size(32.dp),
                                    colors = ButtonDefaults.buttonColors(
                                        backgroundColor = Color.Transparent
                                    )
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.VolumeUp,
                                        contentDescription = "Volume Up",
                                        tint = MaterialTheme.colors.onSurface
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Preview(device = Devices.WEAR_OS_SMALL_ROUND, showSystemUi = true)
@Composable
fun DefaultPreview() {
    MaterialTheme {
        // Preview with mock data - create a simple mock manager for preview
        val mockManager = object : MusicControlManager(null) {
            override val musicState = kotlinx.coroutines.flow.MutableStateFlow(
                MusicState(
                    isPlaying = false,
                    currentTrack = TrackInfo("Sample Song", "Sample Artist", "Sample Album"),
                    volume = 0.7f,
                    position = 30000,
                    duration = 180000
                )
            )
        }
        WearApp(mockManager)
    }
}