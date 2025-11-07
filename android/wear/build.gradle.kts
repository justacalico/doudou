plugins {
    id("com.android.application")
    id("kotlin-android")
}

android {
    namespace = "gitlab.openlyst.doudou.wear"
    compileSdk = 35

    defaultConfig {
        applicationId = "gitlab.openlyst.doudou"
        minSdk = 26  // Wear OS 2.0+ minimum
        targetSdk = 35
        versionCode = 8
        versionName = "8.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.activity:activity-compose:1.8.2")
    
    // Wear OS specific dependencies
    implementation("androidx.wear:wear:1.3.0")
    implementation("com.google.android.support:wearable:2.9.0")
    compileOnly("com.google.android.wearable:wearable:2.9.0")
    
    // Compose BOM for version alignment
    implementation(platform("androidx.compose:compose-bom:2023.10.01"))
    
    // Compose for Wear OS - using BOM versions
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.wear.compose:compose-material:1.2.1")
    implementation("androidx.wear.compose:compose-foundation:1.2.1")
    implementation("androidx.wear.compose:compose-navigation:1.2.1")
    implementation("androidx.activity:activity-compose:1.8.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")
    
    // Communication with phone app
    implementation("com.google.android.gms:play-services-wearable:18.1.0")
    
    // Health Services (for fitness tracking if needed)
    implementation("androidx.health:health-services-client:1.0.0-beta03")
}