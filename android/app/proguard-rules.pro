# JNI-used classes (looked up by name from Dart)
-keep class gitlab.openlyst.doudou.Equalizer { *; }
-keep class gitlab.openlyst.doudou.SDKInt { *; }
-keep class gitlab.openlyst.doudou.SDKInt$Companion { *; }

# audio_service (media session, foreground service)
-keep class com.ryanheise.audioservice.** { *; }

# just_audio / ExoPlayer (used by just_audio on Android)
-keep class com.ryanheise.just_audio.** { *; }
