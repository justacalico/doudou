# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Preserve Wear OS specific classes
-keep class com.google.android.gms.wearable.** { *; }
-keep class androidx.wear.** { *; }

# Keep Kotlin classes
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Keep application class
-keep class gitlab.openlyst.doudou.wear.** { *; }