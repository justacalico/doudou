# Flutter ProGuard Rules for Google Play Store Release
# =====================================================

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Audio Service
-keep class com.ryanheise.audioservice.** { *; }

# Just Audio
-keep class com.google.android.exoplayer2.** { *; }

# Media Kit
-keep class com.alexmercerind.** { *; }

# Prevent obfuscation of Parcelable classes
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions

# Keep generic types
-keepattributes InnerClasses

# OkHttp (used by many networking libraries)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Gson (if used)
-keep class com.google.gson.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep R classes
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Suppress warnings for missing classes that are optional
-dontwarn javax.annotation.**
-dontwarn javax.xml.stream.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Apache Tika (used for metadata extraction)
-dontwarn org.apache.tika.**

# Google Play Core (deferred components) - these are optional
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Disable logging in release builds
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Optimize and remove unused code
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
